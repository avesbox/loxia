/// Defines a composite unique constraint across multiple columns.
///
/// Use this annotation in the `uniqueConstraints` parameter of [EntityMeta]
/// to enforce uniqueness across a combination of columns.
///
/// Example:
/// ```dart
/// @EntityMeta(
///   table: 'watchlist_items',
///   uniqueConstraints: [
///     UniqueConstraint(columns: ['user_id', 'movie_id']),
///   ],
/// )
/// class WatchlistItem extends Entity {
///   // ...
/// }
/// ```
class UniqueConstraint {
  /// The list of column names that together form the unique constraint.
  ///
  /// Column names should match the database column names (snake_case),
  /// not the Dart property names.
  final List<String> columns;

  /// Optional constraint name. If not provided, one will be auto-generated.
  final String? name;

  const UniqueConstraint({required this.columns, this.name});
}
