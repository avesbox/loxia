/// Builder for generating ColumnDescriptor instances.
library;

import 'package:code_builder/code_builder.dart';

import 'models.dart';
import 'utils.dart';

/// Builds a [ColumnDescriptor] expression for a given column.
class ColumnDescriptorBuilder {
  const ColumnDescriptorBuilder();

  /// Builds a single ColumnDescriptor expression.
  Expression build(GenColumn column) {
    return refer('ColumnDescriptor').newInstance([], {
      'name': literalString(column.name),
      'propertyName': literalString(column.prop),
      'type': refer('ColumnType.${column.type.name}'),
      'nullable': literalBool(column.nullable),
      'unique': literalBool(column.unique),
      'isPrimaryKey': literalBool(column.isPk),
      'autoIncrement': literalBool(column.autoIncrement),
      'uuid': literalBool(column.uuid),
      if (column.defaultLiteral != null)
        'defaultValue': CodeExpression(Code(column.defaultLiteral!)),
    });
  }

  /// Builds a list of ColumnDescriptor expressions.
  Expression buildList(List<GenColumn> columns) {
    return literalList(columns.map(build).toList());
  }
}

/// Builds a JoinColumnDescriptor expression.
class JoinColumnDescriptorBuilder {
  const JoinColumnDescriptorBuilder();

  /// Builds a single JoinColumnDescriptor expression.
  Expression build(GenJoinColumn joinColumn) {
    return refer('JoinColumnDescriptor').newInstance([], {
      'name': literalString(joinColumn.name),
      'referencedColumnName': literalString(joinColumn.referencedColumnName),
      'nullable': literalBool(joinColumn.nullable),
      'unique': literalBool(joinColumn.unique),
    });
  }

  /// Builds a const list of JoinColumnDescriptor expressions.
  Expression buildConstList(List<GenJoinColumn> columns) {
    if (columns.isEmpty) {
      return constList([]);
    }
    return constList(columns.map(build).toList());
  }
}

/// Builds a JoinTableDescriptor expression.
class JoinTableDescriptorBuilder {
  const JoinTableDescriptorBuilder();

  final _joinColumnBuilder = const JoinColumnDescriptorBuilder();

  /// Builds a JoinTableDescriptor expression.
  Expression build(GenJoinTable joinTable) {
    return refer('JoinTableDescriptor').newInstance([], {
      'name': literalString(joinTable.name),
      'joinColumns': _joinColumnBuilder.buildConstList(joinTable.joinColumns),
      'inverseJoinColumns':
          _joinColumnBuilder.buildConstList(joinTable.inverseJoinColumns),
    });
  }
}
