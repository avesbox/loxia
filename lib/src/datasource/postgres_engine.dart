import 'package:postgres/postgres.dart';

import '../migrations/schema.dart';
import '../annotations/column.dart';
import 'engine_adapter.dart';

class PostgresEngine implements EngineAdapter {
  PostgresEngine._({
    required this.host,
    required this.port,
    required this.database,
    required this.username,
    required this.password,
    this.useSSL = false,
  });

  final String host;
  final int port;
  final String database;
  final String username;
  final String password;
  final bool useSSL;

  Connection? _connection;

  /// Creates a PostgreSQL engine with connection parameters
  static PostgresEngine create({
    required String host,
    required int port,
    required String database,
    required String username,
    required String password,
    bool useSSL = false,
  }) {
    return PostgresEngine._(
      host: host,
      port: port,
      database: database,
      username: username,
      password: password,
      useSSL: useSSL,
    );
  }

  @override
  Future<void> open() async {
    _connection = await Connection.open(
      Endpoint(
        host: host,
        port: port,
        database: database,
        username: username,
        password: password,
      ),
      settings: ConnectionSettings(
        sslMode: useSSL ? SslMode.require : SslMode.disable,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _connection?.close();
    _connection = null;
  }

  @override
  Future<void> executeBatch(List<String> statements) async {
    final conn = _ensureConnection();
    for (final s in statements) {
      await conn.execute(s);
    }
  }

  @override
  Future<int> execute(String sql, [List<Object?> params = const []]) async {
    final conn = _ensureConnection();
    final result = await conn.execute(Sql.indexed(sql), parameters: params);
    return result.affectedRows;
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String sql, [
    List<Object?> params = const [],
  ]) async {
    final conn = _ensureConnection();
    final result = await conn.execute(Sql.indexed(sql), parameters: params);

    return result.map((row) => row.toColumnMap()).toList(growable: false);
  }

  @override
  Future<SchemaState> readSchema() async {
    final conn = _ensureConnection();
    final tables = <String, SchemaTable>{};

    // Query PostgreSQL information_schema to get all tables
    final tableRows = await conn.execute(
      Sql.indexed(
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema = 'public' AND table_type = 'BASE TABLE'",
      ),
    );

    for (final row in tableRows) {
      final name = row.toColumnMap()['table_name'] as String;

      // Query column information for each table
      final colRs = await conn.execute(
        Sql.indexed(
          "SELECT column_name, data_type, is_nullable, "
          "(SELECT count(*) > 0 FROM information_schema.table_constraints tc "
          "JOIN information_schema.key_column_usage kcu "
          "ON tc.constraint_name = kcu.constraint_name "
          "WHERE tc.table_name = c.table_name "
          "AND tc.constraint_type = 'PRIMARY KEY' "
          "AND kcu.column_name = c.column_name) as is_primary "
          "FROM information_schema.columns c "
          "WHERE table_name = \$1 AND table_schema = 'public' "
          "ORDER BY ordinal_position",
        ),
        parameters: [name],
      );

      final cols = <String, SchemaColumn>{};
      for (final c in colRs) {
        final colMap = c.toColumnMap();
        final cname = colMap['column_name'] as String;
        final ctypeStr = (colMap['data_type'] as String?) ?? '';
        final isNullable = (colMap['is_nullable'] as String?) == 'YES';
        final isPk = colMap['is_primary'] == true;

        cols[cname] = SchemaColumn(
          name: cname,
          type: _mapType(ctypeStr),
          nullable: isNullable,
          isPrimaryKey: isPk,
        );
      }
      tables[name] = SchemaTable(name: name, columns: cols);
    }
    return SchemaState(tables: tables);
  }

  ColumnType _mapType(String t) {
    final up = t.toUpperCase();
    // PostgreSQL type mappings
    if (up.contains('INT') ||
        up == 'SERIAL' ||
        up == 'BIGSERIAL' ||
        up == 'SMALLSERIAL') {
      return ColumnType.integer;
    }
    if (up.contains('CHAR') || up.contains('TEXT') || up == 'VARCHAR') {
      return ColumnType.text;
    }
    if (up == 'BYTEA') return ColumnType.binary;
    if (up.contains('REAL') ||
        up.contains('FLOAT') ||
        up.contains('DOUBLE') ||
        up == 'NUMERIC' ||
        up == 'DECIMAL') {
      return ColumnType.doublePrecision;
    }
    if (up == 'JSON' || up == 'JSONB') return ColumnType.json;
    if (up == 'BOOLEAN' || up == 'BOOL') return ColumnType.boolean;
    if (up.contains('TIME') || up.contains('DATE') || up == 'TIMESTAMP') {
      return ColumnType.dateTime;
    }
    // Fallback to text
    return ColumnType.text;
  }

  Connection _ensureConnection() {
    final conn = _connection;
    if (conn == null) {
      throw StateError('PostgresEngine is not open');
    }
    return conn;
  }
}
