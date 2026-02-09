import 'package:postgres/postgres.dart';

import '../annotations/column.dart';
import '../metadata/entity_descriptor.dart';
import '../migrations/migration.dart';
import '../migrations/schema.dart';
import 'datasource.dart';
import 'engine_adapter.dart';

final class PostgresDataSourceOptions extends DataSourceOptions {
  /// Creates options for a PostgreSQL DataSource.
  PostgresDataSourceOptions._({
    required super.engine,
    required super.entities,
    super.migrations,
    super.synchronize,
  });

  factory PostgresDataSourceOptions.connect({
    required String host,
    required int port,
    required String database,
    required String username,
    required String password,
    required List<EntityDescriptor> entities,
    ConnectionSettings? settings,
    bool synchronize = true,
    List<Migration> migrations = const [],
  }) {
    final engine = PostgresEngine.connect(
      Endpoint(
        host: host,
        port: port,
        database: database,
        username: username,
        password: password,
      ),
      settings: settings,
    );
    return PostgresDataSourceOptions._(
      engine: engine,
      entities: entities,
      migrations: migrations,
      synchronize: synchronize,
    );
  }
}

class PostgresEngine implements EngineAdapter {
  PostgresEngine._(this._open);

  final Future<Connection> Function() _open;
  Connection? _db;

  static PostgresEngine connect(
    Endpoint endpoint, {
    ConnectionSettings? settings,
  }) => PostgresEngine._(() => Connection.open(endpoint, settings: settings));

  static PostgresEngine fromConnection(Connection connection) =>
      PostgresEngine._(() async => connection);

  static Future<SchemaState> _readSchemaWithSession(Session db) async {
    final tables = <String, SchemaTable>{};

    final columnRows = await db.execute(
      "SELECT c.table_schema, c.table_name, c.column_name, c.is_nullable, c.data_type, c.udt_name "
      "FROM information_schema.columns c "
      "JOIN information_schema.tables t "
      "  ON c.table_schema = t.table_schema AND c.table_name = t.table_name "
      "WHERE t.table_type = 'BASE TABLE' "
      "AND t.table_schema NOT IN ('pg_catalog', 'information_schema') "
      "ORDER BY c.table_schema, c.table_name, c.ordinal_position",
    );

    final pkRows = await db.execute(
      "SELECT tc.table_schema, tc.table_name, kcu.column_name "
      "FROM information_schema.table_constraints tc "
      "JOIN information_schema.key_column_usage kcu "
      "  ON tc.constraint_name = kcu.constraint_name "
      " AND tc.table_schema = kcu.table_schema "
      "WHERE tc.constraint_type = 'PRIMARY KEY' "
      "  AND tc.table_schema NOT IN ('pg_catalog', 'information_schema')",
    );

    final pkMap = <String, Set<String>>{};
    for (final row in pkRows) {
      final map = row.toColumnMap();
      final scheme = map['table_schema'] as String;
      final table = map['table_name'] as String;
      final col = map['column_name'] as String;
      pkMap.putIfAbsent('$scheme.$table', () => {}).add(col);
    }

    final tableColumns = <String, Map<String, SchemaColumn>>{};
    final tableNames = <String, String>{};

    for (final row in columnRows) {
      final map = row.toColumnMap();
      final scheme = map['table_schema'] as String;
      final table = map['table_name'] as String;
      final key = '$scheme.$table';

      tableNames[key] = table;

      final cname = map['column_name'] as String;
      final nullable = (map['is_nullable'] as String?) == 'YES';
      final dataType = map['data_type'] as String?;
      final udtName = map['udt_name'] as String?;
      final isPk = pkMap[key]?.contains(cname) ?? false;

      tableColumns.putIfAbsent(key, () => {})[cname] = SchemaColumn(
        name: cname,
        type: _mapType(dataType, udtName),
        nullable: nullable,
        isPrimaryKey: isPk,
      );
    }

    for (final key in tableNames.keys) {
      final name = tableNames[key]!;
      tables[name] = SchemaTable(name: name, columns: tableColumns[key]!);
    }

    return SchemaState(tables: tables);
  }

  @override
  Future<void> open() async {
    _db = await _open();
  }

