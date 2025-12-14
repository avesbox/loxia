import 'dart:async';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import '../../loxia.dart' show Column, ColumnType, EntityMeta, JoinColumn, JoinTable, ManyToMany, ManyToOne, OneToMany, OneToOne, PrimaryKey;

class LoxiaEntityGenerator extends GeneratorForAnnotation<EntityMeta> {
  @override
  Future<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    if (element is! ClassElement) return '';
    final clazz = element;
    final className = clazz.displayName;
    if (clazz.isAbstract) return '';
    final table = annotation.peek('table')?.stringValue ?? _toSnake(className);
    final schema = annotation.peek('schema')?.stringValue;

    final columns = <_GenColumn>[];

    for (final field in clazz.fields.where((f) => !f.isStatic)) {
      final colAnnObj = _firstAnnotation(field, Column) ?? _firstAnnotation(field, PrimaryKey);
      if (colAnnObj == null) continue;
      final colAnn = ConstantReader(colAnnObj);

      final isPk = _firstAnnotation(field, PrimaryKey) != null;
      final colName = colAnn.peek('name')?.stringValue ?? _toSnake(field.displayName);
      final dartType = field.type;
      final nullable = dartType.nullabilitySuffix != NullabilitySuffix.none;
      final unique = colAnn.peek('unique')?.boolValue ?? false;
      final defaultValue = colAnn.peek('defaultValue')?.objectValue;

      final autoInc = isPk ? (colAnn.peek('autoIncrement')?.boolValue ?? false) : false;
      final uuid = isPk ? (colAnn.peek('uuid')?.boolValue ?? false) : false;

      final type = _resolveColumnType(colAnn, dartType);
      final dartTypeCode = dartType.getDisplayString();

      columns.add(_GenColumn(
        name: colName,
        prop: field.displayName,
        type: type,
        dartTypeCode: dartTypeCode,
        nullable: nullable,
        unique: unique,
        isPk: isPk,
        autoIncrement: autoInc,
        uuid: uuid,
        defaultLiteral: _dartObjToLiteral(defaultValue),
      ));
    }

    final relations = <_GenRelation>[];
    for (final field in clazz.fields.where((f) => !f.isStatic)) {
      final relation = _buildRelation(field, className, table);
      if (relation != null) {
        relations.add(relation);
      }
    }
    final owningJoinColumns = relations.where((r) => r.joinColumn != null && r.isOwningSide).toList();
    // Inverse relations (OneToMany, ManyToMany inverse side) - these reference mappedBy
    final inverseRelations = relations.where((r) => !r.isOwningSide && r.mappedBy != null).toList();
    // All relations that can be selected (both owning and inverse sides)
    final partialEntityName = '${className}Partial';

