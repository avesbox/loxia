/// Builder for generating the Relations class.
library;

import 'package:code_builder/code_builder.dart';

import 'models.dart';
import 'utils.dart';

/// Builds the Relations class for an entity.
class RelationsClassBuilder {
  const RelationsClassBuilder();

  /// Builds the complete Relations class.
  Class build(EntityGenerationContext context) {
    final allRelations = context.allSelectableRelations;

    return Class(
      (c) => c
        ..name = context.relationsClassName
        ..extend = TypeReference(
          (t) => t
            ..symbol = 'RelationsOptions'
            ..types.addAll([
              refer(context.entityName),
              refer(context.partialEntityName),
            ]),
        )
        ..constructors.add(_buildConstructor(allRelations))
        ..fields.addAll(_buildFields(allRelations))
        ..methods.add(_buildHasSelectionsGetter(allRelations))
        ..methods.add(_buildCollectMethod(context, allRelations)),
    );
  }

  Constructor _buildConstructor(List<GenRelation> relations) {
    if (relations.isEmpty) {
      return Constructor((c) => c..constant = true);
    }
    return Constructor(
      (c) => c
        ..constant = true
        ..optionalParameters.addAll(
          relations.map(
            (r) => Parameter(
              (p) => p
                ..name = r.fieldName
                ..named = true
                ..toThis = true,
            ),
          ),
        ),
    );
  }

  Iterable<Field> _buildFields(List<GenRelation> relations) {
    return relations.map((relation) {
      final targetSimple = simpleTypeName(relation.targetTypeCode);
      return Field(
        (f) => f
          ..name = relation.fieldName
          ..modifier = FieldModifier.final$
          ..type = refer('${targetSimple}Select?'),
      );
    });
  }

  Method _buildHasSelectionsGetter(List<GenRelation> relations) {
    if (relations.isEmpty) {
      return Method(
        (m) => m
          ..annotations.add(refer('override'))
          ..type = MethodType.getter
          ..name = 'hasSelections'
          ..returns = refer('bool')
          ..body = literalFalse.code
          ..lambda = true,
      );
    }

    final checks = relations
        .map((r) => '(${r.fieldName}?.hasSelections ?? false)')
        .join(' || ');

    return Method(
      (m) => m
        ..annotations.add(refer('override'))
        ..type = MethodType.getter
        ..name = 'hasSelections'
        ..returns = refer('bool')
        ..body = Code(checks)
        ..lambda = true,
    );
  }

  Method _buildCollectMethod(
    EntityGenerationContext context,
    List<GenRelation> relations,
  ) {
    if (relations.isEmpty) {
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
          ..body = Block.of([
            Code('''
if (context is! ${context.fieldsContextName}) {
  throw ArgumentError('Expected ${context.fieldsContextName} for ${context.relationsClassName}');
}
'''),
          ]),
      );
    }

    final statements = <Code>[];
    for (final relation in relations) {
      final relationName = relation.fieldName;
      statements.addAll([
        Code('final ${relationName}Select = $relationName;'),
        Code('''
if (${relationName}Select != null && ${relationName}Select.hasSelections) {
  final relationPath = path == null || path.isEmpty ? '$relationName' : '\${path}_$relationName';
  final relationContext = scoped.$relationName;
  ${relationName}Select.collect(relationContext, out, path: relationPath);
}'''),
      ]);
    }

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
        ..body = Block.of([
          Code('''
if (context is! ${context.fieldsContextName}) {
  throw ArgumentError('Expected ${context.fieldsContextName} for ${context.relationsClassName}');
}
final ${context.fieldsContextName} scoped = context;
'''),
          ...statements,
        ]),
    );
  }
}
