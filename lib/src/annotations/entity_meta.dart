import 'package:loxia/src/annotations/lifecycle.dart';

/// Marks a class as a Loxia entity and optionally overrides table metadata.
class EntityMeta {
  /// Custom table name. Defaults to the class name converted to snake case.
  final String? table;

  /// Database schema or namespace.
  final String? schema;

  final List<Query> queries;

  const EntityMeta({this.table, this.schema, this.queries = const []});
}

class Query {

  final String name;

  final String sql;

  final bool returnFullEntity;

  final bool singleResult;

  final List<Lifecycle> lifecycleHooks;

  const Query({
    required this.name,
    required this.sql,
    this.returnFullEntity = false,
    this.singleResult = false,
    this.lifecycleHooks = const [],
  });

}