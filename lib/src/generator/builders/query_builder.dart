/// Builder for generating the Query class.
library;

import 'package:code_builder/code_builder.dart';

import 'models.dart';

/// Builds the QueryBuilder subclass for an entity.
class QueryClassBuilder {
  const QueryClassBuilder();

  /// Builds the complete Query class.
  Class build(EntityGenerationContext context) {
    return Class((c) => c
      ..name = context.queryClassName
      ..extend = TypeReference((t) => t
        ..symbol = 'QueryBuilder'
        ..types.add(refer(context.entityName)))
      ..constructors.add(_buildConstructor(context))
      ..fields.add(_buildBuilderField(context))
      ..methods.add(_buildBuildMethod(context)));
  }

  Constructor _buildConstructor(EntityGenerationContext context) {
    return Constructor((c) => c
      ..constant = true
      ..requiredParameters.add(Parameter((p) => p
        ..name = '_builder'
        ..toThis = true)));
  }

  Field _buildBuilderField(EntityGenerationContext context) {
    return Field((f) => f
      ..name = '_builder'
      ..modifier = FieldModifier.final$
      ..type = FunctionType((ft) => ft
        ..returnType = refer('WhereExpression')
        ..requiredParameters.add(refer(context.fieldsContextName))));
  }

  Method _buildBuildMethod(EntityGenerationContext context) {
    return Method((m) => m
      ..annotations.add(refer('override'))
      ..name = 'build'
      ..returns = refer('WhereExpression')
      ..requiredParameters.add(Parameter((p) => p
        ..name = 'context'
        ..type = TypeReference((t) => t
          ..symbol = 'QueryFieldsContext'
          ..types.add(refer(context.entityName)))))
      ..body = Block.of([
        Code(
            'if (context is! ${context.fieldsContextName}) { throw ArgumentError(\'Expected ${context.fieldsContextName} for ${context.queryClassName}\'); }'),
        refer('_builder').call([refer('context')]).returned.statement,
      ]));
  }
}