    final buf = StringBuffer();
    buf.writeln('final EntityDescriptor<$className, $partialEntityName> \$${className}EntityDescriptor = EntityDescriptor<$className, $partialEntityName>(');
    buf.writeln("  entityType: $className,");
    buf.writeln("  tableName: '$table',");
    if (schema != null) {
      buf.writeln("  schema: '$schema',");
    }
    buf.writeln('  columns: [');
    for (final c in columns) {
      buf.writeln('    ColumnDescriptor(');
      buf.writeln("      name: '${c.name}',");
      buf.writeln("      propertyName: '${c.prop}',");
      buf.writeln('      type: ColumnType.${c.type.name},');
      buf.writeln('      nullable: ${c.nullable},');
      buf.writeln('      unique: ${c.unique},');
      buf.writeln('      isPrimaryKey: ${c.isPk},');
      buf.writeln('      autoIncrement: ${c.autoIncrement},');
      buf.writeln('      uuid: ${c.uuid},');
      if (c.defaultLiteral != null) {
        buf.writeln('      defaultValue: ${c.defaultLiteral},');
      }
      buf.writeln('    ),');
    }
    buf.writeln('  ],');
    if (relations.isEmpty) {
      buf.writeln('  relations: const [],');
    } else {
      buf.writeln('  relations: const [');
      for (final r in relations) {
        buf.writeln('    RelationDescriptor(');
        buf.writeln("      fieldName: '${r.fieldName}',");
        buf.writeln('      type: RelationType.${r.type.name},');
        buf.writeln('      target: ${r.targetTypeCode},');
        buf.writeln('      isOwningSide: ${r.isOwningSide},');
        if (r.mappedBy != null) {
          buf.writeln("      mappedBy: '${r.mappedBy}',");
        }
        buf.writeln('      fetch: ${r.fetchLiteral},');
        buf.writeln('      cascade: ${r.cascadeLiteral},');
        if (r.joinColumn != null) {
          buf.writeln('      joinColumn: ${r.joinColumnLiteral()},');
        }
        if (r.joinTable != null) {
          buf.writeln('      joinTable: ${r.joinTableLiteral()},');
        }
        buf.writeln('    ),');
      }
      buf.writeln('  ],');
    }
    // fromRow mapping
    buf.writeln('  fromRow: (row) => $className(');
    for (final c in columns) {
      buf.writeln("    ${c.prop}: row['${c.name}'] as ${c.dartTypeCode},");
    }
    for (final r in relations) {
      if (r.constructorLiteral != null) {
        buf.writeln("    ${r.fieldName}: ${r.constructorLiteral},");
      }
    }
    buf.writeln('  ),');
    // toRow mapping
    buf.writeln('  toRow: (e) => {');
    for (final c in columns) {
      buf.writeln("    '${c.name}': e.${c.prop},");
    }
    for (final relation in owningJoinColumns) {
      final accessor = relation.targetPrimaryFieldName == null
          ? 'null'
          : "e.${relation.fieldName}?.${relation.targetPrimaryFieldName}";
      buf.writeln("    '${relation.joinColumn!.name}': $accessor,");
    }
    buf.writeln('  },');
    buf.write('  fieldsContext: const ${className}FieldsContext(),');
    buf.write('  repositoryFactory: (engine) => EntityRepository<$className, $partialEntityName>(\$${className}EntityDescriptor, engine, \$${className}EntityDescriptor.fieldsContext),');
    buf.writeln(');');
    buf.writeln();
    final builderFieldsClass = '${className}FieldsContext';
    buf.writeln('class $builderFieldsClass extends QueryFieldsContext<$className> {');
    buf.writeln('  const $builderFieldsClass([super.runtime, super.alias]);');
    buf.writeln('  @override');
    buf.writeln('  $builderFieldsClass bind(QueryRuntimeContext runtime, String alias) => $builderFieldsClass(runtime, alias);');
    for (final c in columns) {
      buf.writeln("  QueryField<${c.dartTypeCode}> get ${c.prop} => field<${c.dartTypeCode}>('${c.name}');");
    }
    for (final relation in owningJoinColumns) {
      final joinType = relation.joinColumnBaseDartType!;
      final typeWithNull = relation.joinColumnNullable ? '$joinType?' : joinType;
      buf.writeln("  QueryField<$typeWithNull> get ${relation.joinColumnPropertyName} => field<$typeWithNull>('${relation.joinColumn!.name}');");
    }
    for (final relation in owningJoinColumns) {
      final targetSimple = _simpleTypeName(relation.targetTypeCode);
      final targetContext = '${targetSimple}FieldsContext';
      final descriptorRef = '\$${targetSimple}EntityDescriptor';
      buf.writeln('  $targetContext get ${relation.fieldName} {');
      buf.writeln('    final alias = ensureRelationJoin(');
      buf.writeln("      relationName: '${relation.fieldName}',");
      buf.writeln('      targetTableName: $descriptorRef.qualifiedTableName,');
      buf.writeln("      localColumn: '${relation.joinColumn!.name}',");
      buf.writeln("      foreignColumn: '${relation.joinColumn!.referencedColumnName}',");
      buf.writeln('      joinType: JoinType.left,');
      buf.writeln('    );');
      buf.writeln('    return $targetContext(runtimeOrThrow, alias);');
      buf.writeln('  }');
    }
    // Generate getters for inverse relations (OneToMany, ManyToMany inverse side)
    for (final relation in inverseRelations) {
      final targetSimple = _simpleTypeName(relation.targetTypeCode);
      final targetContext = '${targetSimple}FieldsContext';
      final descriptorRef = '\$${targetSimple}EntityDescriptor';
      final mappedBy = relation.mappedBy!;
      buf.writeln('  $targetContext get ${relation.fieldName} {');
      buf.writeln('    // Find the owning relation on the target entity to get join column info');
      buf.writeln("    final targetRelation = $descriptorRef.relations.firstWhere((r) => r.fieldName == '$mappedBy');");
      buf.writeln('    final joinColumn = targetRelation.joinColumn!;');
      buf.writeln('    final alias = ensureRelationJoin(');
      buf.writeln("      relationName: '${relation.fieldName}',");
      buf.writeln('      targetTableName: $descriptorRef.qualifiedTableName,');
      buf.writeln('      localColumn: joinColumn.referencedColumnName,');
      buf.writeln('      foreignColumn: joinColumn.name,');
      buf.writeln('      joinType: JoinType.left,');
      buf.writeln('    );');
      buf.writeln('    return $targetContext(runtimeOrThrow, alias);');
      buf.writeln('  }');
    }
    buf.writeln('}');
    final queryClass = '${className}Query';
    buf.writeln('class $queryClass extends QueryBuilder<$className> {');
    buf.writeln('  const $queryClass(this._builder);');
    buf.writeln('  final WhereExpression Function($builderFieldsClass q) _builder;');
    buf.writeln('  @override');
    buf.writeln('  WhereExpression build(QueryFieldsContext<$className> context) {');
    buf.writeln('    if (context is! $builderFieldsClass) {');
    buf.writeln("      throw ArgumentError('Expected $builderFieldsClass for $queryClass');");
    buf.writeln('    }');
    buf.writeln('    return _builder(context);');
    buf.writeln('  }');
    buf.writeln('}');

