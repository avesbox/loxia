/// Marks a class as a Loxia entity and optionally overrides table metadata.
class EntityMeta {
  /// Custom table name. Defaults to the class name converted to snake case.
  final String? table;

  /// Database schema or namespace.
  final String? schema;

  const EntityMeta({this.table, this.schema});
}