  @override
  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
    }
    _db = null;
  }

  @override
  Future<void> executeBatch(List<String> statements) async {
    final db = _ensureDb();
    for (final s in statements) {
      final sql = _adaptSql(s);
      await db.execute(sql);
    }
  }

  @override
  Future<int> execute(String sql, [List<Object?> params = const []]) async {
    final db = _ensureDb();
    final adapted = _adaptSql(sql);
    final prepared = params.isEmpty ? adapted : _convertPlaceholders(adapted);
    final result = await db.execute(prepared, parameters: params);
    return result.affectedRows;
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String sql, [
    List<Object?> params = const [],
  ]) async {
    final db = _ensureDb();
    final prepared = params.isEmpty ? sql : _convertPlaceholders(sql);
    final result = await db.execute(prepared, parameters: params);
    return result
        .map((row) => row.toColumnMap().cast<String, dynamic>())
        .toList(growable: false);
  }

  @override
  Future<SchemaState> readSchema() async {
    return _readSchemaWithSession(_ensureDb());
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(EngineAdapter txEngine) action,
  ) async {
    final db = _ensureDb();
    return db.runTx((session) async {
      final txEngine = _PostgresSessionEngine(session);
      return action(txEngine);
    });
  }

  @override
  Future<void> ensureHistoryTable() async {
    final db = _ensureDb();
    await db.execute(
      'CREATE TABLE IF NOT EXISTS _loxia_migrations (\n'
      '  version INTEGER PRIMARY KEY,\n'
      '  applied_at TIMESTAMP,\n'
      '  description TEXT\n'
      ')',
    );
  }

  @override
  Future<List<int>> getAppliedVersions() async {
    final db = _ensureDb();
    final result = await db.execute(
      'SELECT version FROM _loxia_migrations ORDER BY version',
    );
    return result
        .map((row) => row.toColumnMap()['version'] as int)
        .toList(growable: false);
  }

  static String _adaptSql(String sql) {
    var adapted = sql;
    adapted = adapted.replaceAll(
      RegExp(r'AUTOINCREMENT\s+PRIMARY\s+KEY', caseSensitive: false),
      'GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY',
    );
    adapted = adapted.replaceAll(
      RegExp(r'PRIMARY\s+KEY\s+AUTO_?INCREMENT', caseSensitive: false),
      'GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY',
    );
    adapted = adapted.replaceAll(
      RegExp(r'\bAUTO_?INCREMENT\b', caseSensitive: false),
      'GENERATED BY DEFAULT AS IDENTITY',
    );
    adapted = adapted.replaceAll(
      RegExp(r'\bBLOB\b', caseSensitive: false),
      'BYTEA',
    );
    adapted = adapted.replaceAll(
      RegExp(r'\bDOUBLE\b', caseSensitive: false),
      'DOUBLE PRECISION',
    );
    return adapted;
  }

  static String _convertPlaceholders(String sql) {
    var index = 0;
    var inSingle = false;
    var inDouble = false;
    final out = StringBuffer();
    for (var i = 0; i < sql.length; i++) {
      final ch = sql[i];
      if (ch == "'" && !inDouble) {
        if (inSingle && i + 1 < sql.length && sql[i + 1] == "'") {
          out.write("''");
          i++;
          continue;
        }
        inSingle = !inSingle;
        out.write(ch);
        continue;
      }
      if (ch == '"' && !inSingle) {
        if (inDouble && i + 1 < sql.length && sql[i + 1] == '"') {
          out.write('""');
          i++;
          continue;
        }
        inDouble = !inDouble;
        out.write(ch);
        continue;
      }
      if (ch == '?' && !inSingle && !inDouble) {
        index += 1;
        out.write('\$$index');
        continue;
      }
      out.write(ch);
    }
    return out.toString();
  }

  static ColumnType _mapType(String? dataType, String? udtName) {
    final type = (dataType ?? '').toUpperCase();
    final udt = (udtName ?? '').toUpperCase();
    if (type.contains('INT') || udt.contains('INT')) return ColumnType.integer;
    if (type.contains('UUID') || udt.contains('UUID')) return ColumnType.uuid;
    if (type.contains('CHAR') ||
        type.contains('TEXT') ||
        udt.contains('CHAR')) {
      return ColumnType.text;
    }
    if (type.contains('BOOL')) return ColumnType.boolean;
    if (type.contains('DOUBLE') ||
        type.contains('REAL') ||
        type.contains('NUMERIC')) {
      return ColumnType.doublePrecision;
    }
    if (type.contains('TIMESTAMP') ||
        type.contains('DATE') ||
        type.contains('TIME')) {
      return ColumnType.dateTime;
    }
    if (type.contains('JSON')) return ColumnType.json;
    if (type.contains('BYTEA')) return ColumnType.binary;
    return ColumnType.text;
  }

  Connection _ensureDb() {
    final db = _db;
    if (db == null) {
      throw StateError('PostgresEngine is not open');
    }
    return db;
  }
}

class _PostgresSessionEngine implements EngineAdapter {
  _PostgresSessionEngine(this._session);

  final Session _session;

  @override
  Future<void> open() async {
    // No-op: session is already active.
  }

  @override
  Future<void> close() async {
    // No-op: session lifecycle is managed by the parent transaction.
  }

  @override
  Future<void> executeBatch(List<String> statements) async {
    for (final s in statements) {
      final sql = PostgresEngine._adaptSql(s);
      await _session.execute(sql);
    }
  }

  @override
  Future<int> execute(String sql, [List<Object?> params = const []]) async {
    final adapted = PostgresEngine._adaptSql(sql);
    final prepared = params.isEmpty
        ? adapted
        : PostgresEngine._convertPlaceholders(adapted);
    final result = await _session.execute(prepared, parameters: params);
    return result.affectedRows;
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String sql, [
    List<Object?> params = const [],
  ]) async {
    final prepared = params.isEmpty
        ? sql
        : PostgresEngine._convertPlaceholders(sql);
    final result = await _session.execute(prepared, parameters: params);
    return result
        .map((row) => row.toColumnMap().cast<String, dynamic>())
        .toList(growable: false);
  }

  @override
  Future<SchemaState> readSchema() async {
    return PostgresEngine._readSchemaWithSession(_session);
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(EngineAdapter txEngine) action,
  ) async {
    return action(this);
  }

  @override
  Future<void> ensureHistoryTable() async {
    await _session.execute(
      'CREATE TABLE IF NOT EXISTS _loxia_migrations (\n'
      '  version INTEGER PRIMARY KEY,\n'
      '  applied_at TIMESTAMP,\n'
      '  description TEXT\n'
      ')',
    );
  }

  @override
  Future<List<int>> getAppliedVersions() async {
    final result = await _session.execute(
      'SELECT version FROM _loxia_migrations ORDER BY version',
    );
    return result
        .map((row) => row.toColumnMap()['version'] as int)
        .toList(growable: false);
  }
}
