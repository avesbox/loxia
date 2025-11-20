/// Enum describing the type of relationship.
enum RelationType {
  oneToOne,
  oneToMany,
  manyToOne,
  manyToMany,
}

/// Describes a relationship between two entities.
class RelationDescriptor {
  RelationDescriptor({
    required this.fieldName,
    required this.type,
    required this.target,
    this.joinColumn,
    this.referenceColumn,
    this.joinTable,
  });

  final String fieldName;
  final RelationType type;
  final Type target;
  final bool? joinColumn;
  final String? referenceColumn;
  final String? joinTable;
}
