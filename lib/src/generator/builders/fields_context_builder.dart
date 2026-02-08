/// Builder for generating the FieldsContext class.
library;

import 'package:code_builder/code_builder.dart';

import 'models.dart';
import 'utils.dart';

/// Builds the QueryFieldsContext subclass for an entity.
class FieldsContextBuilder {
  const FieldsContextBuilder();

  /// Builds the complete FieldsContext class.
  Class build(EntityGenerationContext context) {
    return Class(
      (c) => c
        ..name = context.fieldsContextName
        ..extend = TypeReference(
          (t) => t
            ..symbol = 'QueryFieldsContext'
            ..types.add(refer(context.entityName)),
        )
        ..constructors.add(_buildConstructor(context))
        ..methods.add(_buildBindMethod(context))
        ..methods.addAll(_buildColumnGetters(context))
        ..methods.addAll(_buildJoinColumnGetters(context))
        ..methods.addAll(_buildOwningRelationGetters(context))
        ..methods.addAll(_buildManyToManyRelationGetters(context))
        ..methods.addAll(_buildInverseRelationGetters(context)),
    );
  }

  Constructor _buildConstructor(EntityGenerationContext context) {
    return Constructor(
      (c) => c
        ..constant = true
        ..optionalParameters.addAll([
          Parameter(
            (p) => p
              ..name = 'runtime'
              ..toSuper = true,
          ),
          Parameter(
            (p) => p
              ..name = 'alias'
              ..toSuper = true,
          ),
        ]),
    );
  }

  Method _buildBindMethod(EntityGenerationContext context) {
    return Method(
      (m) => m
        ..annotations.add(refer('override'))
        ..name = 'bind'
        ..returns = refer(context.fieldsContextName)
        ..requiredParameters.addAll([
          Parameter(
            (p) => p
              ..name = 'runtime'
              ..type = refer('QueryRuntimeContext'),
          ),
          Parameter(
            (p) => p
              ..name = 'alias'
              ..type = refer('String'),
          ),
        ])
        ..body = refer(
          context.fieldsContextName,
        ).newInstance([refer('runtime'), refer('alias')]).code
        ..lambda = true,
    );
  }

  Iterable<Method> _buildColumnGetters(EntityGenerationContext context) {
    return context.columns.map(
      (c) => Method(
        (m) => m
          ..type = MethodType.getter
          ..name = c.prop
          ..returns = TypeReference(
            (t) => t
              ..symbol = 'QueryField'
              ..types.add(refer(c.dartTypeCode)),
          )
          ..body = refer(
            'field',
          ).call([literalString(c.name)], {}, [refer(c.dartTypeCode)]).code
          ..lambda = true,
      ),
    );
  }

  Iterable<Method> _buildJoinColumnGetters(EntityGenerationContext context) {
    return context.owningJoinColumns
        .where((r) => r.joinColumnPropertyName != null)
        .map((relation) {
          final joinType = relation.joinColumnBaseDartType!;
          final typeWithNull = relation.joinColumnNullable
              ? '$joinType?'
              : joinType;
          return Method(
            (m) => m
              ..type = MethodType.getter
              ..name = relation.joinColumnPropertyName!
              ..returns = TypeReference(
                (t) => t
                  ..symbol = 'QueryField'
                  ..types.add(refer(typeWithNull)),
              )
              ..body = refer('field')
                  .call(
                    [literalString(relation.joinColumn!.name)],
                    {},
                    [refer(typeWithNull)],
                  )
                  .code
              ..lambda = true,
          );
        });
  }

  Iterable<Method> _buildOwningRelationGetters(
    EntityGenerationContext context,
  ) {
    return context.owningJoinColumns.map((relation) {
      final targetSimple = simpleTypeName(relation.targetTypeCode);
      final targetContext = '${targetSimple}FieldsContext';
      final descriptorRef = '\$${targetSimple}EntityDescriptor';

      return Method(
        (m) => m
          ..type = MethodType.getter
          ..name = relation.fieldName
          ..returns = refer(targetContext)
          ..body = Block.of([
            declareFinal('alias')
                .assign(
                  refer('ensureRelationJoin').call([], {
                    'relationName': literalString(relation.fieldName),
                    'targetTableName': refer(
                      descriptorRef,
                    ).property('qualifiedTableName'),
                    'localColumn': literalString(relation.joinColumn!.name),
                    'foreignColumn': literalString(
                      relation.joinColumn!.referencedColumnName,
                    ),
                    'joinType': refer('JoinType.left'),
                  }),
                )
                .statement,
            refer(targetContext)
                .newInstance([refer('runtimeOrThrow'), refer('alias')])
                .returned
                .statement,
          ]),
      );
    });
  }

