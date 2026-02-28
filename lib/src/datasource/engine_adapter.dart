import '../migrations/schema.dart';

class ParameterizedQuery {
  const ParameterizedQuery(
    this.sql, {
    this.params = const [],
    this.applyDialectAdaptation = false,
  });

  final String sql;
  final List<Object?> params;
  final bool applyDialectAdaptation;

  const ParameterizedQuery.ddl(this.sql)
    : params = const [],
      applyDialectAdaptation = true;
}

/// Basic interface that each SQL engine adapter must implement.
abstract class EngineAdapter {
  /// Whether the engine supports adding foreign key constraints via
  /// `ALTER TABLE ... ADD CONSTRAINT ...`.
  ///
  /// SQLite does not support this syntax.
  bool get supportsAlterTableAddConstraint => true;

  /// Returns the placeholder token for the 1-based [index].
  ///
  /// SQLite-style engines use `?`, while PostgreSQL uses `$1`, `$2`, ...
  String placeholderFor(int index) => '?';

  Future<void> open();
  Future<void> close();

  /// Returns the current schema snapshot for the connected database.
  Future<SchemaState> readSchema();

  /// Executes a batch of SQL statements, optionally parameterized.
  Future<void> executeBatch(List<ParameterizedQuery> statements);

  /// Executes a query and returns list of rows.
  Future<List<Map<String, dynamic>>> query(
    String sql, [
    List<Object?> params = const [],
  ]);

  /// Executes a command (INSERT/UPDATE/DELETE) and returns affected rows.
  Future<int> execute(String sql, [List<Object?> params = const []]);

  /// Executes the provided action within a transactional context.
  Future<T> transaction<T>(Future<T> Function(EngineAdapter txEngine) action);

  /// Ensures the migration history table exists.
  ///
  /// Table: _loxia_migrations
  /// Columns:
  /// - version INTEGER PRIMARY KEY
  /// - applied_at TIMESTAMP
  /// - description TEXT NULL
  Future<void> ensureHistoryTable();

  /// Returns applied migration versions, sorted ascending.
  Future<List<int>> getAppliedVersions();
}
