import 'package:loxia/src/datasource/engine_adapter.dart';
import 'package:loxia/src/repository/dtos.dart';

import '../entity.dart';
import '../repository/entity_repository.dart';
import '../repository/query.dart';
import 'column_descriptor.dart';
import 'index_descriptor.dart';
import 'relation_descriptor.dart';

typedef EntityFromRow<T extends Entity> = T Function(Map<String, dynamic> row);
typedef EntityToRow<T extends Entity> = Map<String, dynamic> Function(T entity);

/// Runtime description of an entity, referenced by repositories and builders.
class EntityDescriptor<T extends Entity, P extends PartialEntity<T>> {
	EntityDescriptor({
		required this.entityType,
		required this.tableName,
		this.schema,
		required List<ColumnDescriptor> columns,
		List<RelationDescriptor> relations = const [],
		List<IndexDescriptor> indexes = const [],
		required this.fromRow,
		required this.toRow,
    required this.fieldsContext,
    required this.repositoryFactory,
	})  : columns = List.unmodifiable(columns),
				relations = List.unmodifiable(relations),
				indexes = List.unmodifiable(indexes);

	final Type entityType;
	final String tableName;
	final String? schema;
	final List<ColumnDescriptor> columns;
	final List<RelationDescriptor> relations;
	final List<IndexDescriptor> indexes;
	final EntityFromRow<T> fromRow;
	final EntityToRow<T> toRow;
  final QueryFieldsContext<T> fieldsContext;
  final EntityRepository<T, P> Function(EngineAdapter engine) repositoryFactory;

	ColumnDescriptor? get primaryKey {
		for (final column in columns) {
			if (column.isPrimaryKey) {
				return column;
			}
		}
		return null;
	}

	String get qualifiedTableName => schema == null ? tableName : '$schema.$tableName';

	Map<String, dynamic> toMap(T entity) => toRow(entity);

	T fromMap(Map<String, dynamic> row) => fromRow(row);
}
