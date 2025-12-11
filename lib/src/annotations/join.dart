/// Declares the join column used to link two entities.
class JoinColumn {
  final String? name;
  final String? referencedColumnName;
  final bool nullable;
  final bool unique;

  const JoinColumn({
    this.name,
    this.referencedColumnName,
    this.nullable = true,
    this.unique = false,
  });
}

/// Declares the join table that backs a relation.
class JoinTable {
  final String? name;
  final List<JoinColumn> joinColumns;
  final List<JoinColumn> inverseJoinColumns;

  const JoinTable({
    this.name,
    this.joinColumns = const [],
    this.inverseJoinColumns = const [],
  });
}
