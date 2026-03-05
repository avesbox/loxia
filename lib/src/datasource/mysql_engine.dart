import 'dart:async';

import 'package:mysql_client/mysql_client.dart';

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
final _pkAutoIncExp = RegExp(
  r'PRIMARY\s+KEY\s+AUTO_?INCREMENT',
  caseSensitive: false,
);
final _autoIncExp = RegExp(r'\bAUTO_?INCREMENT\b', caseSensitive: false);
final _uuidExp = RegExp(r'\bUUID\b', caseSensitive: false);
final _onConflictDoNothingExp = RegExp(r'\s+ON\s+CONFLICT\s+DO\s+NOTHING\s*;?\s*$', caseSensitive: false);
final _insertIntoExp = RegExp(r'^\s*INSERT\s+INTO\b', caseSensitive: false);

final class MySqlDataSourceOptions extends DataSourceOptions {
  MySqlDataSourceOptions._({
    required super.engine,
    required super.entities,
    super.migrations,
    super.synchronize,
  });

  factory MySqlDataSourceOptions.connect({
    required String host,
    required int port,
    required String database,
    required String username,
    required String password,
    required List<EntityDescriptor> entities,
    bool secure = true,
    String collation = 'utf8mb4_general_ci',
    int timeoutMs = 10000,
    bool synchronize = true,
    List<Migration> migrations = const [],
  }) {
    final engine = MySqlEngine.connect(
      host: host,
      port: port,
      database: database,
      username: username,
      password: password,
      secure: secure,
      collation: collation,
      timeoutMs: timeoutMs,
    );
    return MySqlDataSourceOptions._(
      engine: engine,
      entities: entities,
      migrations: migrations,
      synchronize: synchronize,
    );
  }

  factory MySqlDataSourceOptions.pool({
    required String host,
    required int port,
    required String database,
    required String username,
    required String password,
    required List<EntityDescriptor> entities,
    int maxConnections = 10,
    bool secure = true,
    String collation = 'utf8mb4_general_ci',
    int timeoutMs = 10000,
    bool synchronize = true,
    List<Migration> migrations = const [],
  }) {
    final engine = MySqlEngine.pool(
      host: host,
      port: port,
      database: database,
      username: username,
      password: password,
      maxConnections: maxConnections,
      secure: secure,
      collation: collation,
      timeoutMs: timeoutMs,
    );
    return MySqlDataSourceOptions._(
      engine: engine,
      entities: entities,
      migrations: migrations,
      synchronize: synchronize,
    );
  }
}

class MySqlEngine implements EngineAdapter {
  MySqlEngine._(
    this._withConnection,
    this._withTransaction,
    this._close,
  );

  final Future<T> Function<T>(Future<T> Function(MySQLConnection conn) action)
  _withConnection;
  final Future<T> Function<T>(Future<T> Function(MySQLConnection conn) action)
  _withTransaction;
  final Future<void> Function() _close;

  static const _ansiQuotesSql =
      "SET SESSION sql_mode = CONCAT_WS(',', @@sql_mode, 'ANSI_QUOTES')";

  static MySqlEngine connect({
    required String host,
    required int port,
    required String database,
    required String username,
    required String password,
    bool secure = true,
    String collation = 'utf8mb4_general_ci',
    int timeoutMs = 10000,
  }) {
    MySQLConnection? connection;

    Future<MySQLConnection> ensureConnection() async {
      final existing = connection;
      if (existing != null && existing.connected) {
        return existing;
      }

      final conn = await MySQLConnection.createConnection(
        host: host,
        port: port,
        userName: username,
        password: password,
        databaseName: database,
        secure: secure,
        collation: collation,
      );
      await conn.connect(timeoutMs: timeoutMs);
      await conn.execute(_ansiQuotesSql);
      connection = conn;
      return conn;
    }

    return MySqlEngine._(
      <T>(action) async {
        final conn = await ensureConnection();
        return action(conn);
      },
      <T>(action) async {
        final conn = await ensureConnection();
        return conn.transactional((tx) => action(tx));
      },
      () async {
        final conn = connection;
        if (conn != null && conn.connected) {
          await conn.close();
        }
        connection = null;
      },
    );
  }

