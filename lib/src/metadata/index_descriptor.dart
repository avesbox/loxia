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
}
