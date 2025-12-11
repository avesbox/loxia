import '../entity.dart';
import '../metadata/entity_descriptor.dart';
import '../migrations/planner.dart';
import '../repository/dtos.dart';
import '../repository/entity_repository.dart';
import 'engine_adapter.dart';

class DataSourceOptions {
  final EngineAdapter engine;
  final List<EntityDescriptor> entities;
  final bool runMigrations;

  const DataSourceOptions({
    required this.engine,
    required this.entities,
    this.runMigrations = true,
  });
}

/// Main entrypoint coordinating engine, migrations, and repositories.
class DataSource {
  DataSource(this.options);

  final DataSourceOptions options;
  EngineAdapter get _engine => options.engine;
  final Map<Type, EntityDescriptor> _registry = {};

  Future<void> init() async {
    await _engine.open();
    // Register entities for repository lookup
    for (final d in options.entities) {
      _registry[d.entityType] = d;
    }
    if (options.runMigrations) {
      final planner = MigrationPlanner();
      final current = await _engine.readSchema();
      final plan = planner.diff(entities: options.entities, current: current);
      if (!plan.isEmpty) {
        await _engine.executeBatch(plan.statements);
      }
    }
  }

  Future<void> dispose() async {
    await _engine.close();
  }

  /// Returns a repository for the given entity type.
  /// 
  /// [T] is the entity type, [P] is the corresponding partial entity type.
  /// The partial type must match the one generated for the entity.
  EntityRepository<T, P> getRepository<T extends Entity, P extends PartialEntity<T>>() {
    final desc = _registry[T];
    if (desc == null) {
      throw StateError('Entity ${T.toString()} is not registered in this DataSource');
    }
    final typed = desc as EntityDescriptor<T, P>;
    return EntityRepository<T, P>(typed, _engine, desc.fieldsContext);
  }
}