    final selectClass = '${className}Select';
    final relationsClass = '${className}Relations';
    buf.writeln('class $selectClass extends SelectOptions<$className, $partialEntityName> {');
    buf.writeln('  const $selectClass({');
    for (final c in columns) {
      buf.writeln('    this.${c.prop} = false,');
    }
    for (final relation in owningJoinColumns) {
      final joinProp = relation.joinColumnPropertyName;
      if (joinProp != null) {
        buf.writeln('    this.$joinProp = false,');
      }
    }
    buf.writeln('    this.relations,');
    buf.writeln('  });');
    for (final c in columns) {
      buf.writeln('  final bool ${c.prop};');
    }
    for (final relation in owningJoinColumns) {
      final joinProp = relation.joinColumnPropertyName;
      if (joinProp != null) {
        buf.writeln('  final bool $joinProp;');
      }
    }
    buf.writeln('  final $relationsClass? relations;');
    buf.writeln('  @override');
    final hasParts = <String>[];
    if (columns.isNotEmpty) {
      hasParts.addAll(columns.map((c) => c.prop));
    }
    for (final relation in owningJoinColumns) {
      final joinProp = relation.joinColumnPropertyName;
      if (joinProp != null) {
        hasParts.add(joinProp);
      }
    }
    hasParts.add('(relations?.hasSelections ?? false)');
    buf.writeln('  bool get hasSelections => ${hasParts.join(' || ')};');
    buf.writeln('  @override');
    buf.writeln('  void collect(QueryFieldsContext<$className> context, List<SelectField> out, {String? path}) {');
    buf.writeln('    if (context is! ${className}FieldsContext) {');
    buf.writeln("      throw ArgumentError('Expected ${className}FieldsContext for $selectClass');");
    buf.writeln('    }');
    buf.writeln('    final ${className}FieldsContext scoped = context;');
    buf.writeln('    String? aliasFor(String column) {');
    buf.writeln('      final current = path;');
    buf.writeln('      if (current == null || current.isEmpty) return null;');
    buf.writeln("      return '\${current}_\$column';");
    buf.writeln('    }');
    buf.writeln('    final tableAlias = scoped.currentAlias;');
    for (final c in columns) {
      buf.writeln('    if (${c.prop}) {');
      buf.writeln('      out.add(');
      buf.writeln('        SelectField(');
      buf.writeln("          '${c.name}',");
      buf.writeln('          tableAlias: tableAlias,');
      buf.writeln("          alias: aliasFor('${c.name}'),");
      buf.writeln('        ),');
      buf.writeln('      );');
      buf.writeln('    }');
    }
    for (final relation in owningJoinColumns) {
      final joinProp = relation.joinColumnPropertyName;
      final joinColumn = relation.joinColumn?.name;
      if (joinProp != null && joinColumn != null) {
        buf.writeln('    if ($joinProp) {');
        buf.writeln('      out.add(');
        buf.writeln('        SelectField(');
        buf.writeln("          '$joinColumn',");
        buf.writeln('          tableAlias: tableAlias,');
        buf.writeln("          alias: aliasFor('$joinColumn'),");
        buf.writeln('        ),');
        buf.writeln('      );');
        buf.writeln('    }');
      }
    }
    buf.writeln('    final rels = relations;');
    buf.writeln('    if (rels != null && rels.hasSelections) {');
    buf.writeln('      rels.collect(scoped, out, path: path);');
    buf.writeln('    }');
    buf.writeln('  }');
    buf.writeln();
    // Generate hydrate method
    buf.writeln('  @override');
    buf.writeln('  $partialEntityName hydrate(Map<String, dynamic> row, {String? path}) {');
    // First, hydrate any nested relation partials (owning side)
    for (final relation in owningJoinColumns) {
      final targetSimple = _simpleTypeName(relation.targetTypeCode);
      buf.writeln('    ${targetSimple}Partial? ${relation.fieldName}Partial;');
      buf.writeln('    final ${relation.fieldName}Select = relations?.${relation.fieldName};');
      buf.writeln('    if (${relation.fieldName}Select != null && ${relation.fieldName}Select.hasSelections) {');
      buf.writeln("      ${relation.fieldName}Partial = ${relation.fieldName}Select.hydrate(row, path: extendPath(path, '${relation.fieldName}'));");
      buf.writeln('    }');
    }
    // For inverse relations (OneToMany), we can only hydrate a single row at a time.
    // Collection aggregation must happen at the repository level.
    // For single-value inverse relations, we hydrate normally.
    for (final relation in inverseRelations) {
      final targetSimple = _simpleTypeName(relation.targetTypeCode);
      if (relation.isCollection) {
        // Collection relations cannot be fully hydrated per-row - need aggregation
        // For now, set to null - the repository will need to aggregate
        buf.writeln('    // Collection relation ${relation.fieldName} requires row aggregation');
      } else {
        // Single-value inverse relation
        buf.writeln('    ${targetSimple}Partial? ${relation.fieldName}Partial;');
        buf.writeln('    final ${relation.fieldName}Select = relations?.${relation.fieldName};');
        buf.writeln('    if (${relation.fieldName}Select != null && ${relation.fieldName}Select.hasSelections) {');
        buf.writeln("      ${relation.fieldName}Partial = ${relation.fieldName}Select.hydrate(row, path: extendPath(path, '${relation.fieldName}'));");
        buf.writeln('    }');
      }
    }
    buf.writeln('    return $partialEntityName(');
    for (final c in columns) {
      final castType = c.dartTypeCode + (c.nullable ? '?' : '');
      buf.writeln("      ${c.prop}: ${c.prop} ? readValue(row, '${c.name}', path: path) as $castType? : null,");
    }
    for (final relation in owningJoinColumns) {
      final joinProp = relation.joinColumnPropertyName;
      if (joinProp != null) {
        final joinType = relation.joinColumnBaseDartType!;
        buf.writeln("      $joinProp: $joinProp ? readValue(row, '${relation.joinColumn!.name}', path: path) as $joinType? : null,");
      }
      // Add the relation partial
      buf.writeln("      ${relation.fieldName}: ${relation.fieldName}Partial,");
    }
    // Add inverse relation partials
    for (final relation in inverseRelations) {
      if (relation.isCollection) {
        // Collections cannot be hydrated per-row
        buf.writeln("      ${relation.fieldName}: null, // Collection requires aggregation");
      } else {
        buf.writeln("      ${relation.fieldName}: ${relation.fieldName}Partial,");
      }
    }
    buf.writeln('    );');
    buf.writeln('  }');
    
