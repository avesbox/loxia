import 'dart:async';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:loxia/src/generator/builders/repository_extensions_builder.dart';
import 'package:loxia/src/generator/util/sql_analyzer.dart';
import 'package:source_gen/source_gen.dart';

import '../../loxia.dart'
    show
        Column,
        ColumnType,
        CreatedAt,
        UpdatedAt,
        EntityMeta,
        JoinColumn,
        JoinTable,
        ManyToMany,
        ManyToOne,
        OneToMany,
        OneToOne,
        PrePersist,
        PostPersist,
        PreUpdate,
        PostUpdate,
        PreRemove,
        PostRemove,
        PostLoad,
        PrimaryKey;
import 'builders/builders.dart';

/// Code generator for entities annotated with [EntityMeta].
///
/// This generator creates:
/// - Entity descriptor with column and relation metadata
/// - Fields context for query building
/// - Query builder class
/// - Select options class
/// - Relations class
/// - Partial entity class
/// - Insert and Update DTOs
class LoxiaEntityGenerator extends GeneratorForAnnotation<EntityMeta> {
  /// Emitter for generating code.
  final _emitter = DartEmitter(useNullSafetySyntax: true);

  /// Formatter for generated code.
  final _formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );

  /// Builders for each generated component.
  final _entityDescriptorBuilder = const EntityDescriptorBuilder();
  final _fieldsContextBuilder = const FieldsContextBuilder();
  final _queryClassBuilder = const QueryClassBuilder();
  final _selectOptionsBuilder = const SelectOptionsBuilder();
  final _relationsClassBuilder = const RelationsClassBuilder();
  final _partialEntityBuilder = const PartialEntityBuilder();
  final _insertDtoBuilder = const InsertDtoBuilder();
  final _updateDtoBuilder = const UpdateDtoBuilder();
  final _repositoryClassBuilder = const RepositoryClassBuilder();
  final _jsonExtensionBuilder = const JsonExtensionBuilder();
  final _codecBuilder = const CodecBuilder();
  final _repositoryExtensionsBuilder = const RepositoryExtensionsBuilder();
  final _queryResultDtoBuilder = const QueryResultDtoBuilder();

  @override
  Future<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    if (element is! ClassElement) return '';
    final clazz = element;
    if (clazz.isAbstract) return '';

    // Parse metadata from annotations
    final context = _parseEntityContext(clazz, annotation);

    // Analyze SQL queries at compile-time
    _analyzeQueries(context);

    // Build all code components
    final library = Library(
      (lib) => lib
        ..body.add(_entityDescriptorBuilder.build(context))
        ..body.add(_fieldsContextBuilder.build(context))
        ..body.add(_queryClassBuilder.build(context))
        ..body.add(_selectOptionsBuilder.build(context))
        ..body.add(_relationsClassBuilder.build(context))
        ..body.add(_partialEntityBuilder.build(context))
        ..body.add(_insertDtoBuilder.build(context))
        ..body.add(_updateDtoBuilder.build(context))
        ..body.add(_repositoryClassBuilder.build(context))
        ..body.add(_jsonExtensionBuilder.build(context))
        ..body.addAll(_codecBuilder.buildAll(context))
        // Add query result DTOs before the extension that uses them
        ..body.addAll(_queryResultDtoBuilder.buildAll(context))
        ..body.add(_repositoryExtensionsBuilder.build(context)),
    );

    // Emit and format the generated code
    final code = library.accept(_emitter).toString();
    return _formatter.format(code);
  }

  /// Parses the entity class and its annotations into a generation context.
  EntityGenerationContext _parseEntityContext(
    ClassElement clazz,
    ConstantReader annotation,
  ) {
    final className = clazz.displayName;
    final table = annotation.peek('table')?.stringValue ?? _toSnake(className);
    final schema = annotation.peek('schema')?.stringValue;
    final queries = _parseQueries(annotation);
    final columns = _parseColumns(clazz);
    final relations = _parseRelations(clazz, className, table);
    final hooks = _parseHooks(clazz);
    final timestamps = _parseTimestampFields(clazz);
    final uniqueConstraints = _parseUniqueConstraints(annotation);
    final omitNullJsonFields = annotation.peek('omitNullJsonFields')?.boolValue ?? true;

    return EntityGenerationContext(
      className: className,
      tableName: table,
      schema: schema,
      columns: columns,
      relations: relations,
      hooks: hooks,
      queries: queries,
      createdAtFields: timestamps.createdAt,
      updatedAtFields: timestamps.updatedAt,
      uniqueConstraints: uniqueConstraints,
      omitNullJsonFields: omitNullJsonFields,
    );
  }

  List<GenUniqueConstraint> _parseUniqueConstraints(ConstantReader annotation) {
    final constraintsReader = annotation.peek('uniqueConstraints');
    if (constraintsReader == null) return [];
    final constraintObjs = constraintsReader.listValue;
    final constraints = <GenUniqueConstraint>[];
    for (final obj in constraintObjs) {
      final reader = ConstantReader(obj);
      final columnsReader = reader.peek('columns')?.listValue ?? [];
      final columns = columnsReader
          .map((v) => ConstantReader(v).stringValue)
          .toList();
      final name = reader.peek('name')?.stringValue;
      if (columns.isEmpty) {
        throw InvalidGenerationSourceError(
          'Each UniqueConstraint must have at least one column.',
        );
      }
      constraints.add(GenUniqueConstraint(columns: columns, name: name));
    }
    return constraints;
  }

  List<GenQuery> _parseQueries(ConstantReader annotation) {
    final queriesReader = annotation.peek('queries');
    if (queriesReader == null) return [];
    final queryObjs = queriesReader.listValue;
    final queries = <GenQuery>[];
    for (final obj in queryObjs) {
      final reader = ConstantReader(obj);
      final name = reader.peek('name')?.stringValue;
      final sql = reader.peek('sql')?.stringValue;
      if (name == null || sql == null) {
        throw InvalidGenerationSourceError(
          'Each Query must have a non-null name and sql.',
        );
      }
      final lifecycleHooksReader =
          reader.peek('lifecycleHooks')?.listValue ?? [];
      final lifecycleHooks = <String>[];
      for (final hook in lifecycleHooksReader) {
        final revieved = ConstantReader(hook).revive();
        lifecycleHooks.add(revieved.accessor.replaceFirst('Lifecycle.', ''));
      }
      queries.add(
        GenQuery(name: name, sql: sql, lifecycleHooks: lifecycleHooks),
      );
    }
    return queries;
  }

  /// Analyzes all queries in the context using the SQL analyzer.
  ///
  /// This populates the [GenQuery.analysisResult] field for each query
  /// with compile-time type information extracted from the SQL.
  void _analyzeQueries(EntityGenerationContext context) {
    if (context.queries.isEmpty) return;

    final analyzer = SqlAnalyzer(context);

    for (final query in context.queries) {
      final analysis = analyzer.analyze(query.name, query.sql);

      // Convert analyzer result to GenQueryAnalysisResult
      query.analysisResult = GenQueryAnalysisResult(
        columns: analysis.columns
            .map(
              (c) => GenQueryColumn(
                name: c.name,
                dartType: c.dartType,
                nullable: c.nullable,
                originalColumnName: c.originalColumnName,
              ),
            )
            .toList(),
        matchesEntity: analysis.matchesEntity,
        matchesPartialEntity: analysis.matchesPartialEntity,
        hasJoins: analysis.hasJoins,
        hasAggregates: analysis.hasAggregates,
        isSingleResult: analysis.isSingleResult,
        dtoClassName: analysis.dtoClassName,
      );

      // Validate parameters
      final sqlParams = _extractSqlParams(query.sql);
      final unknownParams = analyzer.validateVariables(query.name, sqlParams);

      if (unknownParams.isNotEmpty) {
        // Log a warning but don't fail - params might be intentionally custom
        print(
          'Warning: Query "${query.name}" on ${context.className} uses '
          'parameters not found as columns: ${unknownParams.join(', ')}. '
          'Ensure these match entity property names.',
        );
      }
    }
  }

  /// Extracts parameter names from SQL (e.g., @id, @name -> ['id', 'name'])
  List<String> _extractSqlParams(String sql) {
    final regex = RegExp(r'@(\w+)');
    return regex.allMatches(sql).map((m) => m.group(1)!).toList();
  }

  _TimestampFields _parseTimestampFields(ClassElement clazz) {
    final createdAt = <GenTimestampField>[];
    final updatedAt = <GenTimestampField>[];

    for (final field in clazz.fields.where((f) => !f.isStatic)) {
      final hasCreatedAt = _firstAnnotation(field, CreatedAt) != null;
      final hasUpdatedAt = _firstAnnotation(field, UpdatedAt) != null;
      if (!hasCreatedAt && !hasUpdatedAt) continue;

      final valueExpression = _timestampValueExpression(field);
      final model = GenTimestampField(
        fieldName: field.displayName,
        valueExpression: valueExpression,
      );
      if (hasCreatedAt) createdAt.add(model);
      if (hasUpdatedAt) updatedAt.add(model);
    }

    return _TimestampFields(createdAt: createdAt, updatedAt: updatedAt);
  }

  String _timestampValueExpression(FieldElement field) {
    var typeName = field.type.getDisplayString();
    if (field.type.nullabilitySuffix == NullabilitySuffix.question) {
      typeName = typeName.substring(0, typeName.length - 1);
    }
    switch (typeName) {
      case 'DateTime':
        return 'DateTime.now()';
      case 'int':
        return 'DateTime.now().millisecondsSinceEpoch';
      case 'double':
        return 'DateTime.now().millisecondsSinceEpoch.toDouble()';
      case 'String':
        return 'DateTime.now().toIso8601String()';
      default:
        throw InvalidGenerationSourceError(
          'Unsupported timestamp field type ${field.type.getDisplayString()} on ${field.enclosingElement.displayName}.${field.displayName}. '
          'Use DateTime, int, double, or String.',
          element: field,
        );
    }
  }

  Map<String, List<String>> _parseHooks(ClassElement clazz) {
    final hooks = <String, List<String>>{};
    final hookTypes = <Type, String>{
      PrePersist: 'prePersist',
      PostPersist: 'postPersist',
      PreUpdate: 'preUpdate',
      PostUpdate: 'postUpdate',
      PreRemove: 'preRemove',
      PostRemove: 'postRemove',
      PostLoad: 'postLoad',
    };

    for (final method in clazz.methods.where((m) => !m.isStatic)) {
      final matching = <String>[];
      for (final entry in hookTypes.entries) {
        if (_hasAnnotation(method, entry.key)) {
          matching.add(entry.value);
        }
      }
      if (matching.isEmpty) continue;
      _validateHookSignature(clazz, method);
      for (final hookName in matching) {
        (hooks[hookName] ??= <String>[]).add(method.displayName);
      }
    }
    return hooks;
  }

  bool _hasAnnotation(MethodElement method, Type t) {
    final want = t.toString();
    final metas = (method.metadata as dynamic);
    final iterable = (metas is Iterable)
        ? metas
        : (metas.annotations as Iterable);
    for (final meta in iterable) {
      final obj = meta.computeConstantValue();
      if (obj == null) continue;
      final typeName = obj.type?.getDisplayString();
      if (typeName == want) return true;
    }
    return false;
  }

  void _validateHookSignature(ClassElement clazz, MethodElement method) {
    if (method.formalParameters.isNotEmpty) {
      throw InvalidGenerationSourceError(
        'Lifecycle hook ${clazz.displayName}.${method.displayName} must not accept parameters.',
        element: method,
      );
    }
    if (method.returnType.getDisplayString() != 'void') {
      throw InvalidGenerationSourceError(
        'Lifecycle hook ${clazz.displayName}.${method.displayName} must return void.',
        element: method,
      );
    }
    if (method.firstFragment.isAsynchronous) {
      throw InvalidGenerationSourceError(
        'Lifecycle hook ${clazz.displayName}.${method.displayName} must be synchronous (not async).',
        element: method,
      );
    }
  }

  /// Parses column definitions from entity fields.
  List<GenColumn> _parseColumns(ClassElement clazz) {
    final columns = <GenColumn>[];

    for (final field in clazz.fields.where((f) => !f.isStatic)) {
      final primaryAnnObj = _firstAnnotation(field, PrimaryKey);
      final colAnnObj = _firstAnnotation(field, Column) ?? primaryAnnObj;
      final createdAtAnn = _firstAnnotation(field, CreatedAt);
      final updatedAtAnn = _firstAnnotation(field, UpdatedAt);
      if (colAnnObj == null && createdAtAnn == null && updatedAtAnn == null) {
        continue;
      }
      final colAnn = colAnnObj == null ? null : ConstantReader(colAnnObj);
      final primaryAnn = primaryAnnObj == null
          ? null
          : ConstantReader(primaryAnnObj);

      final isPk = primaryAnnObj != null;
      final colName =
          colAnn?.peek('name')?.stringValue ?? _toSnake(field.displayName);
      final dartType = field.type;
      final isEnumType =
          dartType is InterfaceType && dartType.element is EnumElement;
      final enumTypeName = isEnumType
          ? _stripNullability(dartType.getDisplayString())
          : null;
      final nullable = dartType.nullabilitySuffix != NullabilitySuffix.none;
      final unique = colAnn?.peek('unique')?.boolValue ?? false;
      final defaultValue = colAnn?.peek('defaultValue')?.objectValue;

      final autoInc = isPk
          ? (primaryAnn?.peek('autoIncrement')?.boolValue ?? false)
          : false;
      final uuid = isPk
          ? (primaryAnn?.peek('uuid')?.boolValue ?? false)
          : false;

      final isCreatedAt = createdAtAnn != null;
      final isUpdatedAt = updatedAtAnn != null;

      var type = (createdAtAnn != null || updatedAtAnn != null)
          ? ColumnType.dateTime
          : _resolveColumnType(
              colAnn,
              dartType,
              isEnum: isEnumType,
              field: field,
            );
      if (uuid) {
        type = ColumnType.uuid;
      }
      final dartTypeCode = dartType.getDisplayString();

      columns.add(
        GenColumn(
          name: colName,
          prop: field.displayName,
          type: type,
          dartTypeCode: dartTypeCode,
          isEnum: isEnumType,
          enumTypeName: enumTypeName,
          nullable: nullable,
          unique: unique,
          isPk: isPk,
          autoIncrement: autoInc,
          uuid: uuid,
          isCreatedAt: isCreatedAt,
          isUpdatedAt: isUpdatedAt,
          defaultLiteral: _dartObjToLiteral(defaultValue),
        ),
      );
    }

    return columns;
  }

  /// Parses relation definitions from entity fields.
  List<GenRelation> _parseRelations(
    ClassElement clazz,
    String entityName,
    String tableName,
  ) {
    final relations = <GenRelation>[];

    for (final field in clazz.fields.where((f) => !f.isStatic)) {
      final relation = _buildRelation(field, entityName, tableName);
      if (relation != null) {
        relations.add(relation);
      }
    }

    return relations;
  }

  DartObject? _firstAnnotation(FieldElement field, Type t) {
    final want = t.toString();
    final metas = (field.metadata as dynamic);
    final iterable = (metas is Iterable)
        ? metas
        : (metas.annotations as Iterable);
    for (final meta in iterable) {
      final obj = meta.computeConstantValue();
      if (obj == null) continue;
      final typeName = obj.type?.getDisplayString();
      if (typeName == want) return obj;
    }
    return null;
  }

  GenRelation? _buildRelation(
    FieldElement field,
    String entityName,
    String tableName,
  ) {
    final match = _findRelationAnnotation(field);
    if (match == null) return null;
    final reader = match.reader;
    final onType = reader.peek('on')?.typeValue;
    if (onType == null) {
      throw InvalidGenerationSourceError(
        'Relation on $entityName.${field.displayName} must specify the `on` target type.',
        element: field,
      );
    }
    final targetTypeCode = onType.getDisplayString();
    if (onType.nullabilitySuffix == NullabilitySuffix.question) {
      throw InvalidGenerationSourceError(
        'Relation target type on $entityName.${field.displayName} cannot be nullable.',
        element: field,
      );
    }
    if (onType is! InterfaceType) {
      throw InvalidGenerationSourceError(
        'Relation target type on $entityName.${field.displayName} must be a class.',
        element: field,
      );
    }
    String? mappedBy = reader.peek('mappedBy')?.stringValue;
    mappedBy = (mappedBy == null || mappedBy.trim().isEmpty)
        ? null
        : mappedBy.trim();
    var isOwning = mappedBy == null;

    switch (match.kind) {
      case RelationKind.oneToMany:
        if (isOwning) {
          throw InvalidGenerationSourceError(
            '@OneToMany on $entityName.${field.displayName} must set mappedBy to the owning @ManyToOne field.',
            element: field,
          );
        }
        isOwning = false;
        break;
      case RelationKind.manyToOne:
        if (!isOwning) {
          throw InvalidGenerationSourceError(
            '@ManyToOne on $entityName.${field.displayName} cannot declare mappedBy; it is always the owning side.',
            element: field,
          );
        }
        mappedBy = null;
        isOwning = true;
        break;
      default:
        break;
    }

    final fetchReader = reader.peek('fetch');
    final fetchLiteral = _enumLiteral(
      fetchReader?.objectValue,
      _fetchStrategyNames,
      'RelationFetchStrategy',
      defaultIndex: 1,
    );

    final cascadeReader = reader.peek('cascade');
    final cascadeValues = cascadeReader == null
        ? const <DartObject>[]
        : cascadeReader.listValue;
    final cascadeLiteral = _enumListLiteral(
      cascadeValues,
      _relationCascadeNames,
      'RelationCascade',
    );
    final cascadePersist = _hasCascadePersist(cascadeValues);
    final cascadeMerge = _hasCascadeMerge(cascadeValues);
    final cascadeRemove = _hasCascadeRemove(cascadeValues);

    final joinColumnAnn = _firstAnnotation(field, JoinColumn);
    final needsJoinColumn =
        isOwning &&
        (match.kind == RelationKind.oneToOne ||
            match.kind == RelationKind.manyToOne);
    final fieldIsNullable =
        field.type.nullabilitySuffix != NullabilitySuffix.none;
    GenJoinColumn? joinColumn;
    if (joinColumnAnn != null) {
      if (!needsJoinColumn) {
        throw InvalidGenerationSourceError(
          '@JoinColumn can only be used on the owning side of a relation.',
          element: field,
        );
      }
      joinColumn = _joinColumnFromConstant(
        joinColumnAnn,
        fallbackName: _toSnake('${field.displayName}_id'),
        fallbackReference: 'id',
        fallbackNullable: fieldIsNullable,
        fallbackUnique: match.kind == RelationKind.oneToOne,
      );
    } else if (needsJoinColumn) {
      joinColumn = GenJoinColumn(
        name: _toSnake('${field.displayName}_id'),
        referencedColumnName: 'id',
        nullable: fieldIsNullable,
        unique: match.kind == RelationKind.oneToOne,
      );
    }

    final needsJoinTable = isOwning && (match.kind == RelationKind.manyToMany);
    final joinTableAnn = _firstAnnotation(field, JoinTable);
    GenJoinTable? joinTable;
    if (joinTableAnn != null) {
      if (match.kind != RelationKind.manyToMany) {
        throw InvalidGenerationSourceError(
          '@JoinTable can only be used on many-to-many relations.',
          element: field,
        );
      }
      final ownerColFallback =
          '${_toSnake(entityName)}_${_toSnake(field.displayName)}_id';
      final inverseFallback =
          '${simpleTypeName(targetTypeCode).toLowerCase()}_id';
      joinTable = _joinTableFromConstant(
        joinTableAnn,
        defaultName: '${tableName}_${_toSnake(field.displayName)}_join',
        ownerFallback: ownerColFallback,
        inverseFallback: inverseFallback,
      );
    } else if (needsJoinTable) {
      throw InvalidGenerationSourceError(
        '@${match.annotationName} on $entityName.${field.displayName} requires a @JoinTable annotation on the owning side.',
        element: field,
      );
    }

    final constructorLiteral = _relationConstructorLiteral(field, match.kind);
    final pkInfo = _resolvePrimaryKeyInfo(onType);
    String? joinColumnPropertyName;
    String? joinColumnBaseDartType;
    bool joinColumnNullable = true;
    String? targetPrimaryFieldName;
    if (joinColumn != null) {
      joinColumnPropertyName = _identifierFromColumnName(joinColumn.name);
      final baseType = pkInfo.dartTypeCode;
      joinColumnNullable = joinColumn.nullable;
      joinColumnBaseDartType = baseType;
      targetPrimaryFieldName = pkInfo.propertyName;
    }

    final isCollection =
        match.kind == RelationKind.oneToMany ||
        match.kind == RelationKind.manyToMany;

    return GenRelation(
      fieldName: field.displayName,
      type: match.kind,
      targetTypeCode: targetTypeCode,
      isOwningSide: isOwning,
      mappedBy: mappedBy,
      fetchLiteral: fetchLiteral,
      cascadeLiteral: cascadeLiteral,
      cascadePersist: cascadePersist,
      cascadeMerge: cascadeMerge,
      cascadeRemove: cascadeRemove,
      joinColumn: joinColumn,
      joinTable: joinTable,
      constructorLiteral: constructorLiteral,
      joinColumnPropertyName: joinColumnPropertyName,
      joinColumnBaseDartType: joinColumnBaseDartType,
      joinColumnNullable: joinColumnNullable,
      targetPrimaryFieldName: targetPrimaryFieldName,
      isCollection: isCollection,
    );
  }

  _RelationMatch? _findRelationAnnotation(FieldElement field) {
    final mappings = <Type, RelationKind>{
      OneToOne: RelationKind.oneToOne,
      ManyToOne: RelationKind.manyToOne,
      OneToMany: RelationKind.oneToMany,
      ManyToMany: RelationKind.manyToMany,
    };
    for (final entry in mappings.entries) {
      final ann = _firstAnnotation(field, entry.key);
      if (ann != null) {
        return _RelationMatch(
          entry.value,
          ConstantReader(ann),
          entry.key.toString(),
        );
      }
    }
    return null;
  }

  String _enumLiteral(
    DartObject? obj,
    List<String> names,
    String enumType, {
    required int defaultIndex,
  }) {
    final index = obj?.getField('index')?.toIntValue() ?? defaultIndex;
    if (index < 0 || index >= names.length) {
      throw InvalidGenerationSourceError('Unsupported value for $enumType');
    }
    return '$enumType.${names[index]}';
  }

  String _enumListLiteral(
    List<DartObject> values,
    List<String> names,
    String enumType,
  ) {
    if (values.isEmpty) return 'const []';
    final items = <String>[];
    for (final value in values) {
      final index = value.getField('index')?.toIntValue();
      if (index == null || index < 0 || index >= names.length) {
        throw InvalidGenerationSourceError('Unsupported value for $enumType');
      }
      items.add('$enumType.${names[index]}');
    }
    return 'const [${items.join(', ')}]';
  }

  bool _hasCascadePersist(List<DartObject> values) {
    if (values.isEmpty) return false;
    for (final value in values) {
      final index = value.getField('index')?.toIntValue();
      if (index == null || index < 0 || index >= _relationCascadeNames.length) {
        continue;
      }
      final name = _relationCascadeNames[index];
      if (name == 'persist' || name == 'all') return true;
    }
    return false;
  }

  bool _hasCascadeMerge(List<DartObject> values) {
    if (values.isEmpty) return false;
    for (final value in values) {
      final index = value.getField('index')?.toIntValue();
      if (index == null || index < 0 || index >= _relationCascadeNames.length) {
        continue;
      }
      final name = _relationCascadeNames[index];
      if (name == 'merge' || name == 'all') return true;
    }
    return false;
  }

  bool _hasCascadeRemove(List<DartObject> values) {
    if (values.isEmpty) return false;
    for (final value in values) {
      final index = value.getField('index')?.toIntValue();
      if (index == null || index < 0 || index >= _relationCascadeNames.length) {
        continue;
      }
      final name = _relationCascadeNames[index];
      if (name == 'remove' || name == 'all') return true;
    }
    return false;
  }

  GenJoinColumn _joinColumnFromConstant(
    DartObject obj, {
    required String fallbackName,
    required String fallbackReference,
    bool fallbackNullable = true,
    bool fallbackUnique = false,
  }) {
    final reader = ConstantReader(obj);
    final name = reader.peek('name')?.stringValue ?? fallbackName;
    final reference =
        reader.peek('referencedColumnName')?.stringValue ?? fallbackReference;
    final nullable = reader.peek('nullable')?.boolValue ?? fallbackNullable;
    final unique = reader.peek('unique')?.boolValue ?? fallbackUnique;
    return GenJoinColumn(
      name: name,
      referencedColumnName: reference,
      nullable: nullable,
      unique: unique,
    );
  }

  GenJoinTable _joinTableFromConstant(
    DartObject obj, {
    required String defaultName,
    required String ownerFallback,
    required String inverseFallback,
  }) {
    final reader = ConstantReader(obj);
    final name = reader.peek('name')?.stringValue ?? defaultName;
    final ownerListReader = reader.peek('joinColumns');
    final inverseListReader = reader.peek('inverseJoinColumns');
    final ownerObjs = ownerListReader == null
        ? const <DartObject>[]
        : ownerListReader.listValue;
    final inverseObjs = inverseListReader == null
        ? const <DartObject>[]
        : inverseListReader.listValue;
    final ownerCols = ownerObjs.isEmpty
        ? [
            GenJoinColumn(
              name: ownerFallback,
              referencedColumnName: 'id',
              nullable: false,
              unique: false,
            ),
          ]
        : ownerObjs
              .map(
                (o) => _joinColumnFromConstant(
                  o,
                  fallbackName: ownerFallback,
                  fallbackReference: 'id',
                  fallbackNullable: false,
                ),
              )
              .toList();
    final inverseCols = inverseObjs.isEmpty
        ? [
            GenJoinColumn(
              name: inverseFallback,
              referencedColumnName: 'id',
              nullable: false,
              unique: false,
            ),
          ]
        : inverseObjs
              .map(
                (o) => _joinColumnFromConstant(
                  o,
                  fallbackName: inverseFallback,
                  fallbackReference: 'id',
                  fallbackNullable: false,
                ),
              )
              .toList();
    return GenJoinTable(
      name: name,
      joinColumns: ownerCols,
      inverseJoinColumns: inverseCols,
    );
  }

  String? _relationConstructorLiteral(FieldElement field, RelationKind kind) {
    final type = field.type;
    final isCollection = _isCollectionType(type);
    if (isCollection) {
      final elementType = _collectionElementType(type);
      if (elementType == null) {
        throw InvalidGenerationSourceError(
          'Relation field ${field.displayName} on ${field.enclosingElement.displayName} must be a List or Set with a concrete type.',
          element: field,
        );
      }
      return 'const <$elementType>[]';
    }
    final isNullable = type.nullabilitySuffix != NullabilitySuffix.none;
    if (!isNullable) {
      throw InvalidGenerationSourceError(
        '@${kind.name} relation field ${field.displayName} on ${field.enclosingElement.displayName} must be nullable because related data is not auto-hydrated.',
        element: field,
      );
    }
    return 'null';
  }

  bool _isCollectionType(DartType type) {
    if (type is! InterfaceType) return false;
    final name = type.element.name;
    return name == 'List' || name == 'Set' || name == 'Iterable';
  }

  String? _collectionElementType(DartType type) {
    if (type is! InterfaceType || type.typeArguments.isEmpty) return null;
    final elementType = type.typeArguments.first.getDisplayString();
    return type.typeArguments.first.nullabilitySuffix ==
            NullabilitySuffix.question
        ? elementType.substring(0, elementType.length - 1)
        : elementType;
  }

  PrimaryKeyInfo _resolvePrimaryKeyInfo(InterfaceType type) {
    final element = type.element;
    for (final field in element.fields.where((f) => !f.isStatic)) {
      if (_firstAnnotation(field, PrimaryKey) != null) {
        final columnAnnObj = _firstAnnotation(field, Column);
        final columnName = columnAnnObj == null
            ? _toSnake(field.displayName)
            : (ConstantReader(columnAnnObj).peek('name')?.stringValue ??
                  _toSnake(field.displayName));
        var dartType = field.type.getDisplayString();
        if (field.type.nullabilitySuffix != NullabilitySuffix.none) {
          dartType = dartType.substring(0, dartType.length - 1);
        }
        return PrimaryKeyInfo(
          propertyName: field.displayName,
          columnName: columnName,
          dartTypeCode: dartType,
        );
      }
    }
    throw InvalidGenerationSourceError(
      'Target ${element.displayName} must declare a primary key for relation mapping.',
      element: element,
    );
  }

  String _identifierFromColumnName(String column) {
    final parts = column.split('_');
    final buffer = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part.isEmpty) continue;
      if (i == 0) {
        buffer.write(part);
      } else {
        buffer.write(part.substring(0, 1).toUpperCase());
        buffer.write(part.substring(1));
      }
    }
    final result = buffer.toString();
    if (result.isEmpty) {
      return column.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    }
    return result;
  }

  ColumnType _resolveColumnType(
    ConstantReader? ann,
    DartType type, {
    bool isEnum = false,
    FieldElement? field,
  }) {
    ColumnType? explicitType;
    if (ann != null) {
      final explicit = ann.peek('type');
      if (explicit != null && !explicit.isNull) {
        final index = explicit.objectValue.getField('index')?.toIntValue();
        if (index != null && index >= 0 && index < ColumnType.values.length) {
          explicitType = ColumnType.values[index];
        }
      }
    }

    if (explicitType != null) {
      if (!isEnum) return explicitType;
      if (explicitType == ColumnType.text ||
          explicitType == ColumnType.integer) {
        return explicitType;
      }
      final className =
          field?.enclosingElement.displayName ?? '<unknown class>';
      final fieldName = field?.displayName ?? '<unknown field>';
      throw InvalidGenerationSourceError(
        'Enum column $className.$fieldName must use ColumnType.text or ColumnType.integer.',
        element: field,
      );
    }

    if (isEnum) return ColumnType.integer;

    return _inferColumnType(type);
  }

  ColumnType _inferColumnType(DartType type) {
    var name = type.getDisplayString();
    if (type.nullabilitySuffix == NullabilitySuffix.question) {
      name = name.substring(0, name.length - 1);
    }
    if (type is InterfaceType && (type.isDartCoreList || type.isDartCoreMap)) {
      return ColumnType.json;
    }
    switch (name) {
      case 'int':
        return ColumnType.integer;
      case 'String':
        return ColumnType.text;
      case 'bool':
        return ColumnType.boolean;
      case 'double':
        return ColumnType.doublePrecision;
      case 'DateTime':
        return ColumnType.dateTime;
      default:
        return ColumnType.text;
    }
  }

  String _stripNullability(String typeName) {
    return typeName.endsWith('?')
        ? typeName.substring(0, typeName.length - 1)
        : typeName;
  }

  String? _dartObjToLiteral(DartObject? obj) {
    if (obj == null) return null;
    final type = obj.type?.getDisplayString();
    final i = obj.toIntValue();
    if (i != null) return i.toString();
    final d = obj.toDoubleValue();
    if (d != null) return d.toString();
    if (type == 'bool') return (obj.toBoolValue() ?? false) ? 'true' : 'false';
    final s = obj.toStringValue();
    if (s != null) return "'${s.replaceAll("'", "\\'")}'";
    return null;
  }

  String _toSnake(String input) {
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final c = input[i];
      final isUpper = c.toUpperCase() == c && c.toLowerCase() != c;
      if (isUpper && i != 0) buffer.write('_');
      buffer.write(c.toLowerCase());
    }
    return buffer.toString();
  }

  static const _fetchStrategyNames = ['eager', 'lazy'];
  static const _relationCascadeNames = [
    'persist',
    'merge',
    'remove',
    'detach',
    'refresh',
    'all',
  ];
}

class _RelationMatch {
  const _RelationMatch(this.kind, this.reader, this.annotationName);

  final RelationKind kind;
  final ConstantReader reader;
  final String annotationName;
}

class _TimestampFields {
  _TimestampFields({required this.createdAt, required this.updatedAt});

  final List<GenTimestampField> createdAt;
  final List<GenTimestampField> updatedAt;
}
