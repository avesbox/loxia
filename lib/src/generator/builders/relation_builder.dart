/// Builder for generating RelationDescriptor instances.
library;

import 'package:code_builder/code_builder.dart';

import 'column_builder.dart';
import 'models.dart';

/// Builds RelationDescriptor expressions for entity relations.
class RelationDescriptorBuilder {
  const RelationDescriptorBuilder();

  final _joinColumnBuilder = const JoinColumnDescriptorBuilder();
  final _joinTableBuilder = const JoinTableDescriptorBuilder();

  /// Builds a single RelationDescriptor expression.
  Expression build(GenRelation relation) {
    final namedArgs = <String, Expression>{
      'fieldName': literalString(relation.fieldName),
      'type': refer('RelationType.${relation.type.name}'),
      'target': refer(relation.targetTypeCode),
      'isOwningSide': literalBool(relation.isOwningSide),
    };

    if (relation.mappedBy != null) {
      namedArgs['mappedBy'] = literalString(relation.mappedBy!);
    }

    namedArgs['fetch'] = CodeExpression(Code(relation.fetchLiteral));
    namedArgs['cascade'] = CodeExpression(Code(relation.cascadeLiteral));

    if (relation.joinColumn != null) {
      namedArgs['joinColumn'] = _joinColumnBuilder.build(relation.joinColumn!);
    }

    if (relation.joinTable != null) {
      namedArgs['joinTable'] = _joinTableBuilder.build(relation.joinTable!);
    }

    return refer('RelationDescriptor').constInstance([], namedArgs);
  }

  /// Builds a const list of RelationDescriptor expressions.
  Expression buildConstList(List<GenRelation> relations) {
    if (relations.isEmpty) {
      return literalConstList([]);
    }
    return literalConstList(relations.map(build).toList());
  }
}
