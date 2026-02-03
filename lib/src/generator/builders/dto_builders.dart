/// Builders for generating InsertDto and UpdateDto classes.
library;

import 'package:code_builder/code_builder.dart';

import 'models.dart';

/// Builds the InsertDto class for an entity.
class InsertDtoBuilder {
  const InsertDtoBuilder();

  /// Builds the complete InsertDto class.
  Class build(EntityGenerationContext context) {
    final insertableColumns =
        context.columns.where((c) => !c.autoIncrement && !c.isPk).toList();

    return Class((c) => c
      ..name = context.insertDtoName
      ..implements.add(TypeReference((t) => t
        ..symbol = 'InsertDto'
        ..types.add(refer(context.entityName))))
      ..constructors.add(_buildConstructor(context, insertableColumns))
      ..fields.addAll(_buildColumnFields(insertableColumns))
      ..fields.addAll(_buildJoinColumnFields(context))
      ..methods.add(_buildToMapMethod(context, insertableColumns)));
  }

  Constructor _buildConstructor(
      EntityGenerationContext context, List<GenColumn> columns) {
    final params = <Parameter>[];

    for (final c in columns) {
      params.add(Parameter((p) => p
        ..name = c.prop
        ..named = true
        ..toThis = true
        ..required = !c.nullable && c.defaultLiteral == null
        ..defaultTo = c.defaultLiteral != null ? Code(c.defaultLiteral!) : null));
    }

    for (final relation in context.owningJoinColumns) {
      params.add(Parameter((p) => p
        ..name = relation.joinColumnPropertyName!
        ..named = true
        ..toThis = true
        ..required = !relation.joinColumnNullable));
    }

    return Constructor((c) => c
      ..constant = true
      ..optionalParameters.addAll(params));
  }

  Iterable<Field> _buildColumnFields(List<GenColumn> columns) {
    return columns.map((c) => Field((f) => f
      ..name = c.prop
      ..modifier = FieldModifier.final$
      ..type = refer(c.dartTypeCode)));
  }

  Iterable<Field> _buildJoinColumnFields(EntityGenerationContext context) {
    return context.owningJoinColumns.map((relation) {
      final joinType = relation.joinColumnBaseDartType!;
      final typeWithNull =
          relation.joinColumnNullable ? '$joinType?' : joinType;
      return Field((f) => f
        ..name = relation.joinColumnPropertyName!
        ..modifier = FieldModifier.final$
        ..type = refer(typeWithNull));
    });
  }

  Method _buildToMapMethod(
      EntityGenerationContext context, List<GenColumn> columns) {
    final entries = <String>[];

    for (final c in columns) {
      entries.add("'${c.name}': ${c.prop}");
    }

    for (final relation in context.owningJoinColumns) {
      final prop = relation.joinColumnPropertyName;
      if (relation.joinColumnNullable) {
        entries.add(
            "if($prop != null) '${relation.joinColumn!.name}': $prop");
      } else {
        entries.add("'${relation.joinColumn!.name}': $prop");
      }
    }

    return Method((m) => m
      ..annotations.add(refer('override'))
      ..name = 'toMap'
      ..returns = refer('Map<String, dynamic>')
      ..body = Code('return {${entries.join(', ')}};')
      ..lambda = false);
  }
}

/// Builds the UpdateDto class for an entity.
class UpdateDtoBuilder {
  const UpdateDtoBuilder();

  /// Builds the complete UpdateDto class.
  Class build(EntityGenerationContext context) {
    final updateableColumns =
        context.columns.where((c) => !c.autoIncrement && !c.isPk).toList();

    return Class((c) => c
      ..name = context.updateDtoName
      ..implements.add(TypeReference((t) => t
        ..symbol = 'UpdateDto'
        ..types.add(refer(context.entityName))))
      ..constructors.add(_buildConstructor(context, updateableColumns))
      ..fields.addAll(_buildColumnFields(updateableColumns))
      ..fields.addAll(_buildJoinColumnFields(context))
      ..methods.add(_buildToMapMethod(context, updateableColumns)));
  }

  Constructor _buildConstructor(
      EntityGenerationContext context, List<GenColumn> columns) {
    final params = <Parameter>[];

    for (final c in columns) {
      params.add(Parameter((p) => p
        ..name = c.prop
        ..named = true
        ..toThis = true));
    }

    for (final relation in context.owningJoinColumns) {
      params.add(Parameter((p) => p
        ..name = relation.joinColumnPropertyName!
        ..named = true
        ..toThis = true));
    }

    return Constructor((c) => c
      ..constant = true
      ..optionalParameters.addAll(params));
  }

  Iterable<Field> _buildColumnFields(List<GenColumn> columns) {
    return columns.map((c) {
      // For update DTO, all fields are optional (nullable)
      final type = c.nullable ? c.dartTypeCode : '${c.dartTypeCode}?';
      return Field((f) => f
        ..name = c.prop
        ..modifier = FieldModifier.final$
        ..type = refer(type));
    });
  }

  Iterable<Field> _buildJoinColumnFields(EntityGenerationContext context) {
    return context.owningJoinColumns.map((relation) {
      final joinType = relation.joinColumnBaseDartType!;
      return Field((f) => f
        ..name = relation.joinColumnPropertyName!
        ..modifier = FieldModifier.final$
        ..type = refer('$joinType?'));
    });
  }

  Method _buildToMapMethod(
      EntityGenerationContext context, List<GenColumn> columns) {
    final entries = <String>[];

    for (final c in columns) {
      entries.add("if(${c.prop} != null) '${c.name}': ${c.prop}");
    }

    for (final relation in context.owningJoinColumns) {
      entries.add(
          "if(${relation.joinColumnPropertyName} != null) '${relation.joinColumn!.name}': ${relation.joinColumnPropertyName}");
    }

    return Method((m) => m
      ..annotations.add(refer('override'))
      ..name = 'toMap'
      ..returns = refer('Map<String, dynamic>')
      ..body = Code('return {${entries.join(', ')}};')
      ..lambda = false);
  }
}
