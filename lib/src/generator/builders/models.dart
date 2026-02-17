/// Internal models used by the entity code generators.
///
/// These models hold the parsed metadata from annotated entity classes
/// and are used by the builder classes to generate code.
library;

import 'package:loxia/loxia.dart';

import '../../annotations/column.dart' show ColumnType;

/// Represents a parsed column from an entity class.
class GenColumn {
  GenColumn({
    required this.name,
    required this.prop,
    required this.type,
    required this.dartTypeCode,
    required this.isEnum,
    this.enumTypeName,
    required this.nullable,
    required this.unique,
    required this.isPk,
    required this.autoIncrement,
    required this.uuid,
    this.isCreatedAt = false,
    this.isUpdatedAt = false,
    this.defaultLiteral,
  });

  final String name;
  final String prop;
  final ColumnType type;
  final String dartTypeCode;
  final bool isEnum;
  final String? enumTypeName;
  final bool nullable;
  final bool unique;
  final bool isPk;
  final bool autoIncrement;
  final bool uuid;
  final bool isCreatedAt;
  final bool isUpdatedAt;
  final String? defaultLiteral;
}

/// Represents a parsed join column configuration.
class GenJoinColumn {
  GenJoinColumn({
    required this.name,
    required this.referencedColumnName,
    required this.nullable,
    required this.unique,
  });

  final String name;
  final String referencedColumnName;
  final bool nullable;
  final bool unique;
}

/// Represents a parsed join table configuration.
class GenJoinTable {
  GenJoinTable({
    required this.name,
    required this.joinColumns,
    required this.inverseJoinColumns,
  });

  final String name;
  final List<GenJoinColumn> joinColumns;
  final List<GenJoinColumn> inverseJoinColumns;
}

/// Kinds of relations supported.
enum RelationKind { oneToOne, oneToMany, manyToOne, manyToMany }

/// Represents a parsed relation from an entity class.
class GenRelation {
  GenRelation({
    required this.fieldName,
    required this.type,
    required this.targetTypeCode,
    required this.isOwningSide,
    required this.mappedBy,
    required this.fetchLiteral,
    required this.cascadeLiteral,
    required this.cascadePersist,
    required this.cascadeMerge,
    required this.cascadeRemove,
    this.joinColumn,
    this.joinTable,
    this.constructorLiteral,
    this.joinColumnPropertyName,
    this.joinColumnBaseDartType,
    this.joinColumnNullable = true,
    this.targetPrimaryFieldName,
    this.isCollection = false,
  });

  final String fieldName;
  final RelationKind type;
  final String targetTypeCode;
  final bool isOwningSide;
  final String? mappedBy;
  final String fetchLiteral;
  final String cascadeLiteral;
  final bool cascadePersist;
  final bool cascadeMerge;
  final bool cascadeRemove;
  final GenJoinColumn? joinColumn;
  final GenJoinTable? joinTable;
  final String? constructorLiteral;
  final String? joinColumnPropertyName;
  final String? joinColumnBaseDartType;
  final bool joinColumnNullable;
  final String? targetPrimaryFieldName;
  final bool isCollection;
}

/// Primary key information for an entity.
class PrimaryKeyInfo {
  const PrimaryKeyInfo({
    required this.propertyName,
    required this.columnName,
    required this.dartTypeCode,
  });

  final String propertyName;
  final String columnName;
  final String dartTypeCode;
}

/// Context object containing all parsed metadata for entity code generation.
class EntityGenerationContext {
  EntityGenerationContext({
    required this.className,
    required this.tableName,
    this.schema,
    required this.columns,
    required this.queries,
    required this.relations,
    this.omitNullJsonFields = true,
    Map<String, List<String>>? hooks,
    List<GenTimestampField>? createdAtFields,
    List<GenTimestampField>? updatedAtFields,
    List<GenUniqueConstraint>? uniqueConstraints,
  }) : hooks = hooks ?? const {},
       createdAtFields = createdAtFields ?? const [],
       updatedAtFields = updatedAtFields ?? const [],
       uniqueConstraints = uniqueConstraints ?? const [];

  final String className;
  final String tableName;
  final String? schema;
  final List<GenColumn> columns;
  final List<GenRelation> relations;
  final Map<String, List<String>> hooks;
  final List<GenQuery> queries;
  final List<GenTimestampField> createdAtFields;
  final List<GenTimestampField> updatedAtFields;
  final List<GenUniqueConstraint> uniqueConstraints;
  final bool omitNullJsonFields;

