/// Builder for generating the SelectOptions class.
library;

import 'package:code_builder/code_builder.dart';

import '../../annotations/column.dart';
import 'models.dart';
import 'utils.dart';

/// Builds the SelectOptions subclass for an entity.
class SelectOptionsBuilder {
  const SelectOptionsBuilder();

  /// Builds the complete Select class.
  Class build(EntityGenerationContext context) {
    return Class(
      (c) => c
        ..name = context.selectClassName
        ..extend = TypeReference(
          (t) => t
            ..symbol = 'SelectOptions'
            ..types.addAll([
              refer(context.entityName),
              refer(context.partialEntityName),
            ]),
        )
        ..constructors.add(_buildConstructor(context))
        ..fields.addAll(_buildColumnFields(context))
        ..fields.addAll(_buildJoinColumnFields(context))
        ..fields.add(_buildRelationsField(context))
        ..methods.add(_buildHasSelectionsGetter(context))
        ..methods.add(_buildWithRelationsMethod(context))
        ..methods.add(_buildCollectMethod(context))
        ..methods.add(_buildHydrateMethod(context))
        ..methods.add(_buildHasCollectionRelationsGetter(context))
        ..methods.add(_buildPrimaryKeyColumnGetter(context))
        ..methods.addAll(_buildAggregateRowsMethod(context)),
    );
  }

  Constructor _buildConstructor(EntityGenerationContext context) {
    final params = <Parameter>[];

    for (final c in context.columns) {
      params.add(
        Parameter(
          (p) => p
            ..name = c.prop
            ..named = true
            ..toThis = true
            ..defaultTo = literalTrue.code,
        ),
      );
    }

    for (final relation in context.owningJoinColumns) {
      final joinProp = relation.joinColumnPropertyName;
      if (joinProp != null) {
        params.add(
          Parameter(
            (p) => p
              ..name = joinProp
              ..named = true
              ..toThis = true
              ..defaultTo = literalTrue.code,
          ),
        );
      }
    }

    params.add(
      Parameter(
        (p) => p
          ..name = 'relations'
          ..named = true
          ..toThis = true,
      ),
    );

    return Constructor(
      (c) => c
        ..constant = true
        ..optionalParameters.addAll(params),
    );
  }

  Iterable<Field> _buildColumnFields(EntityGenerationContext context) {
    return context.columns.map(
      (c) => Field(
        (f) => f
          ..name = c.prop
          ..modifier = FieldModifier.final$
          ..type = refer('bool'),
      ),
    );
  }

  Iterable<Field> _buildJoinColumnFields(EntityGenerationContext context) {
    return context.owningJoinColumns
        .where((r) => r.joinColumnPropertyName != null)
        .map(
          (relation) => Field(
            (f) => f
              ..name = relation.joinColumnPropertyName!
              ..modifier = FieldModifier.final$
              ..type = refer('bool'),
          ),
        );
  }

  Field _buildRelationsField(EntityGenerationContext context) {
    return Field(
      (f) => f
        ..name = 'relations'
        ..modifier = FieldModifier.final$
        ..type = refer('${context.relationsClassName}?'),
    );
  }

  Method _buildHasSelectionsGetter(EntityGenerationContext context) {
    final parts = <String>[];
    parts.addAll(context.columns.map((c) => c.prop));
    for (final relation in context.owningJoinColumns) {
      final joinProp = relation.joinColumnPropertyName;
      if (joinProp != null) {
        parts.add(joinProp);
      }
    }
    parts.add('(relations?.hasSelections ?? false)');

    return Method(
      (m) => m
        ..annotations.add(refer('override'))
        ..type = MethodType.getter
        ..name = 'hasSelections'
        ..returns = refer('bool')
        ..body = Code(parts.join(' || '))
        ..lambda = true,
    );
  }