    // Generate hasCollectionRelations getter
    final hasCollections = inverseRelations.any((r) => r.isCollection);
    buf.writeln('  @override');
    buf.writeln('  bool get hasCollectionRelations => $hasCollections;');
    
    // Generate primaryKeyColumn getter (for aggregation)
    final pkColumn = columns.firstWhere((c) => c.isPk, orElse: () => columns.first);
    buf.writeln('  @override');
    buf.writeln("  String? get primaryKeyColumn => '${pkColumn.name}';");
    
    // Generate aggregateRows method for collection relations
    if (hasCollections) {
      buf.writeln('  @override');
      buf.writeln('  List<$partialEntityName> aggregateRows(List<Map<String, dynamic>> rows, {String? path}) {');
      buf.writeln('    if (rows.isEmpty) return [];');
      buf.writeln('    final grouped = <Object?, List<Map<String, dynamic>>>{};');
      buf.writeln('    for (final row in rows) {');
      buf.writeln("      final key = readValue(row, '${pkColumn.name}', path: path);");
      buf.writeln('      (grouped[key] ??= []).add(row);');
      buf.writeln('    }');
      buf.writeln('    return grouped.entries.map((entry) {');
      buf.writeln('      final groupRows = entry.value;');
      buf.writeln('      final firstRow = groupRows.first;');
      // Hydrate the base partial from the first row
      buf.writeln('      final base = hydrate(firstRow, path: path);');
      // Collect collection relation items from all rows
      for (final relation in inverseRelations.where((r) => r.isCollection)) {
        final targetSimple = _simpleTypeName(relation.targetTypeCode);
        final relationName = relation.fieldName;
        buf.writeln('      // Aggregate $relationName collection');
        buf.writeln('      final ${relationName}Select = relations?.$relationName;');
        buf.writeln('      List<${targetSimple}Partial>? ${relationName}List;');
        buf.writeln('      if (${relationName}Select != null && ${relationName}Select.hasSelections) {');
        buf.writeln("        final relationPath = extendPath(path, '$relationName');");
        buf.writeln('        ${relationName}List = <${targetSimple}Partial>[];');
        buf.writeln('        final seenKeys = <Object?>{};');
        buf.writeln('        for (final row in groupRows) {');
        // Check if this row has a non-null relation item
        buf.writeln("          final itemKey = ${relationName}Select.readValue(row, ${relationName}Select.primaryKeyColumn ?? 'id', path: relationPath);");
        buf.writeln('          if (itemKey != null && seenKeys.add(itemKey)) {');
        buf.writeln('            ${relationName}List.add(${relationName}Select.hydrate(row, path: relationPath));');
        buf.writeln('          }');
        buf.writeln('        }');
        buf.writeln('      }');
      }
      // Return a new partial with the aggregated collections
      buf.writeln('      return $partialEntityName(');
      for (final c in columns) {
        buf.writeln('        ${c.prop}: base.${c.prop},');
      }
      for (final relation in owningJoinColumns) {
        final joinProp = relation.joinColumnPropertyName;
        if (joinProp != null) {
          buf.writeln('        $joinProp: base.$joinProp,');
        }
        buf.writeln('        ${relation.fieldName}: base.${relation.fieldName},');
      }
      for (final relation in inverseRelations) {
        if (relation.isCollection) {
          buf.writeln('        ${relation.fieldName}: ${relation.fieldName}List,');
        } else {
          buf.writeln('        ${relation.fieldName}: base.${relation.fieldName},');
        }
      }
      buf.writeln('      );');
      buf.writeln('    }).toList();');
      buf.writeln('  }');
    }
    
