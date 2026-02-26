import 'package:postgres/postgres.dart';

import '../annotations/column.dart';
import '../metadata/entity_descriptor.dart';
import '../migrations/migration.dart';
import '../migrations/schema.dart';
import 'datasource.dart';
import 'engine_adapter.dart';

final _autoIncPkExp = RegExp(
  r'AUTOINCREMENT\s+PRIMARY\s+KEY',
  caseSensitive: false,
);
final _autoIncExp = RegExp(r'\bAUTO_?INCREMENT\b', caseSensitive: false);
final _blobExp = RegExp(r'\bBLOB\b', caseSensitive: false);
final _doubleExp = RegExp(r'\bDOUBLE\b', caseSensitive: false);
final _pkAutoIncExp = RegExp(
  r'PRIMARY\s+KEY\s+AUTO_?INCREMENT',
  caseSensitive: false,
);

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
    PoolSettings? poolSettings = const PoolSettings(
      maxConnectionCount: 10,
      maxConnectionAge: Duration(minutes: 30),
      queryMode: QueryMode.extended,
      maxSessionUse: Duration(minutes: 30),
      sslMode: SslMode.disable,
    ),
    bool synchronize = true,
    List<Migration> migrations = const [],
  }) {
    final endpoint = Endpoint(
      host: host,
      port: port,
      database: database,
      username: username,
      password: password,
    );
    final engine = poolSettings == null
        ? PostgresEngine.connect(endpoint, settings: settings)
        : PostgresEngine.pool([endpoint], settings: poolSettings);
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

  final Future<SessionExecutor> Function() _open;
  SessionExecutor? _db;

  static PostgresEngine connect(
    Endpoint endpoint, {
    ConnectionSettings? settings,
    PoolSettings? poolSettings,
  }) => PostgresEngine._(() async {
    final effectivePoolSettings =
        poolSettings ??
        (settings == null
            ? null
            : PoolSettings(
                applicationName: settings.applicationName,
                connectTimeout: settings.connectTimeout,
                encoding: settings.encoding,
                queryMode: settings.queryMode,
                queryTimeout: settings.queryTimeout,
                sslMode: settings.sslMode,
                securityContext: settings.securityContext,
                replicationMode: settings.replicationMode,
                transformer: settings.transformer,
                timeZone: settings.timeZone,
                ignoreSuperfluousParameters:
                    settings.ignoreSuperfluousParameters,
                onOpen: settings.onOpen,
                typeRegistry: settings.typeRegistry,
              ));
    return Pool.withEndpoints([endpoint], settings: effectivePoolSettings);
  });

  static PostgresEngine pool(
    List<Endpoint> endpoints, {
    PoolSettings? settings,
  }) => PostgresEngine._(
    () async => Pool.withEndpoints(endpoints, settings: settings),
  );

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

    final fkRows = await db.execute(
      "SELECT tc.table_schema, tc.table_name, kcu.column_name, "
      "ccu.table_name AS foreign_table_name, ccu.column_name AS foreign_column_name, rc.delete_rule "
      "FROM information_schema.table_constraints AS tc "
      "JOIN information_schema.key_column_usage AS kcu "
      "  ON tc.constraint_name = kcu.constraint_name "
      "  AND tc.table_schema = kcu.table_schema "
      "JOIN information_schema.referential_constraints AS rc "
      "  ON tc.constraint_name = rc.constraint_name "
      "  AND tc.constraint_schema = rc.constraint_schema "
      "JOIN information_schema.constraint_column_usage AS ccu "
      "  ON ccu.constraint_name = tc.constraint_name "
      "  AND ccu.table_schema = tc.table_schema "
      "WHERE tc.constraint_type = 'FOREIGN KEY' "
      "AND tc.table_schema NOT IN ('pg_catalog', 'information_schema')",
    );

    final fkMap = <String, List<SchemaForeignKey>>{};
    for (final row in fkRows) {
      final map = row.toColumnMap();
      final scheme = map['table_schema'] as String;
      final table = map['table_name'] as String;
      final key = '$scheme.$table';

      final sourceCol = map['column_name'] as String;
      final targetTable = map['foreign_table_name'] as String;
      final targetCol = map['foreign_column_name'] as String;
      final deleteRule = map['delete_rule'] as String?;

      fkMap
          .putIfAbsent(key, () => [])
          .add(
            SchemaForeignKey(
              sourceColumn: sourceCol,
              targetTable: targetTable,
              targetColumn: targetCol,
              onDeleteCascade: deleteRule == 'CASCADE',
            ),
          );
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
      tables[name] = SchemaTable(
        name: name,
        columns: tableColumns[key]!,
        foreignKeys: fkMap[key],
      );
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
    final db = _ensureSessionExecutor();
    await db.run((session) async {
      for (final s in statements) {
        final sql = _adaptSql(s);
        await session.execute(sql);
      }
      return null;
    });
  }

  @override
  Future<int> execute(String sql, [List<Object?> params = const []]) async {
    final db = _ensureSessionExecutor();
    final prepared = params.isEmpty ? sql : _normalizePlaceholders(sql);
    final result = await db.run(
      (session) => session.execute(prepared, parameters: params),
    );
    return result.affectedRows;
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String sql, [
    List<Object?> params = const [],
  ]) async {
    final db = _ensureSessionExecutor();
    final prepared = params.isEmpty ? sql : _normalizePlaceholders(sql);
    final result = await db.run(
      (session) => session.execute(prepared, parameters: params),
    );
    return result
        .map((row) => row.toColumnMap().cast<String, dynamic>())
        .toList(growable: false);
  }

  @override
  Future<SchemaState> readSchema() async {
    final db = _ensureSessionExecutor();
    return db.run((session) => _readSchemaWithSession(session));
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(EngineAdapter txEngine) action,
  ) async {
    final db = _ensureSessionExecutor();
    return db.runTx((session) async {
      final txEngine = _PostgresSessionEngine(session);
      return action(txEngine);
    });
  }

  @override
  Future<void> ensureHistoryTable() async {
    final db = _ensureSessionExecutor();
    await db.run(
      (session) => session.execute(
        _adaptSql(
          'CREATE TABLE IF NOT EXISTS _loxia_migrations (\n'
          '  version INTEGER PRIMARY KEY,\n'
          '  applied_at TIMESTAMP,\n'
          '  description TEXT\n'
          ')',
        ),
      ),
    );
  }

  @override
  Future<List<int>> getAppliedVersions() async {
    final db = _ensureSessionExecutor();
    final result = await db.run(
      (session) => session.execute(
        'SELECT version FROM _loxia_migrations ORDER BY version',
      ),
    );
    return result
        .map((row) => row.toColumnMap()['version'] as int)
        .toList(growable: false);
  }

  static String _adaptSql(String sql) {
    var adapted = sql;
    adapted = adapted.replaceAll(
      _autoIncPkExp,
      'GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY',
    );
    adapted = adapted.replaceAll(
      _pkAutoIncExp,
      'GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY',
    );
    adapted = adapted.replaceAll(
      _autoIncExp,
      'GENERATED BY DEFAULT AS IDENTITY',
    );
    adapted = adapted.replaceAll(_blobExp, 'BYTEA');
    adapted = adapted.replaceAll(_doubleExp, 'DOUBLE PRECISION');
    return adapted;
  }

  static String _normalizePlaceholders(String sql) {
    if (!sql.contains('?')) return sql;
    var index = 0;
    return sql.replaceAllMapped(RegExp(r'\?'), (_) => '\$${++index}');
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

  SessionExecutor _ensureSessionExecutor() {
    final db = _db;
    if (db == null) {
      throw StateError('PostgresEngine is not open');
    }
    return db;
  }

  @override
  bool get supportsAlterTableAddConstraint => true;

  @override
  String placeholderFor(int index) => '\$$index';
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
    final prepared = params.isEmpty
        ? sql
        : PostgresEngine._normalizePlaceholders(sql);
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
        : PostgresEngine._normalizePlaceholders(sql);
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
      PostgresEngine._adaptSql(
        'CREATE TABLE IF NOT EXISTS _loxia_migrations (\n'
        '  version INTEGER PRIMARY KEY,\n'
        '  applied_at TIMESTAMP,\n'
        '  description TEXT\n'
        ')',
      ),
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

  @override
  bool get supportsAlterTableAddConstraint => true;

  @override
  String placeholderFor(int index) => '\$$index';
}
