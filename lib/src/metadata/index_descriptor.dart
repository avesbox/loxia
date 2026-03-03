/// Represents an index defined on a table.
class IndexDescriptor {
  IndexDescriptor({
    required this.name,
    required this.columns,
    this.unique = false,
  });

  final String name;
  final List<String> columns;
  final bool unique;

  /// Generates a default index name based on the table name.
  String generateName(String tableName) {
    final prefix = unique ? 'uidx' : 'idx';
    return name.isNotEmpty
        ? name
        : '${prefix}_${tableName}_${columns.join('_')}';
  }
}
