/// Builder for generating the PartialEntity class.
library;

import 'package:code_builder/code_builder.dart';

import '../../annotations/column.dart';
import 'models.dart';
import 'utils.dart';

/// Builds the PartialEntity subclass for an entity.
class PartialEntityBuilder {
  const PartialEntityBuilder();

  /// Builds the complete Partial entity class.
  Class build(EntityGenerationContext context) {
    return Class(
      (c) => c
        ..name = context.partialEntityName
        ..extend = TypeReference(
          (t) => t
            ..symbol = 'PartialEntity'
            ..types.add(refer(context.entityName)),
        )
        ..constructors.add(_buildConstructor(context))
        ..fields.addAll(_buildColumnFields(context))
        ..fields.addAll(_buildJoinColumnFields(context))
        ..fields.addAll(_buildRelationFields(context))
        ..methods.add(_buildPrimaryKeyGetter(context))
        ..methods.add(_buildToInsertDtoMethod(context))
        ..methods.add(_buildToUpdateDtoMethod(context))
        ..methods.add(_buildToEntityMethod(context))
        ..methods.add(_buildToJsonMethod(context)),
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
            ..toThis = true,
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
              ..toThis = true,
          ),
        );
      }
      params.add(
        Parameter(
          (p) => p
            ..name = relation.fieldName
            ..named = true
            ..toThis = true,
        ),
      );
    }

    for (final relation in context.manyToManyRelations) {
      params.add(
        Parameter(
          (p) => p
            ..name = relation.fieldName
            ..named = true
            ..toThis = true,
        ),
      );
    }

    for (final relation in context.inverseRelations) {
      params.add(
        Parameter(
          (p) => p
            ..name = relation.fieldName
            ..named = true
            ..toThis = true,
        ),
      );
    }

    return Constructor(
      (c) => c
        ..constant = true
        ..optionalParameters.addAll(params),
    );
  }

  Iterable<Field> _buildColumnFields(EntityGenerationContext context) {
    return context.columns.map((c) {
      var baseType = c.dartTypeCode;
      if (baseType.endsWith('?')) {
        baseType = baseType.substring(0, baseType.length - 1);
      }
      return Field(
        (f) => f
          ..name = c.prop
          ..modifier = FieldModifier.final$
          ..type = refer('$baseType?'),
      );
    });
  }

  Iterable<Field> _buildJoinColumnFields(EntityGenerationContext context) {
    return context.owningJoinColumns
        .where((r) => r.joinColumnPropertyName != null)
        .map(
          (relation) => Field(
            (f) => f
              ..name = relation.joinColumnPropertyName!
              ..modifier = FieldModifier.final$
              ..type = refer('${relation.joinColumnBaseDartType}?'),
          ),
        );
  }

  Iterable<Field> _buildRelationFields(EntityGenerationContext context) {
    final fields = <Field>[];

    for (final relation in context.owningJoinColumns) {
      final targetSimple = simpleTypeName(relation.targetTypeCode);
      fields.add(
        Field(
          (f) => f
            ..name = relation.fieldName
            ..modifier = FieldModifier.final$
            ..type = refer('${targetSimple}Partial?'),
        ),
      );
    }

    for (final relation in context.manyToManyRelations) {
      final targetSimple = simpleTypeName(relation.targetTypeCode);
      fields.add(
        Field(
          (f) => f
            ..name = relation.fieldName
            ..modifier = FieldModifier.final$
            ..type = refer('List<${targetSimple}Partial>?'),
        ),
      );
    }

    for (final relation in context.inverseRelations) {
      final targetSimple = simpleTypeName(relation.targetTypeCode);
      if (relation.isCollection) {
        fields.add(
          Field(
            (f) => f
              ..name = relation.fieldName
              ..modifier = FieldModifier.final$
              ..type = refer('List<${targetSimple}Partial>?'),
          ),
        );
      } else {
        fields.add(
          Field(
            (f) => f
              ..name = relation.fieldName
              ..modifier = FieldModifier.final$
              ..type = refer('${targetSimple}Partial?'),
          ),
        );
      }
    }

    return fields;
  }

  Method _buildToEntityMethod(EntityGenerationContext context) {
    final statements = <Code>[Code('final missing = <String>[];')];

    // Validation for required fields
    for (final c in context.columns.where((c) => !c.nullable)) {
      statements.add(Code("if (${c.prop} == null) missing.add('${c.prop}');"));
    }

    statements.add(
      Code('''
if (missing.isNotEmpty) {
  throw StateError('Cannot convert ${context.partialEntityName} to ${context.entityName}: missing required fields: \${missing.join(', ')}');
}'''),
    );

    // Build return statement
    final returnParts = <String>[];
    for (final c in context.columns) {
      final prop = c.prop;
      final assign = c.nullable ? prop : '$prop!';
      returnParts.add('$prop: $assign');
    }

    for (final r in context.owningJoinColumns) {
      returnParts.add('${r.fieldName}: ${r.fieldName}?.toEntity()');
    }

    for (final r in context.manyToManyRelations) {
      final defaultLiteral = r.constructorLiteral ?? 'const []';
      returnParts.add(
        '${r.fieldName}: ${r.fieldName}?.map((p) => p.toEntity()).toList() ?? $defaultLiteral',
      );
    }

    for (final r in context.inverseRelations) {
      if (r.isCollection) {
        final defaultLiteral = r.constructorLiteral ?? 'const []';
        returnParts.add(
          '${r.fieldName}: ${r.fieldName}?.map((p) => p.toEntity()).toList() ?? $defaultLiteral',
        );
      } else {
        returnParts.add('${r.fieldName}: ${r.fieldName}?.toEntity()');
      }
    }

    statements.add(
      Code('return ${context.entityName}(${returnParts.join(', ')});'),
    );

    return Method(
      (m) => m
        ..annotations.add(refer('override'))
        ..name = 'toEntity'
        ..returns = refer(context.entityName)
        ..body = Block.of(statements),
    );
  }

  Method _buildPrimaryKeyGetter(EntityGenerationContext context) {
    final pkProp = context.primaryKeyColumn.prop;
    return Method(
      (m) => m
        ..annotations.add(refer('override'))
        ..name = 'primaryKeyValue'
        ..type = MethodType.getter
        ..returns = refer('Object?')
        ..body = Code('return $pkProp;'),
    );
  }

  Method _buildToInsertDtoMethod(EntityGenerationContext context) {
    final insertableColumns = context.columns
        .where((c) => !c.autoIncrement && !c.isPk)
        .toList();
    final cascadeRelations = context.relations
        .where((r) => r.cascadePersist)
        .toList();

    final statements = <Code>[Code('final missing = <String>[];')];

    for (final c in insertableColumns) {
      if ((c.isCreatedAt || c.isUpdatedAt)) continue;
      if (!c.nullable && c.defaultLiteral == null) {
        statements.add(
          Code("if (${c.prop} == null) missing.add('${c.prop}');"),
        );
      }
    }

    for (final relation in context.owningJoinColumns) {
      if (!relation.joinColumnNullable) {
        statements.add(
          Code(
            "if (${relation.joinColumnPropertyName} == null) missing.add('${relation.joinColumnPropertyName}');",
          ),
        );
      }
    }

    statements.add(
      Code('''
if (missing.isNotEmpty) {
  throw StateError('Cannot convert ${context.partialEntityName} to ${context.insertDtoName}: missing required fields: \${missing.join(', ')}');
}'''),
    );

    final args = <String>[];
    for (final c in insertableColumns) {
      if (c.isCreatedAt || c.isUpdatedAt) {
        args.add('${c.prop}: ${c.prop}');
      } else if (!c.nullable && c.defaultLiteral == null) {
        args.add('${c.prop}: ${c.prop}!');
      } else if (c.defaultLiteral != null) {
        args.add('${c.prop}: ${c.prop} ?? ${c.defaultLiteral}');
      } else {
        args.add('${c.prop}: ${c.prop}');
      }
    }

    for (final relation in context.owningJoinColumns) {
      final prop = relation.joinColumnPropertyName!;
      if (relation.joinColumnNullable) {
        args.add('$prop: $prop');
      } else {
        args.add('$prop: $prop!');
      }
    }

    for (final relation in cascadeRelations) {
      final prop = relation.fieldName;
      if (relation.isCollection) {
        args.add('$prop: $prop?.map((p) => p.toInsertDto()).toList()');
      } else {
        args.add('$prop: $prop?.toInsertDto()');
      }
    }

    statements.add(
      Code('return ${context.insertDtoName}(${args.join(', ')});'),
    );

    return Method(
      (m) => m
        ..annotations.add(refer('override'))
        ..name = 'toInsertDto'
        ..returns = refer(context.insertDtoName)
        ..body = Block.of(statements),
    );
  }

  Method _buildToUpdateDtoMethod(EntityGenerationContext context) {
    final updateableColumns = context.columns
        .where((c) => !c.autoIncrement && !c.isPk)
        .toList();

    final args = <String>[];
    for (final c in updateableColumns) {
      args.add('${c.prop}: ${c.prop}');
    }
    for (final relation in context.owningJoinColumns) {
      final prop = relation.joinColumnPropertyName!;
      args.add('$prop: $prop');
    }

    return Method(
      (m) => m
        ..annotations.add(refer('override'))
        ..name = 'toUpdateDto'
        ..returns = refer(context.updateDtoName)
        ..body = Code('return ${context.updateDtoName}(${args.join(', ')});'),
    );
  }

  Method _buildToJsonMethod(EntityGenerationContext context) {
    final entries = <String>[];

    // Columns
    for (final c in context.columns) {
      final key = "'${c.prop}'";
      var value = c.prop;
      if (c.isEnum) {
        if (c.type == ColumnType.text) {
          value = '$value?.name';
        } else if (c.type == ColumnType.integer) {
          value = '$value?.index';
        }
      } else if (c.type == ColumnType.dateTime &&
          c.dartTypeCode.contains('DateTime')) {
        if (c.nullable) {
          value = '$value?.toIso8601String()';
        } else {
          value = '$value.toIso8601String()';
        }
      }
      entries.add('$key: $value');
    }

    // Relations
    for (final r in context.allSelectableRelations) {
      final key = "'${r.fieldName}'";
      var value = r.fieldName;
      if (r.isCollection) {
        // List<Partial>?
        value = '$value?.map((e) => e.toJson()).toList()';
        // If join table relation or such, assume .toJson exists on target partial
      } else {
        // Partial?
        value = '$value?.toJson()';
      }
      entries.add('$key: $value');
    }

    // Join Columns (exposed as IDs usually, e.g. userId)
    for (final r in context.owningJoinColumns) {
      final prop = r.joinColumnPropertyName;
      if (prop != null) {
        entries.add("'$prop': $prop");
      }
    }

    return Method(
      (m) => m
        ..annotations.add(refer('override'))
        ..name = 'toJson'
        ..returns = refer('Map<String, dynamic>')
        ..body = Code('return { ${entries.join(', ')} };'),
    );
  }
}
