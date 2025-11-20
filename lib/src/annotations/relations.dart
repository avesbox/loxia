/// Declares a one-to-one relationship.
class OneToOne {
  final Type on;
  final bool joinColumn;
  final String? referenceColumn;

  const OneToOne({
    required this.on,
    this.joinColumn = false,
    this.referenceColumn,
  });
}

/// Declares a one-to-many relationship hosted on the current entity.
class OneToMany {
  final Type on;
  final String? referenceColumn;

  const OneToMany({
    required this.on,
    this.referenceColumn,
  });
}

/// Declares a many-to-one relationship.
class ManyToOne {
  final Type on;
  final String? referenceColumn;

  const ManyToOne({
    required this.on,
    this.referenceColumn,
  });
}

/// Declares a many-to-many relationship.
class ManyToMany {
  final Type on;
  final String? joinTable;

  const ManyToMany({
    required this.on,
    this.joinTable,
  });
}
