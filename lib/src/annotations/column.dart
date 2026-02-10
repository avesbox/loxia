/// Declares a numeric, textual, or binary column on an entity.
class Column {
  final String? name;
  final ColumnType? type;
  final bool nullable;
  final bool unique;
  final dynamic defaultValue;

  const Column({
    this.name,
    this.type,
    this.nullable = false,
    this.unique = false,
    this.defaultValue,
  });
}

/// Marks a primary key column.
class PrimaryKey {
  final bool autoIncrement;
  final bool uuid;

  const PrimaryKey({this.autoIncrement = false, this.uuid = false});
}

/// Marks a column that should be indexed.
class IndexColumn {
  final String? name;
  final bool unique;

  const IndexColumn({this.name, this.unique = false});
}

/// A minimal column type enum used by annotations and descriptors.
enum ColumnType {
  integer,
  text,
  character,
  varChar,
  boolean,
  doublePrecision,
  dateTime,
  timestamp,
  json,
  binary,
  blob,
  uuid,
}