  Method _buildCollectMethod(EntityGenerationContext context) {
    final statements = <Code>[
      Code('''
if (context is! ${context.fieldsContextName}) {
  throw ArgumentError('Expected ${context.fieldsContextName} for ${context.selectClassName}');
}
final ${context.fieldsContextName} scoped = context;
String? aliasFor(String column) {
  final current = path;
  if (current == null || current.isEmpty) return null;
  return '\${current}_\$column';
}
final tableAlias = scoped.currentAlias;'''),
    ];

    // Column selection statements
    for (final c in context.columns) {
      statements.add(
        Code('''
if (${c.prop}) {
  out.add(SelectField('${c.name}', tableAlias: tableAlias, alias: aliasFor('${c.name}')));
}'''),
      );
    }

    // Join column selection statements
    for (final relation in context.owningJoinColumns) {
      final joinProp = relation.joinColumnPropertyName;
      final joinColumn = relation.joinColumn?.name;
      if (joinProp != null && joinColumn != null) {
        statements.add(
          Code('''
if ($joinProp) {
  out.add(SelectField('$joinColumn', tableAlias: tableAlias, alias: aliasFor('$joinColumn')));
}'''),
        );
      }
    }

    statements.add(
      Code('''
final rels = relations;
if (rels != null && rels.hasSelections) {
  rels.collect(scoped, out, path: path);
}'''),
    );

    return Method(
      (m) => m
        ..annotations.add(refer('override'))
        ..name = 'collect'
        ..returns = refer('void')
        ..requiredParameters.addAll([
          Parameter(
            (p) => p
              ..name = 'context'
              ..type = TypeReference(
                (t) => t
                  ..symbol = 'QueryFieldsContext'
                  ..types.add(refer(context.entityName)),
              ),
          ),
          Parameter(
            (p) => p
              ..name = 'out'
              ..type = refer('List<SelectField>'),
          ),
        ])
        ..optionalParameters.add(
          Parameter(
            (p) => p
              ..name = 'path'
              ..named = true
              ..type = refer('String?'),
          ),
        )
        ..body = Block.of(statements),
    );
  }

