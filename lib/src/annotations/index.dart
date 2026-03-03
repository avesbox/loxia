/// Defines a composite index across multiple columns.
///
/// Use this annotation in the `indexes` parameter of [EntityMeta]
/// to create an index spanning multiple columns.
///
/// Example:
/// ```dart
/// @EntityMeta(
///   table: 'orders',
///   indexes: [
///     Index(columns: ['customer_id', 'created_at']),
///     Index(columns: ['status'], unique: true, name: 'idx_orders_status'),
///   ],
/// )
/// class Order extends Entity {
///   // ...
/// }
/// ```
class Index {
  /// The list of column names that form the index.
  ///
  /// Column names should match the database column names (snake_case),
  /// not the Dart property names.
  final List<String> columns;

  /// Optional index name. If not provided, one will be auto-generated
  /// based on the table and column names.
  final String? name;

  /// Whether the index enforces uniqueness.
  final bool unique;

  const Index({required this.columns, this.name, this.unique = false});
}
