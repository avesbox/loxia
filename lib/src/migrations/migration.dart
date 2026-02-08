import '../datasource/engine_adapter.dart';

/// Base class for database migrations.
abstract class Migration {
  const Migration(this.version);

  /// Unique, increasing migration version number.
  final int version;

  /// Apply the migration.
  Future<void> up(EngineAdapter engine);

  /// Revert the migration.
  Future<void> down(EngineAdapter engine);
}