  Method _buildWithRelationsMethod(EntityGenerationContext context) {
    final args = <String>[];
    for (final c in context.columns) {
      args.add('${c.prop}: ${c.prop}');
    }
    for (final relation in context.owningJoinColumns) {
      final joinProp = relation.joinColumnPropertyName;
      if (joinProp != null) {
        args.add('$joinProp: $joinProp');
      }
    }
    args.add('relations: relations as ${context.relationsClassName}?');

    return Method(
      (m) => m
        ..annotations.add(refer('override'))
        ..name = 'withRelations'
        ..returns = TypeReference(
          (t) => t
            ..symbol = 'SelectOptions'
            ..types.addAll([
              refer(context.entityName),
              refer(context.partialEntityName),
            ]),
        )
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'relations'
              ..type = TypeReference(
                (t) => t
                  ..symbol = 'RelationsOptions'
                  ..types.addAll([
                    refer(context.entityName),
                    refer(context.partialEntityName),
                  ])
                  ..isNullable = true,
              ),
          ),
        )
        ..body = Code(
          'return ${context.selectClassName}(${args.join(', ')});',
        ),
    );
  }

  Method _buildHydrateMethod(EntityGenerationContext context) {
    final statements = <Code>[];

    // Hydrate owning relations
    for (final relation in context.owningJoinColumns) {
      final targetSimple = simpleTypeName(relation.targetTypeCode);
      statements.add(
        Code('''
${targetSimple}Partial? ${relation.fieldName}Partial;
final ${relation.fieldName}Select = relations?.${relation.fieldName};
if (${relation.fieldName}Select != null && ${relation.fieldName}Select.hasSelections) {
  ${relation.fieldName}Partial = ${relation.fieldName}Select.hydrate(row, path: extendPath(path, '${relation.fieldName}'));
}'''),
      );
    }

    // Hydrate inverse relations
    for (final relation in context.inverseRelations) {
      final targetSimple = simpleTypeName(relation.targetTypeCode);
      if (relation.isCollection) {
        statements.add(
          Code(
            '// Collection relation ${relation.fieldName} requires row aggregation',
          ),
        );
      } else {
        statements.add(
          Code('''
${targetSimple}Partial? ${relation.fieldName}Partial;
final ${relation.fieldName}Select = relations?.${relation.fieldName};
if (${relation.fieldName}Select != null && ${relation.fieldName}Select.hasSelections) {
  ${relation.fieldName}Partial = ${relation.fieldName}Select.hydrate(row, path: extendPath(path, '${relation.fieldName}'));
}'''),
        );
      }
    }

    // Build return statement
    final returnParts = <String>[];
    for (final c in context.columns) {
      final readExpr = "readValue(row, '${c.name}', path: path)";
      final hydrated = _hydrateColumnValue(c, readExpr);
      returnParts.add('${c.prop}: ${c.prop} ? $hydrated : null');
    }
    for (final relation in context.owningJoinColumns) {
      final joinProp = relation.joinColumnPropertyName;
      if (joinProp != null) {
        final joinType = relation.joinColumnBaseDartType!;
        returnParts.add(
          "$joinProp: $joinProp ? readValue(row, '${relation.joinColumn!.name}', path: path) as $joinType? : null",
        );
      }
      returnParts.add('${relation.fieldName}: ${relation.fieldName}Partial');
    }
    for (final relation in context.inverseRelations) {
      if (relation.isCollection) {
        returnParts.add('${relation.fieldName}: null');
      } else {
        returnParts.add('${relation.fieldName}: ${relation.fieldName}Partial');
      }
    }

    statements.add(
      Code('return ${context.partialEntityName}(${returnParts.join(', ')});'),
    );

    return Method(
      (m) => m
        ..annotations.add(refer('override'))
        ..name = 'hydrate'
        ..returns = refer(context.partialEntityName)
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'row'
              ..type = refer('Map<String, dynamic>'),
          ),
        )
        ..optionalParameters.add(
          Parameter(
            (p) => p
              ..name = 'path'
              ..named = true
              ..type = refer('String?'),
          ),
        )
        ..body = Block.of(statements),
    );
  }

  Method _buildHasCollectionRelationsGetter(EntityGenerationContext context) {
    return Method(
      (m) => m
        ..annotations.add(refer('override'))
        ..type = MethodType.getter
        ..name = 'hasCollectionRelations'
        ..returns = refer('bool')
        ..body = literalBool(context.hasCollectionRelations).code
        ..lambda = true,
    );
  }

  Method _buildPrimaryKeyColumnGetter(EntityGenerationContext context) {
    return Method(
      (m) => m
        ..annotations.add(refer('override'))
        ..type = MethodType.getter
        ..name = 'primaryKeyColumn'
        ..returns = refer('String?')
        ..body = literalString(context.primaryKeyColumn.name).code
        ..lambda = true,
    );
  }

  Iterable<Method> _buildAggregateRowsMethod(EntityGenerationContext context) {
    if (!context.hasCollectionRelations) {
      return [];
    }
    final pkColumn = context.primaryKeyColumn;
    final statements = <Code>[
      Code('if (rows.isEmpty) return [];'),
      Code('final grouped = <Object?, List<Map<String, dynamic>>>{};'),
      Code('''
for (final row in rows) {
  final key = readValue(row, '${pkColumn.name}', path: path);
  (grouped[key] ??= []).add(row);
}'''),
    ];

    // Build aggregation logic
    final aggregationParts = <String>[];
    aggregationParts.add('final groupRows = entry.value;');
    aggregationParts.add('final firstRow = groupRows.first;');
    aggregationParts.add('final base = hydrate(firstRow, path: path);');

    // Collection aggregation for each inverse collection relation
    for (final relation in context.inverseRelations.where(
      (r) => r.isCollection,
    )) {
      final targetSimple = simpleTypeName(relation.targetTypeCode);
      final relationName = relation.fieldName;
      aggregationParts.add('''
// Aggregate $relationName collection
final ${relationName}Select = relations?.$relationName;
List<${targetSimple}Partial>? ${relationName}List;
if (${relationName}Select != null && ${relationName}Select.hasSelections) {
  final relationPath = extendPath(path, '$relationName');
  ${relationName}List = <${targetSimple}Partial>[];
  final seenKeys = <Object?>{};
  for (final row in groupRows) {
    final itemKey = ${relationName}Select.readValue(row, ${relationName}Select.primaryKeyColumn ?? 'id', path: relationPath);
    if (itemKey != null && seenKeys.add(itemKey)) {
      ${relationName}List.add(${relationName}Select.hydrate(row, path: relationPath));
    }
  }
}''');
    }

    // Build return partial
    final returnParts = <String>[];
    for (final c in context.columns) {
      returnParts.add('${c.prop}: base.${c.prop}');
    }
    for (final relation in context.owningJoinColumns) {
      final joinProp = relation.joinColumnPropertyName;
      if (joinProp != null) {
        returnParts.add('$joinProp: base.$joinProp');
      }
      returnParts.add('${relation.fieldName}: base.${relation.fieldName}');
    }
    for (final relation in context.inverseRelations) {
      if (relation.isCollection) {
        returnParts.add('${relation.fieldName}: ${relation.fieldName}List');
      } else {
        returnParts.add('${relation.fieldName}: base.${relation.fieldName}');
      }
    }
    aggregationParts.add(
      'return ${context.partialEntityName}(${returnParts.join(', ')});',
    );

    statements.add(
      Code('''
return grouped.entries.map((entry) {
  ${aggregationParts.join('\n  ')}
}).toList();'''),
    );

    return [
      Method(
        (m) => m
          ..annotations.add(refer('override'))
          ..name = 'aggregateRows'
          ..returns = refer('List<${context.partialEntityName}>')
          ..requiredParameters.add(
            Parameter(
              (p) => p
                ..name = 'rows'
                ..type = refer('List<Map<String, dynamic>>'),
            ),
          )
          ..optionalParameters.add(
            Parameter(
              (p) => p
                ..name = 'path'
                ..named = true
                ..type = refer('String?'),
            ),
          )
          ..body = Block.of(statements),
      ),
    ];
  }

  String _hydrateColumnValue(GenColumn c, String readExpr) {
    final baseType = c.dartTypeCode.replaceAll('?', '');
    if (c.isEnum) {
      final enumType = c.enumTypeName ?? baseType;
      switch (c.type) {
        case ColumnType.text:
          final expr = '$enumType.values.byName($readExpr as String)';
          return c.nullable ? '$readExpr == null ? null : $expr' : expr;
        case ColumnType.integer:
          final expr = '$enumType.values[$readExpr as int]';
          return c.nullable ? '$readExpr == null ? null : $expr' : expr;
        default:
          return c.nullable
              ? '$readExpr as $enumType?'
              : '$readExpr as $enumType';
      }
    }
    if (c.isCreatedAt || c.isUpdatedAt) {
      final parsed =
          '($readExpr is String ? DateTime.parse($readExpr as String) : $readExpr as DateTime)';
      switch (baseType) {
        case 'int':
          final expr = '$parsed.millisecondsSinceEpoch';
          return c.nullable ? '$readExpr == null ? null : $expr' : expr;
        case 'double':
          final expr = '$parsed.millisecondsSinceEpoch.toDouble()';
          return c.nullable ? '$readExpr == null ? null : $expr' : expr;
        case 'String':
          final expr = '$parsed.toIso8601String()';
          return c.nullable ? '$readExpr == null ? null : $expr' : expr;
        default:
          return c.nullable ? '$readExpr == null ? null : $parsed' : parsed;
      }
    }
    if (c.type == ColumnType.dateTime && baseType == 'DateTime') {
      final parsed =
          '($readExpr is String ? DateTime.parse($readExpr as String) : $readExpr as DateTime)';
      return c.nullable ? '$readExpr == null ? null : $parsed' : parsed;
    }
    if (c.type == ColumnType.json) {
      final decoded = 'decodeJsonColumn($readExpr)';
      final casted = _castJson(decoded, baseType);
      return c.nullable ? '$readExpr == null ? null : $casted' : casted;
    }
    return c.nullable ? '$readExpr as $baseType?' : '$readExpr as $baseType';
  }

  String _castJson(String decoded, String baseType) {
    final listMatch = RegExp(r'^List<(.+)>$').firstMatch(baseType);
    if (listMatch != null) {
      final elem = listMatch.group(1)!;
      return '($decoded as List).cast<$elem>()';
    }

    final mapMatch = RegExp(r'^Map<([^,>]+),\s*(.+)>$').firstMatch(baseType);
    if (mapMatch != null) {
      final key = mapMatch.group(1)!;
      final value = mapMatch.group(2)!;
      return '($decoded as Map).cast<$key, $value>()';
    }

    if (baseType == 'List') {
      return '($decoded as List).cast<dynamic>()';
    }
    if (baseType == 'Map') {
      return '($decoded as Map).cast<dynamic, dynamic>()';
    }

    return '$decoded as $baseType';
  }
}
