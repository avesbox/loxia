/// Builder for generating the PartialEntity class.
library;

import 'package:code_builder/code_builder.dart';

import 'models.dart';
import 'utils.dart';

/// Builds the PartialEntity subclass for an entity.
class PartialEntityBuilder {
  const PartialEntityBuilder();

  /// Builds the complete Partial entity class.
  Class build(EntityGenerationContext context) {
    return Class((c) => c
      ..name = context.partialEntityName
      ..extend = TypeReference((t) => t
        ..symbol = 'PartialEntity'
        ..types.add(refer(context.entityName)))
      ..constructors.add(_buildConstructor(context))
      ..fields.addAll(_buildColumnFields(context))
      ..fields.addAll(_buildJoinColumnFields(context))
      ..fields.addAll(_buildRelationFields(context))
      ..methods.add(_buildToEntityMethod(context)));
  }

  Constructor _buildConstructor(EntityGenerationContext context) {
    final params = <Parameter>[];

    for (final c in context.columns) {
      params.add(Parameter((p) => p
        ..name = c.prop
        ..named = true
        ..toThis = true));
    }

    for (final relation in context.owningJoinColumns) {
      final joinProp = relation.joinColumnPropertyName;
      if (joinProp != null) {
        params.add(Parameter((p) => p
          ..name = joinProp
          ..named = true
          ..toThis = true));
      }
      params.add(Parameter((p) => p
        ..name = relation.fieldName
        ..named = true
        ..toThis = true));
    }

    for (final relation in context.inverseRelations) {
      params.add(Parameter((p) => p
        ..name = relation.fieldName
        ..named = true
        ..toThis = true));
    }

    return Constructor((c) => c
      ..constant = true
      ..optionalParameters.addAll(params));
  }

  Iterable<Field> _buildColumnFields(EntityGenerationContext context) {
    return context.columns.map((c) => Field((f) => f
      ..name = c.prop
      ..modifier = FieldModifier.final$
      ..type = refer('${c.dartTypeCode}?')));
  }

  Iterable<Field> _buildJoinColumnFields(EntityGenerationContext context) {
    return context.owningJoinColumns
        .where((r) => r.joinColumnPropertyName != null)
        .map((relation) => Field((f) => f
          ..name = relation.joinColumnPropertyName!
          ..modifier = FieldModifier.final$
          ..type = refer('${relation.joinColumnBaseDartType}?')));
  }

  Iterable<Field> _buildRelationFields(EntityGenerationContext context) {
    final fields = <Field>[];

    for (final relation in context.owningJoinColumns) {
      final targetSimple = simpleTypeName(relation.targetTypeCode);
      fields.add(Field((f) => f
        ..name = relation.fieldName
        ..modifier = FieldModifier.final$
        ..type = refer('${targetSimple}Partial?')));
    }

    for (final relation in context.inverseRelations) {
      final targetSimple = simpleTypeName(relation.targetTypeCode);
      if (relation.isCollection) {
        fields.add(Field((f) => f
          ..name = relation.fieldName
          ..modifier = FieldModifier.final$
          ..type = refer('List<${targetSimple}Partial>?')));
      } else {
        fields.add(Field((f) => f
          ..name = relation.fieldName
          ..modifier = FieldModifier.final$
          ..type = refer('${targetSimple}Partial?')));
      }
    }

    return fields;
  }

  Method _buildToEntityMethod(EntityGenerationContext context) {
    final statements = <Code>[
      Code('final missing = <String>[];'),
    ];

    // Validation for required fields
    for (final c in context.columns.where((c) => !c.nullable)) {
      statements.add(Code("if (${c.prop} == null) missing.add('${c.prop}');"));
    }

    statements.add(Code('''
if (missing.isNotEmpty) {
  throw StateError('Cannot convert ${context.partialEntityName} to ${context.entityName}: missing required fields: ' + missing.join(', '));
}'''));

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

    for (final r in context.inverseRelations) {
      if (r.isCollection) {
        final defaultLiteral = r.constructorLiteral ?? 'const []';
        returnParts.add(
            '${r.fieldName}: ${r.fieldName}?.map((p) => p.toEntity()).toList() ?? $defaultLiteral');
      } else {
        returnParts.add('${r.fieldName}: ${r.fieldName}?.toEntity()');
      }
    }

    statements.add(
        Code('return ${context.entityName}(${returnParts.join(', ')});'));

    return Method((m) => m
      ..annotations.add(refer('override'))
      ..name = 'toEntity'
      ..returns = refer(context.entityName)
      ..body = Block.of(statements));
  }
}