  Iterable<Method> _buildManyToManyRelationGetters(
    EntityGenerationContext context,
  ) {
    return context.manyToManyRelations.map((relation) {
      final targetSimple = simpleTypeName(relation.targetTypeCode);
      final targetContext = '${targetSimple}FieldsContext';
      final descriptorRef = '\$${targetSimple}EntityDescriptor';
      final joinTable = relation.joinTable!;
      final joinColumn = joinTable.joinColumns.first;
      final inverseJoinColumn = joinTable.inverseJoinColumns.first;

      return Method(
        (m) => m
          ..type = MethodType.getter
          ..name = relation.fieldName
          ..returns = refer(targetContext)
          ..docs.add('/// Join through the ${joinTable.name} join table')
          ..body = Block.of([
            // First join: owner table -> join table
            declareFinal('joinTableAlias')
                .assign(
                  refer('ensureRelationJoin').call([], {
                    'relationName': literalString('${relation.fieldName}_jt'),
                    'targetTableName': literalString(joinTable.name),
                    'localColumn': literalString(
                      joinColumn.referencedColumnName,
                    ),
                    'foreignColumn': literalString(joinColumn.name),
                    'joinType': refer('JoinType.left'),
                  }),
                )
                .statement,
            // Second join: join table -> target table
            declareFinal('alias')
                .assign(
                  refer('ensureRelationJoinFrom').call([], {
                    'fromAlias': refer('joinTableAlias'),
                    'relationName': literalString(relation.fieldName),
                    'targetTableName': refer(
                      descriptorRef,
                    ).property('qualifiedTableName'),
                    'localColumn': literalString(inverseJoinColumn.name),
                    'foreignColumn': literalString(
                      inverseJoinColumn.referencedColumnName,
                    ),
                    'joinType': refer('JoinType.left'),
                  }),
                )
                .statement,
            refer(targetContext)
                .newInstance([refer('runtimeOrThrow'), refer('alias')])
                .returned
                .statement,
          ]),
      );
    });
  }

  Iterable<Method> _buildInverseRelationGetters(
    EntityGenerationContext context,
  ) {
    return context.inverseRelations.map((relation) {
      final targetSimple = simpleTypeName(relation.targetTypeCode);
      final targetContext = '${targetSimple}FieldsContext';
      final descriptorRef = '\$${targetSimple}EntityDescriptor';
      final mappedBy = relation.mappedBy!;

      return Method(
        (m) => m
          ..type = MethodType.getter
          ..name = relation.fieldName
          ..returns = refer(targetContext)
          ..docs.add(
            '/// Find the owning relation on the target entity to get join column info',
          )
          ..body = Block.of([
            declareFinal('targetRelation')
                .assign(
                  refer(
                    descriptorRef,
                  ).property('relations').property('firstWhere').call([
                    Method(
                      (m) => m
                        ..requiredParameters.add(
                          Parameter((p) => p..name = 'r'),
                        )
                        ..body = refer('r')
                            .property('fieldName')
                            .equalTo(literalString(mappedBy))
                            .code
                        ..lambda = true,
                    ).closure,
                  ]),
                )
                .statement,
            declareFinal('joinColumn')
                .assign(
                  refer('targetRelation').property('joinColumn').nullChecked,
                )
                .statement,
            declareFinal('alias')
                .assign(
                  refer('ensureRelationJoin').call([], {
                    'relationName': literalString(relation.fieldName),
                    'targetTableName': refer(
                      descriptorRef,
                    ).property('qualifiedTableName'),
                    'localColumn': refer(
                      'joinColumn',
                    ).property('referencedColumnName'),
                    'foreignColumn': refer('joinColumn').property('name'),
                    'joinType': refer('JoinType.left'),
                  }),
                )
                .statement,
            refer(targetContext)
                .newInstance([refer('runtimeOrThrow'), refer('alias')])
                .returned
                .statement,
          ]),
      );
    });
  }
}