    buf.writeln('}');

    buf.writeln('class $relationsClass {');
    final allSelectableRelations = [...owningJoinColumns, ...inverseRelations];
    if (allSelectableRelations.isEmpty) {
      buf.writeln('  const $relationsClass();');
      buf.writeln('  bool get hasSelections => false;');
      buf.writeln('  void collect(${className}FieldsContext context, List<SelectField> out, {String? path}) {}');
    } else {
      buf.writeln('  const $relationsClass({');
      for (final relation in allSelectableRelations) {
        buf.writeln('    this.${relation.fieldName},');
      }
      buf.writeln('  });');
      for (final relation in allSelectableRelations) {
        final targetSimple = _simpleTypeName(relation.targetTypeCode);
        buf.writeln('  final ${targetSimple}Select? ${relation.fieldName};');
      }
      final relationHasParts = allSelectableRelations
          .map((r) => '(${r.fieldName}?.hasSelections ?? false)')
          .toList();
      buf.writeln('  bool get hasSelections => ${relationHasParts.join(' || ')};');
      buf.writeln('  void collect(${className}FieldsContext context, List<SelectField> out, {String? path}) {');
      for (final relation in allSelectableRelations) {
        final relationName = relation.fieldName;
        buf.writeln('    final ${relationName}Select = $relationName;');
        buf.writeln('    if (${relationName}Select != null && ${relationName}Select.hasSelections) {');
        buf.writeln(
            "      final relationPath = path == null || path.isEmpty ? '$relationName' : '\${path}_$relationName';");
        buf.writeln('      final relationContext = context.$relationName;');
        buf.writeln('      ${relationName}Select.collect(relationContext, out, path: relationPath);');
        buf.writeln('    }');
      }
      buf.writeln('  }');
    }
    buf.writeln('}');
    // Generate partial entity class - all fields nullable
    buf.writeln('class $partialEntityName extends PartialEntity<$className> {');
    buf.writeln('  const $partialEntityName({');
    for (final c in columns) {
      buf.writeln('    this.${c.prop},');
    }
    for (final relation in owningJoinColumns) {
      final joinProp = relation.joinColumnPropertyName;
      if (joinProp != null) {
        buf.writeln('    this.$joinProp,');
      }
      // Add the relation partial field
      buf.writeln('    this.${relation.fieldName},');
    }
    // Add inverse relation partial fields
    for (final relation in inverseRelations) {
      buf.writeln('    this.${relation.fieldName},');
    }
    buf.writeln('  });');
    buf.writeln();
    for (final c in columns) {
      buf.writeln('  final ${c.dartTypeCode}? ${c.prop};');
    }
    for (final relation in owningJoinColumns) {
      final joinProp = relation.joinColumnPropertyName;
      if (joinProp != null) {
        final joinType = relation.joinColumnBaseDartType!;
        buf.writeln('  final $joinType? $joinProp;');
      }
      // Add the relation partial field type
      final targetSimple = _simpleTypeName(relation.targetTypeCode);
      buf.writeln('  final ${targetSimple}Partial? ${relation.fieldName};');
    }
    // Add inverse relation partial field types (collections)
    for (final relation in inverseRelations) {
      final targetSimple = _simpleTypeName(relation.targetTypeCode);
      if (relation.isCollection) {
        buf.writeln('  final List<${targetSimple}Partial>? ${relation.fieldName};');
      } else {
        buf.writeln('  final ${targetSimple}Partial? ${relation.fieldName};');
      }
    }
    buf.writeln();
    buf.writeln('  @override');
    buf.writeln('  $className toEntity() {');
    // Add validation for required fields
    buf.writeln('    final missing = <String>[];');
    for (final c in columns.where((c) => !c.nullable)) {
      buf.writeln("    if (${c.prop} == null) missing.add('${c.prop}');");
    }
    buf.writeln('    if (missing.isNotEmpty) {');
    buf.writeln("      throw StateError('Cannot convert $partialEntityName to $className: missing required fields: \${missing.join(', ')}');");
    buf.writeln('    }');
    buf.writeln('    return $className(');
    for (final c in columns) {
      final prop = c.prop;
      final assign = c.nullable ? prop : '$prop!';
      buf.writeln('      $prop: $assign,');
    }
    // Handle owning relations - use the partial's toEntity() if available
    for (final r in owningJoinColumns) {
      buf.writeln("      ${r.fieldName}: ${r.fieldName}?.toEntity(),");
    }
    // Handle inverse relations - convert partials to entities or use constructor literal
    for (final r in inverseRelations) {
      if (r.isCollection) {
        buf.writeln("      ${r.fieldName}: ${r.fieldName}?.map((p) => p.toEntity()).toList() ?? ${r.constructorLiteral ?? 'const []'},");
      } else {
        buf.writeln("      ${r.fieldName}: ${r.fieldName}?.toEntity(),");
      }
    }
    buf.writeln('    );');
    buf.writeln('  }');
    buf.writeln('}');
    buf.writeln();
    final insertDtoName = '${className}InsertDto';
    buf.writeln('class $insertDtoName implements InsertDto<$className> {');
    buf.writeln('  const $insertDtoName({');
    for (final c in columns.where((c) => !c.autoIncrement && !c.isPk)) {
      buf.writeln('   ${c.nullable ? '' : 'required '}this.${c.prop},');
    }
    for (final relation in owningJoinColumns) {
      final requiredClause = relation.joinColumnNullable ? '' : 'required ';
      buf.writeln('   ${requiredClause}this.${relation.joinColumnPropertyName},');
    }
    buf.writeln('  });');
    for (final c in columns.where((c) => !c.autoIncrement && !c.isPk)) {
      buf.writeln('  final ${c.dartTypeCode} ${c.prop};');
    }
    for (final relation in owningJoinColumns) {
      final joinType = relation.joinColumnBaseDartType!;
      final typeWithNull = relation.joinColumnNullable ? '$joinType?' : joinType;
      buf.writeln('  final $typeWithNull ${relation.joinColumnPropertyName};');
    }
    buf.writeln();
    buf.writeln('  @override');
    buf.writeln('  Map<String, dynamic> toMap() {');
    buf.writeln('    return {');
    for (final c in columns.where((c) => !c.autoIncrement && !c.isPk)) {
      buf.writeln("      '${c.name}': ${c.prop},");
    }
    for (final relation in owningJoinColumns) {
      final prop = relation.joinColumnPropertyName;
      final nullable = relation.joinColumnNullable;
      final entry = nullable
          ? "      if($prop != null) '${relation.joinColumn!.name}': $prop,"
          : "      '${relation.joinColumn!.name}': $prop,";
      buf.writeln(entry);
    }
    buf.writeln('    };');
    buf.writeln('  }');
    buf.writeln('}');
    final updateDtoName = '${className}UpdateDto';
    buf.writeln('class $updateDtoName implements UpdateDto<$className> {');
    buf.writeln('  const $updateDtoName({');
    for (final c in columns.where((c) => !c.autoIncrement && !c.isPk)) {
      buf.writeln('    this.${c.prop},');
    }
    for (final relation in owningJoinColumns) {
      buf.writeln('    this.${relation.joinColumnPropertyName},');
    }
    buf.writeln('  });');
    for (final c in columns.where((c) => !c.autoIncrement && !c.isPk)) {
      buf.writeln('  final ${c.dartTypeCode}${c.nullable ? '' : '?'} ${c.prop};');
    }
    for (final relation in owningJoinColumns) {
      final joinType = relation.joinColumnBaseDartType!;
      buf.writeln('  final $joinType? ${relation.joinColumnPropertyName};');
    }
    buf.writeln();
    buf.writeln('  @override');
    buf.writeln('  Map<String, dynamic> toMap() {');
    buf.writeln('    return {');
    for (final c in columns.where((c) => !c.autoIncrement && !c.isPk)) {
      buf.writeln("      if(${c.prop} != null) '${c.name}': ${c.prop},");
    }
    for (final relation in owningJoinColumns) {
      buf.writeln("      if(${relation.joinColumnPropertyName} != null) '${relation.joinColumn!.name}': ${relation.joinColumnPropertyName},");
    }
    buf.writeln('    };');
    buf.writeln('  }');
    buf.writeln('}');