  static MySqlEngine pool({
    required String host,
    required int port,
    required String database,
    required String username,
    required String password,
    int maxConnections = 10,
    bool secure = true,
    String collation = 'utf8mb4_general_ci',
    int timeoutMs = 10000,
  }) {
    final pool = MySQLConnectionPool(
      host: host,
      port: port,
      userName: username,
      password: password,
      maxConnections: maxConnections,
      databaseName: database,
      secure: secure,
      collation: collation,
      timeoutMs: timeoutMs,
    );

    final configured = Expando<bool>('loxia_mysql_ansi_quotes');

    Future<T> withConfiguredConnection<T>(
      Future<T> Function(MySQLConnection conn) action,
    ) {
      return Future<T>.value(
        pool.withConnection<T>((conn) async {
          if (configured[conn] != true) {
            await conn.execute(_ansiQuotesSql);
            configured[conn] = true;
          }
          return action(conn);
        }),
      );
    }

    return MySqlEngine._(
      withConfiguredConnection,
      <T>(action) async {
        return pool.transactional<T>((tx) async {
          if (configured[tx] != true) {
            await tx.execute(_ansiQuotesSql);
            configured[tx] = true;
          }
          return action(tx);
        });
      },
      pool.close,
    );
  }

  @override
  Future<void> open() async {}

  @override
  Future<void> close() => _close();

  @override
  Future<void> executeBatch(List<ParameterizedQuery> statements) async {
    await _withConnection((conn) async {
      for (final statement in statements) {
        final sql = _prepareSql(statement.sql);
        if (statement.params.isEmpty) {
          await conn.execute(sql);
          continue;
        }

        final prepared = await conn.prepare(sql);
        try {
          await prepared.execute(statement.params);
        } finally {
          await prepared.deallocate();
        }
      }
    });
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String sql, [
    List<Object?> params = const [],
  ]) {
    return _withConnection((conn) async {
      final preparedSql = _prepareSql(sql);
      final result = await _runWithParams(conn, preparedSql, params);
      return result.rows
          .map((row) => row.typedAssoc().cast<String, dynamic>())
          .toList(growable: false);
    });
  }

  @override
  Future<int> execute(String sql, [List<Object?> params = const []]) {
    return _withConnection((conn) async {
      final preparedSql = _prepareSql(sql);
      final result = await _runWithParams(conn, preparedSql, params);
      return result.affectedRows.toInt();
    });
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(EngineAdapter txEngine) action,
  ) {
    return _withTransaction((txConn) async {
      final txEngine = _MySqlSessionEngine(txConn);
      return action(txEngine);
    });
  }

  @override
  Future<void> ensureHistoryTable() {
    return executeBatch([
      ParameterizedQuery.ddl(
        'CREATE TABLE IF NOT EXISTS _loxia_migrations (\n'
        '  version BIGINT PRIMARY KEY,\n'
        '  applied_at TIMESTAMP,\n'
        '  description TEXT\n'
        ')',
      ),
    ]);
  }

  @override
  Future<List<int>> getAppliedVersions() async {
    final rows = await query(
      'SELECT version FROM _loxia_migrations ORDER BY version',
    );
    return rows
        .map((row) => row['version'])
        .whereType<num>()
        .map((value) => value.toInt())
        .toList(growable: false);
  }

  @override
  Future<SchemaState> readSchema() async {
    return _withConnection(_readSchemaWithConnection);
  }

