import 'package:loxia/src/annotations/lifecycle.dart';
import 'package:loxia/src/annotations/unique_constraint.dart';

/// Marks a class as a Loxia entity and optionally overrides table metadata.
class EntityMeta {
  /// Custom table name. Defaults to the class name converted to snake case.
  final String? table;

  /// Database schema or namespace.
  final String? schema;

  /// If true, null values are omitted from the JSON representation of this entity.
  final bool omitNullJsonFields;

  final List<Query> queries;

  /// Composite unique constraints for this entity.
  ///
  /// Use this to define uniqueness across multiple columns, similar to
  /// Prisma's `@@unique([column1, column2])`.
  ///
  /// Example:
  /// ```dart
  /// @EntityMeta(
  ///   table: 'watchlist_items',
  ///   uniqueConstraints: [
  ///     UniqueConstraint(columns: ['user_id', 'movie_id']),
  ///   ],
  /// )
  /// ```
  final List<UniqueConstraint> uniqueConstraints;

  const EntityMeta({
    this.table,
    this.schema,
    this.omitNullJsonFields = true,
    this.queries = const [],
    this.uniqueConstraints = const [],
  });
}

class Query {
  final String name;

  final String sql;

  final List<Lifecycle> lifecycleHooks;

  const Query({
    required this.name,
    required this.sql,
    this.lifecycleHooks = const [],
  });
}
