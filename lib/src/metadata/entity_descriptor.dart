import 'package:loxia/src/datasource/engine_adapter.dart';
import 'package:loxia/src/repository/dtos.dart';

import '../entity.dart';
import '../repository/entity_repository.dart';
import '../repository/query.dart';
import 'column_descriptor.dart';
import 'index_descriptor.dart';
import 'relation_descriptor.dart';
import 'unique_constraint_descriptor.dart';

typedef EntityFromRow<T extends Entity> = T Function(Map<String, dynamic> row);
typedef EntityToRow<T extends Entity> = Map<String, dynamic> Function(T entity);

/// Runtime description of an entity, referenced by repositories and builders.
class EntityDescriptor<T extends Entity, P extends PartialEntity<T>> {
  static final Map<Type, EntityDescriptor> _registry = {};

  static void registerAll(Iterable<EntityDescriptor> descriptors) {
    _registry
      ..clear()
      ..addEntries(descriptors.map((d) => MapEntry(d.entityType, d)));
  }

  static EntityDescriptor? lookup(Type type) => _registry[type];

  EntityDescriptor({
    required this.entityType,
    required this.tableName,
    this.schema,
    required List<ColumnDescriptor> columns,
    List<RelationDescriptor> relations = const [],
    List<IndexDescriptor> indexes = const [],
    List<UniqueConstraintDescriptor> uniqueConstraints = const [],
    required this.fromRow,
    required this.toRow,
    required this.fieldsContext,
    required this.repositoryFactory,
    this.hooks,
    this.defaultSelect,
  }) : columns = List.unmodifiable(columns),
       relations = List.unmodifiable(relations),
       indexes = List.unmodifiable(indexes),
       uniqueConstraints = List.unmodifiable(uniqueConstraints);

  final Type entityType;
  final String tableName;
  final String? schema;
  final List<ColumnDescriptor> columns;
  final List<RelationDescriptor> relations;
  final List<IndexDescriptor> indexes;
  final List<UniqueConstraintDescriptor> uniqueConstraints;
  final EntityFromRow<T> fromRow;
  final EntityToRow<T> toRow;
  final QueryFieldsContext<T> fieldsContext;
  final EntityRepository<T, P> Function(EngineAdapter engine) repositoryFactory;
  final EntityHooks<T>? hooks;
  final SelectOptions<T, P> Function()? defaultSelect;

  ColumnDescriptor? get primaryKey {
    for (final column in columns) {
      if (column.isPrimaryKey) {
        return column;
      }
    }
    return null;
  }

  String get qualifiedTableName =>
      schema == null ? tableName : '$schema.$tableName';

  Map<String, dynamic> toMap(T entity) => toRow(entity);

  T fromMap(Map<String, dynamic> row) => fromRow(row);
}

/// Optional lifecycle hooks for an entity.
class EntityHooks<T> {
  const EntityHooks({
    this.prePersist,
    this.postPersist,
    this.preUpdate,
    this.postUpdate,
    this.preRemove,
    this.postRemove,
    this.postLoad,
  });

  final void Function(T entity)? prePersist;
  final void Function(T entity)? postPersist;
  final void Function(T entity)? preUpdate;
  final void Function(T entity)? postUpdate;
  final void Function(T entity)? preRemove;
  final void Function(T entity)? postRemove;
  final void Function(T entity)? postLoad;
}