  static Future<SchemaState> _readSchemaWithConnection(
    MySQLConnection conn,
  ) async {
    final tables = <String, SchemaTable>{};
    final tableColumns = <String, Map<String, SchemaColumn>>{};

    final columns = await conn.execute(
      'SELECT TABLE_NAME, COLUMN_NAME, IS_NULLABLE, DATA_TYPE, COLUMN_KEY '
      'FROM INFORMATION_SCHEMA.COLUMNS '
      'WHERE TABLE_SCHEMA = DATABASE() '
      'ORDER BY TABLE_NAME, ORDINAL_POSITION',
    );

    for (final row in columns.rows) {
      final values = row.assoc();
      final tableName = values['TABLE_NAME'];
      final columnName = values['COLUMN_NAME'];
      if (tableName == null || columnName == null) {
        continue;
      }

      final nullable = (values['IS_NULLABLE'] ?? '').toUpperCase() == 'YES';
      final dataType = values['DATA_TYPE'];
      final isPk = (values['COLUMN_KEY'] ?? '').toUpperCase() == 'PRI';

      tableColumns.putIfAbsent(tableName, () => {})[columnName] = SchemaColumn(
        name: columnName,
        type: _mapType(dataType),
        nullable: nullable,
        isPrimaryKey: isPk,
      );
    }

    final foreignKeys = <String, List<SchemaForeignKey>>{};
    final fkRows = await conn.execute(
      'SELECT k.TABLE_NAME, k.COLUMN_NAME, k.REFERENCED_TABLE_NAME, '
      'k.REFERENCED_COLUMN_NAME, rc.DELETE_RULE '
      'FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE k '
      'JOIN INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS rc '
      '  ON rc.CONSTRAINT_SCHEMA = k.CONSTRAINT_SCHEMA '
      ' AND rc.CONSTRAINT_NAME = k.CONSTRAINT_NAME '
      ' AND rc.TABLE_NAME = k.TABLE_NAME '
      'WHERE k.CONSTRAINT_SCHEMA = DATABASE() '
      '  AND k.REFERENCED_TABLE_NAME IS NOT NULL',
    );

    for (final row in fkRows.rows) {
      final values = row.assoc();
      final tableName = values['TABLE_NAME'];
      final sourceColumn = values['COLUMN_NAME'];
      final targetTable = values['REFERENCED_TABLE_NAME'];
      final targetColumn = values['REFERENCED_COLUMN_NAME'];
      if (tableName == null ||
          sourceColumn == null ||
          targetTable == null ||
          targetColumn == null) {
        continue;
      }

      final onDeleteCascade =
          (values['DELETE_RULE'] ?? '').toUpperCase() == 'CASCADE';
      foreignKeys.putIfAbsent(tableName, () => []).add(
        SchemaForeignKey(
          sourceColumn: sourceColumn,
          targetTable: targetTable,
          targetColumn: targetColumn,
          onDeleteCascade: onDeleteCascade,
        ),
      );
    }

    for (final entry in tableColumns.entries) {
      tables[entry.key] = SchemaTable(
        name: entry.key,
        columns: entry.value,
        foreignKeys: foreignKeys[entry.key],
      );
    }

    return SchemaState(tables: tables);
  }

  static ColumnType _mapType(String? dataType) {
    final type = (dataType ?? '').toUpperCase();
    if (type.contains('INT')) return ColumnType.integer;
    if (type == 'UUID') return ColumnType.uuid;
    if (type.contains('CHAR') ||
        type.contains('TEXT') ||
        type.contains('ENUM') ||
        type.contains('SET')) {
      return ColumnType.text;
    }
    if (type.contains('BOOL') || type == 'BIT') return ColumnType.boolean;
    if (type.contains('DOUBLE') ||
        type.contains('FLOAT') ||
        type.contains('DECIMAL') ||
        type.contains('NUMERIC') ||
        type == 'REAL') {
      return ColumnType.doublePrecision;
    }
    if (type.contains('TIMESTAMP') ||
        type.contains('DATE') ||
        type.contains('TIME') ||
        type.contains('YEAR')) {
      return ColumnType.dateTime;
    }
    if (type.contains('JSON')) return ColumnType.json;
    if (type.contains('BLOB') || type.contains('BINARY')) {
      return ColumnType.binary;
    }
    return ColumnType.text;
  }