    return buf.toString();
  }

  DartObject? _firstAnnotation(FieldElement field, Type t) {
    final want = t.toString();
    final metas = (field.metadata as dynamic);
    final iterable = (metas is Iterable) ? metas : (metas.annotations as Iterable);
    for (final meta in iterable) {
      final obj = meta.computeConstantValue();
      if (obj == null) continue;
      final typeName = obj.type?.getDisplayString();
      if (typeName == want) return obj;
    }
    return null;
  }

  _GenRelation? _buildRelation(FieldElement field, String entityName, String tableName) {
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
    mappedBy = (mappedBy == null || mappedBy.trim().isEmpty) ? null : mappedBy.trim();
    var isOwning = mappedBy == null;

    switch (match.kind) {
      case _RelationKind.oneToMany:
        if (isOwning) {
          throw InvalidGenerationSourceError(
            '@OneToMany on $entityName.${field.displayName} must set mappedBy to the owning @ManyToOne field.',
            element: field,
          );
        }
        isOwning = false;
        break;
      case _RelationKind.manyToOne:
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
    final cascadeValues = cascadeReader == null ? const <DartObject>[] : cascadeReader.listValue;
    final cascadeLiteral = _enumListLiteral(
      cascadeValues,
      _relationCascadeNames,
      'RelationCascade',
    );

    final joinColumnAnn = _firstAnnotation(field, JoinColumn);
    final needsJoinColumn = isOwning && (match.kind == _RelationKind.oneToOne || match.kind == _RelationKind.manyToOne);
    final fieldIsNullable = field.type.nullabilitySuffix != NullabilitySuffix.none;
    _GenJoinColumn? joinColumn;
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
        fallbackUnique: match.kind == _RelationKind.oneToOne,
      );
    } else if (needsJoinColumn) {
      joinColumn = _GenJoinColumn(
        name: _toSnake('${field.displayName}_id'),
        referencedColumnName: 'id',
        nullable: fieldIsNullable,
        unique: match.kind == _RelationKind.oneToOne,
      );
    }

    final needsJoinTable = isOwning && (match.kind == _RelationKind.manyToMany);
    final joinTableAnn = _firstAnnotation(field, JoinTable);
    _GenJoinTable? joinTable;
    if (joinTableAnn != null) {
      if (match.kind != _RelationKind.manyToMany) {
        throw InvalidGenerationSourceError(
          '@JoinTable can only be used on many-to-many relations.',
          element: field,
        );
      }
      final ownerColFallback = '${_toSnake(entityName)}_${_toSnake(field.displayName)}_id';
      final inverseFallback = '${_toSnake(_simpleTypeName(targetTypeCode))}_id';
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

    // For inverse relations, determine if this is a collection type
    final isCollection = match.kind == _RelationKind.oneToMany || match.kind == _RelationKind.manyToMany;

    return _GenRelation(
      fieldName: field.displayName,
      type: match.kind,
      targetTypeCode: targetTypeCode,
      isOwningSide: isOwning,
      mappedBy: mappedBy,
      fetchLiteral: fetchLiteral,
      cascadeLiteral: cascadeLiteral,
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
    final mappings = <Type, _RelationKind>{
      OneToOne: _RelationKind.oneToOne,
      ManyToOne: _RelationKind.manyToOne,
      OneToMany: _RelationKind.oneToMany,
      ManyToMany: _RelationKind.manyToMany,
    };
    for (final entry in mappings.entries) {
      final ann = _firstAnnotation(field, entry.key);
      if (ann != null) {
        return _RelationMatch(entry.value, ConstantReader(ann), entry.key.toString());
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

  _GenJoinColumn _joinColumnFromConstant(
    DartObject obj, {
    required String fallbackName,
    required String fallbackReference,
    bool fallbackNullable = true,
    bool fallbackUnique = false,
  }) {
    final reader = ConstantReader(obj);
    final name = reader.peek('name')?.stringValue ?? fallbackName;
    final reference = reader.peek('referencedColumnName')?.stringValue ?? fallbackReference;
    final nullable = reader.peek('nullable')?.boolValue ?? fallbackNullable;
    final unique = reader.peek('unique')?.boolValue ?? fallbackUnique;
    return _GenJoinColumn(
      name: name,
      referencedColumnName: reference,
      nullable: nullable,
      unique: unique,
    );
  }

  _GenJoinTable _joinTableFromConstant(
    DartObject obj, {
    required String defaultName,
    required String ownerFallback,
    required String inverseFallback,
  }) {
    final reader = ConstantReader(obj);
    final name = reader.peek('name')?.stringValue ?? defaultName;
    final ownerListReader = reader.peek('joinColumns');
    final inverseListReader = reader.peek('inverseJoinColumns');
    final ownerObjs = ownerListReader == null ? const <DartObject>[] : ownerListReader.listValue;
    final inverseObjs = inverseListReader == null ? const <DartObject>[] : inverseListReader.listValue;
    final ownerCols = ownerObjs.isEmpty
        ? [
            _GenJoinColumn(
              name: ownerFallback,
              referencedColumnName: 'id',
              nullable: false,
              unique: false,
            ),
          ]
        : ownerObjs
            .map((o) => _joinColumnFromConstant(
                  o,
                  fallbackName: ownerFallback,
                  fallbackReference: 'id',
                  fallbackNullable: false,
                ))
            .toList();
    final inverseCols = inverseObjs.isEmpty
        ? [
            _GenJoinColumn(
              name: inverseFallback,
              referencedColumnName: 'id',
              nullable: false,
              unique: false,
            ),
          ]
        : inverseObjs
            .map((o) => _joinColumnFromConstant(
                  o,
                  fallbackName: inverseFallback,
                  fallbackReference: 'id',
                  fallbackNullable: false,
                ))
            .toList();
    return _GenJoinTable(
      name: name,
      joinColumns: ownerCols,
      inverseJoinColumns: inverseCols,
    );
  }

  String _simpleTypeName(String typeCode) {
    final genericsIndex = typeCode.indexOf('<');
    final trimmed = genericsIndex == -1 ? typeCode : typeCode.substring(0, genericsIndex);
    final dotIndex = trimmed.lastIndexOf('.');
    return dotIndex == -1 ? trimmed : trimmed.substring(dotIndex + 1);
  }

  String? _relationConstructorLiteral(FieldElement field, _RelationKind kind) {
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
    return type.typeArguments.first.nullabilitySuffix == NullabilitySuffix.question
        ? elementType.substring(0, elementType.length - 1)
        : elementType;
  }

  _PrimaryKeyInfo _resolvePrimaryKeyInfo(InterfaceType type) {
    final element = type.element;
    for (final field in element.fields.where((f) => !f.isStatic)) {
      if (_firstAnnotation(field, PrimaryKey) != null) {
        final columnAnnObj = _firstAnnotation(field, Column);
        final columnName = columnAnnObj == null
            ? _toSnake(field.displayName)
            : (ConstantReader(columnAnnObj).peek('name')?.stringValue ?? _toSnake(field.displayName));
        var dartType = field.type.getDisplayString();
        if (field.type.nullabilitySuffix != NullabilitySuffix.none) {
          dartType = dartType.substring(0, dartType.length - 1);
        }
        return _PrimaryKeyInfo(
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

  ColumnType _resolveColumnType(ConstantReader ann, DartType type) {
    final explicit = ann.peek('type');
    if (explicit != null && !explicit.isNull) {
      // If a specific ColumnType was provided, map it directly by reading the enum name.
      final ev = explicit.objectValue;
      final typeName = ev.type?.getDisplayString();
      if (typeName != null && typeName.endsWith('ColumnType')) {
        // Not reliable across analyzer versions; fall back to inference.
      }
    }
    return _inferColumnType(type);
  }

  ColumnType _inferColumnType(DartType type) {
    var name = type.getDisplayString();
    if (type.nullabilitySuffix == NullabilitySuffix.question) {
      name = name.substring(0, name.length - 1);
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
  static const _relationCascadeNames = ['persist', 'merge', 'remove', 'detach', 'refresh', 'all'];
}

enum _RelationKind { oneToOne, oneToMany, manyToOne, manyToMany }

class _RelationMatch {
  const _RelationMatch(this.kind, this.reader, this.annotationName);

  final _RelationKind kind;
  final ConstantReader reader;
  final String annotationName;
}

class _GenRelation {
  _GenRelation({
    required this.fieldName,
    required this.type,
    required this.targetTypeCode,
    required this.isOwningSide,
    required this.mappedBy,
    required this.fetchLiteral,
    required this.cascadeLiteral,
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
  final _RelationKind type;
  final String targetTypeCode;
  final bool isOwningSide;
  final String? mappedBy;
  final String fetchLiteral;
  final String cascadeLiteral;
  final _GenJoinColumn? joinColumn;
  final _GenJoinTable? joinTable;
  final String? constructorLiteral;
  final String? joinColumnPropertyName;
  final String? joinColumnBaseDartType;
  final bool joinColumnNullable;
  final String? targetPrimaryFieldName;
  final bool isCollection;

  String joinColumnLiteral() {
    final jc = joinColumn!;
    return 'JoinColumnDescriptor(name: ${_stringLiteral(jc.name)}, referencedColumnName: ${_stringLiteral(jc.referencedColumnName)}, nullable: ${jc.nullable}, unique: ${jc.unique})';
  }

  String joinTableLiteral() {
    final jt = joinTable!;
    final joinCols = jt.joinColumns.map((c) => c.literal).join(', ');
    final inverseCols = jt.inverseJoinColumns.map((c) => c.literal).join(', ');
    final joinList = jt.joinColumns.isEmpty ? 'const []' : 'const [$joinCols]';
    final inverseList = jt.inverseJoinColumns.isEmpty ? 'const []' : 'const [$inverseCols]';
    return 'JoinTableDescriptor(name: ${_stringLiteral(jt.name)}, joinColumns: $joinList, inverseJoinColumns: $inverseList)';
  }
}

class _GenJoinColumn {
  _GenJoinColumn({
    required this.name,
    required this.referencedColumnName,
    required this.nullable,
    required this.unique,
  });

  final String name;
  final String referencedColumnName;
  final bool nullable;
  final bool unique;

  String get literal =>
      'JoinColumnDescriptor(name: ${_stringLiteral(name)}, referencedColumnName: ${_stringLiteral(referencedColumnName)}, nullable: $nullable, unique: $unique)';
}

class _GenJoinTable {
  _GenJoinTable({
    required this.name,
    required this.joinColumns,
    required this.inverseJoinColumns,
  });

  final String name;
  final List<_GenJoinColumn> joinColumns;
  final List<_GenJoinColumn> inverseJoinColumns;
}

String _stringLiteral(String value) => "'${value.replaceAll("'", "\\'")}'";

class _PrimaryKeyInfo {
  const _PrimaryKeyInfo({
    required this.propertyName,
    required this.columnName,
    required this.dartTypeCode,
  });

  final String propertyName;
  final String columnName;
  final String dartTypeCode;
}

class _GenColumn {
  _GenColumn({
    required this.name,
    required this.prop,
    required this.type,
    required this.dartTypeCode,
    required this.nullable,
    required this.unique,
    required this.isPk,
    required this.autoIncrement,
    required this.uuid,
    this.defaultLiteral,
  });

  final String name;
  final String prop;
  final ColumnType type;
  final String dartTypeCode;
  final bool nullable;
  final bool unique;
  final bool isPk;
  final bool autoIncrement;
  final bool uuid;
  final String? defaultLiteral;
}
