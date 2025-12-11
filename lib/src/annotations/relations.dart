/// Defines how related records should be fetched at runtime.
enum RelationFetchStrategy { eager, lazy }

/// Describes cascading operations that propagate to relations.
enum RelationCascade {
  persist,
  merge,
  remove,
  detach,
  refresh,
  all,
}

/// Declares a one-to-one relationship.
class OneToOne {
  final Type on;
  final String? mappedBy;
  final List<RelationCascade> cascade;
  final RelationFetchStrategy fetch;

  const OneToOne({
    required this.on,
    this.mappedBy,
    this.cascade = const [],
    this.fetch = RelationFetchStrategy.lazy,
  });
}

/// Declares a many-to-one relationship.
class ManyToOne {
  final Type on;
  final String? mappedBy;
  final List<RelationCascade> cascade;
  final RelationFetchStrategy fetch;

  const ManyToOne({
    required this.on,
    this.mappedBy,
    this.cascade = const [],
    this.fetch = RelationFetchStrategy.lazy,
  });
}

/// Declares a one-to-many relationship hosted on the current entity.
class OneToMany {
  final Type on;
  final String? mappedBy;
  final List<RelationCascade> cascade;
  final RelationFetchStrategy fetch;

  const OneToMany({
    required this.on,
    this.mappedBy,
    this.cascade = const [],
    this.fetch = RelationFetchStrategy.lazy,
  });
}

/// Declares a many-to-many relationship.
class ManyToMany {
  final Type on;
  final String? mappedBy;
  final List<RelationCascade> cascade;
  final RelationFetchStrategy fetch;

  const ManyToMany({
    required this.on,
    this.mappedBy,
    this.cascade = const [],
    this.fetch = RelationFetchStrategy.lazy,
  });
}
