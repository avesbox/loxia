import '../migrations/schema.dart';

/// Basic interface that each SQL engine adapter must implement.
abstract class EngineAdapter {
  Future<void> open();
  Future<void> close();

  /// Returns the current schema snapshot for the connected database.
  Future<SchemaState> readSchema();

  /// Executes a batch of DDL statements.
  Future<void> executeBatch(List<String> statements);

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