  static String _adaptSql(String sql) {
    var adapted = sql;
    adapted = adapted.replaceAll(_autoIncPkExp, 'AUTO_INCREMENT PRIMARY KEY');
    adapted = adapted.replaceAll(_pkAutoIncExp, 'AUTO_INCREMENT PRIMARY KEY');
    adapted = adapted.replaceAll(_autoIncExp, 'AUTO_INCREMENT');
    adapted = adapted.replaceAll(_uuidExp, 'CHAR(36)');

    if (_onConflictDoNothingExp.hasMatch(adapted) &&
        _insertIntoExp.hasMatch(adapted)) {
      adapted = adapted.replaceFirst(_insertIntoExp, 'INSERT IGNORE INTO');
      adapted = adapted.replaceFirst(_onConflictDoNothingExp, '');
    }

    return adapted;
  }

  static String _prepareSql(String sql) {
    return _adaptSql(sql);
  }

  static Future<IResultSet> _runWithParams(
    MySQLConnection conn,
    String sql,
    List<Object?> params,
  ) async {
    if (params.isEmpty) {
      return conn.execute(sql);
    }

    final prepared = await conn.prepare(sql);
    try {
      return await prepared.execute(params);
    } finally {
      await prepared.deallocate();
    }
  }

  @override
  bool get supportsAlterTableAddConstraint => true;

  @override
  String placeholderFor(int index) => '?';
}

class _MySqlSessionEngine implements EngineAdapter {
  _MySqlSessionEngine(this._conn);

  final MySQLConnection _conn;

  @override
  Future<void> open() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> executeBatch(List<ParameterizedQuery> statements) async {
    for (final statement in statements) {
      final sql = MySqlEngine._prepareSql(statement.sql);
      if (statement.params.isEmpty) {
        await _conn.execute(sql);
        continue;
      }
      final prepared = await _conn.prepare(sql);
      try {
        await prepared.execute(statement.params);
      } finally {
        await prepared.deallocate();
      }
    }
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String sql, [
    List<Object?> params = const [],
  ]) async {
    final preparedSql = MySqlEngine._prepareSql(sql);
    final result = await MySqlEngine._runWithParams(_conn, preparedSql, params);
    return result.rows
        .map((row) => row.typedAssoc().cast<String, dynamic>())
        .toList(growable: false);
  }

  @override
  Future<int> execute(String sql, [List<Object?> params = const []]) async {
    final preparedSql = MySqlEngine._prepareSql(sql);
    final result = await MySqlEngine._runWithParams(_conn, preparedSql, params);
    return result.affectedRows.toInt();
  }

  @override
  Future<SchemaState> readSchema() => MySqlEngine._readSchemaWithConnection(_conn);

  @override
  Future<T> transaction<T>(Future<T> Function(EngineAdapter txEngine) action) {
    return action(this);
  }

  @override
  Future<void> ensureHistoryTable() {
    return _conn.execute(
      MySqlEngine._adaptSql(
        'CREATE TABLE IF NOT EXISTS _loxia_migrations (\n'
        '  version BIGINT PRIMARY KEY,\n'
        '  applied_at TIMESTAMP,\n'
        '  description TEXT\n'
        ')',
      ),
    );
  }

  @override
  Future<List<int>> getAppliedVersions() async {
    final result = await _conn.execute(
      'SELECT version FROM _loxia_migrations ORDER BY version',
    );
    return result.rows
        .map((row) => row.typedColByName<num>('version'))
        .whereType<num>()
        .map((value) => value.toInt())
        .toList(growable: false);
  }

  @override
  bool get supportsAlterTableAddConstraint => true;

  @override
  String placeholderFor(int index) => '?';
}