  /// Entity class name.
  String get entityName => className;

  /// Partial entity class name.
  String get partialEntityName => '${className}Partial';

  /// Fields context class name.
  String get fieldsContextName => '${className}FieldsContext';

  /// Query builder class name.
  String get queryClassName => '${className}Query';

  /// Select options class name.
  String get selectClassName => '${className}Select';

  /// Relations class name.
  String get relationsClassName => '${className}Relations';

  /// Insert DTO class name.
  String get insertDtoName => '${className}InsertDto';

  /// Update DTO class name.
  String get updateDtoName => '${className}UpdateDto';

  /// Entity descriptor variable name.
  String get descriptorVarName => '\$${className}EntityDescriptor';

  /// Internal codec init function name.
  String get codecInitFunctionName => '\$init${className}JsonCodec';

  /// Internal codec initialized flag variable name.
  String get codecInitializedFlagName => '\$is${className}JsonCodecInitialized';

  /// Relations with owning join columns (ManyToOne, OneToOne owning).
  List<GenRelation> get owningJoinColumns =>
      relations.where((r) => r.joinColumn != null && r.isOwningSide).toList();

  /// ManyToMany relations (owning side with join table).
  List<GenRelation> get manyToManyRelations => relations
      .where((r) => r.type == RelationKind.manyToMany && r.isOwningSide)
      .toList();

  /// Inverse relations (not owning side with mappedBy).
  List<GenRelation> get inverseRelations =>
      relations.where((r) => !r.isOwningSide && r.mappedBy != null).toList();

  /// All selectable relations (owning, manyToMany, and inverse).
  List<GenRelation> get allSelectableRelations => [
    ...owningJoinColumns,
    ...manyToManyRelations,
    ...inverseRelations,
  ];

  /// Primary key column.
  GenColumn get primaryKeyColumn =>
      columns.firstWhere((c) => c.isPk, orElse: () => columns.first);

  /// Whether the entity has collection relations.
  bool get hasCollectionRelations =>
      inverseRelations.any((r) => r.isCollection);
}

/// Represents a timestamp field to be managed by lifecycle hooks.
class GenTimestampField {
  GenTimestampField({required this.fieldName, required this.valueExpression});

  final String fieldName;
  final String valueExpression;
}

class GenQuery {
  GenQuery({
    required this.name,
    required this.sql,
    required this.lifecycleHooks,
    this.analysisResult,
  });

  final String name;
  final String sql;
  final List<String> lifecycleHooks;

  /// The result of SQL analysis for this query.
  /// Populated during generation for compile-time validation.
  GenQueryAnalysisResult? analysisResult;
}

/// Result of SQL analysis for a query.
class GenQueryAnalysisResult {
  GenQueryAnalysisResult({
    required this.columns,
    required this.matchesEntity,
    required this.matchesPartialEntity,
    required this.hasJoins,
    required this.hasAggregates,
    required this.isSingleResult,
    required this.dtoClassName,
  });

  /// The resolved columns from the SELECT statement.
  final List<GenQueryColumn> columns;

  /// Whether the columns exactly match the entity's columns.
  final bool matchesEntity;

  /// Whether the columns are a subset of the entity's columns.
  final bool matchesPartialEntity;

  /// Whether the query contains JOINs.
  final bool hasJoins;

  /// Whether the query contains aggregate functions.
  final bool hasAggregates;

  /// Whether the query returns a single result (LIMIT 1 or aggregate without GROUP BY).
  final bool isSingleResult;

  /// The generated DTO class name if needed.
  final String dtoClassName;

  /// Returns true if a DTO class needs to be generated.
  bool get requiresDto => !matchesEntity && !matchesPartialEntity;
}

/// A resolved column from SQL analysis.
class GenQueryColumn {
  GenQueryColumn({
    required this.name,
    required this.dartType,
    required this.nullable,
    this.originalColumnName,
  });

  /// The name of the column in the result (may be alias).
  final String name;

  /// The Dart type to use for this column.
  final String dartType;

  /// Whether the column is nullable.
  final bool nullable;

  /// The original column name if this is an alias.
  final String? originalColumnName;
}

/// Represents a composite unique constraint for code generation.
class GenUniqueConstraint {
  GenUniqueConstraint({required this.columns, this.name});

  /// The list of column names that form the unique constraint.
  final List<String> columns;

  /// Optional constraint name.
  final String? name;
}
