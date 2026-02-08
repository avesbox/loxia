import 'dart:collection';

import '../entity.dart';
import '../metadata/entity_descriptor.dart';
import '../migrations/migration.dart';
import '../migrations/planner.dart';
import '../repository/dtos.dart';
import '../repository/entity_repository.dart';
import 'engine_adapter.dart';

abstract class DataSourceOptions {
  final EngineAdapter engine;
  final List<EntityDescriptor> entities;
  final List<Migration> migrations;

  const DataSourceOptions({
    required this.engine,
    required this.entities,
    this.migrations = const [],
  });
}

/// Main entrypoint coordinating engine, migrations, and repositories.
class DataSource {
  DataSource(this.options);

  final DataSourceOptions options;
  EngineAdapter get _engine => options.engine;
  final Map<Type, EntityDescriptor> _registry = {};
  final Map<Type, EntityRepository> _repositories = {};

  Map<Type, EntityRepository> get repositories =>
      UnmodifiableMapView(_repositories);

  Future<void> init() async {
    await _engine.open();
    // Register entities for repository lookup
    for (final d in options.entities) {
      _registry[d.entityType] = d;
      _repositories[d.entityType] = d.repositoryFactory(_engine);
    }
    EntityDescriptor.registerAll(options.entities);

    await _engine.ensureHistoryTable();
    final applied = await _engine.getAppliedVersions();
    final migrations = options.migrations;
    final migrationVersions = migrations.map((m) => m.version).toSet();
    final missingInCode = applied
        .where((v) => !migrationVersions.contains(v))
        .toList();
    if (missingInCode.isNotEmpty) {
      throw StateError(
        'Migration history mismatch. Database contains versions not present in code: $missingInCode',
      );
    }

    final pending =
        migrations
            .where((m) => !applied.contains(m.version))
            .toList(growable: false)
          ..sort((a, b) => a.version.compareTo(b.version));

    for (final migration in pending) {
      print('Applying migration ${migration.version}...');
      await _engine.transaction((txEngine) async {
        await migration.up(txEngine);
        await txEngine.execute(
          'INSERT INTO _loxia_migrations (version, applied_at) VALUES (?, CURRENT_TIMESTAMP)',
          [migration.version],
        );
      });
    }

    final planner = MigrationPlanner();
    final current = await _engine.readSchema();
    final plan = planner.diff(entities: options.entities, current: current);
    if (!plan.isEmpty) {
      await _engine.executeBatch(plan.statements);
    }
  }

  Future<void> dispose() async {
    await _engine.close();
  }

  /// Returns a repository for the given entity type.
  ///
  /// [T] is the entity type, [P] is the corresponding partial entity type.
  /// The partial type must match the one generated for the entity.
  EntityRepository<T, PartialEntity<T>> getRepository<T extends Entity>() {
    final repo = _repositories[T];
    if (repo == null) {
      throw StateError(
        'Entity ${T.toString()} is not registered in this DataSource',
      );
    }
    return repo as EntityRepository<T, PartialEntity<T>>;
  }

  /// Returns a repository for the given entity descriptor.
  /// [T] is the entity type, [P] is the corresponding partial entity type.
  /// The partial type must match the one generated for the entity.
  ///
  /// Throws a [StateError] if the entity type is not registered.
  ///
  /// [descriptor] is the entity descriptor to get the repository for.
  EntityRepository<T, PartialEntity<T>> getRepositoryFromDescriptor<
    T extends Entity
  >(EntityDescriptor<T, PartialEntity<T>> descriptor) {
    return EntityRepository<T, PartialEntity<T>>(
      descriptor,
      _engine,
      descriptor.fieldsContext,
    );
  }

  /// Executes the provided action within a transactional context.
  Future<T> transaction<T>(Future<T> Function(LoxiaTransaction tx) action) {
    return _engine.transaction((txEngine) async {
      final tx = LoxiaTransaction._(_registry, txEngine);
      return action(tx);
    });
  }
}

/// Transactional context for repository access.
class LoxiaTransaction {
  LoxiaTransaction._(this._registry, this._engine);

  final Map<Type, EntityDescriptor> _registry;
  final EngineAdapter _engine;

  /// Returns a repository bound to this transaction.
  EntityRepository<T, PartialEntity<T>> getRepository<T extends Entity>() {
    final descriptor = _registry[T];
    if (descriptor == null) {
      throw StateError(
        'Entity ${T.toString()} is not registered in this DataSource',
      );
    }
    return (descriptor as EntityDescriptor<T, PartialEntity<T>>)
        .repositoryFactory(_engine);
  }
}
