import '../annotations/column.dart';

/// Describes a column at runtime. Instances are held by [EntityDescriptor].
class ColumnDescriptor {
  ColumnDescriptor({
    required this.name,
    required this.propertyName,
    required this.type,
    this.nullable = false,
    this.unique = false,
    this.isPrimaryKey = false,
    this.autoIncrement = false,
    this.uuid = false,
    this.defaultValue,
  });

  final String name;
  final String propertyName;
  final ColumnType type;
  final bool nullable;
  final bool unique;
  final bool isPrimaryKey;
  final bool autoIncrement;
  final bool uuid;
  final dynamic defaultValue;
}
