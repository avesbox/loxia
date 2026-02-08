import '../annotations/relations.dart';

/// Enum describing the type of relationship.
enum RelationType {
  oneToOne,
  oneToMany,
  manyToOne,
  manyToMany,
}

class JoinColumnDescriptor {
  const JoinColumnDescriptor({
    required this.name,
    required this.referencedColumnName,
    this.nullable = true,
    this.unique = false,
  });

  final String name;
  final String referencedColumnName;
  final bool nullable;
  final bool unique;
}

class JoinTableDescriptor {
  const JoinTableDescriptor({
    required this.name,
    this.joinColumns = const [],
    this.inverseJoinColumns = const [],
  });

  final String name;
  final List<JoinColumnDescriptor> joinColumns;
  final List<JoinColumnDescriptor> inverseJoinColumns;
}

/// Describes a relationship between two entities.
class RelationDescriptor {
  const RelationDescriptor({
    required this.fieldName,
    required this.type,
    required this.target,
    required this.isOwningSide,
    this.mappedBy,
    this.fetch = RelationFetchStrategy.lazy,
    this.cascade = const [],
    this.cascadePersist = false,
    this.cascadeMerge = false,
    this.cascadeRemove = false,
    this.joinColumn,
    this.joinTable,
  });

  final String fieldName;
  final RelationType type;
  final Type target;
  final bool isOwningSide;
  final String? mappedBy;
  final RelationFetchStrategy fetch;
  final List<RelationCascade> cascade;
  final bool cascadePersist;
  final bool cascadeMerge;
  final bool cascadeRemove;
  final JoinColumnDescriptor? joinColumn;
  final JoinTableDescriptor? joinTable;

  /// Returns true if this cascade should propagate persist operations.
  bool get shouldCascadePersist =>
      cascadePersist || cascade.contains(RelationCascade.persist) || cascade.contains(RelationCascade.all);

  /// Returns true if this cascade should propagate merge/update operations.
  bool get shouldCascadeMerge =>
      cascadeMerge || cascade.contains(RelationCascade.merge) || cascade.contains(RelationCascade.all);

  /// Returns true if this cascade should propagate remove/delete operations.
  bool get shouldCascadeRemove =>
      cascadeRemove || cascade.contains(RelationCascade.remove) || cascade.contains(RelationCascade.all);
}
