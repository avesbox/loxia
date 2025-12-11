import 'package:loxia/src/repository/dtos.dart';

import '../entity.dart';
import '../metadata/entity_descriptor.dart';
import '../datasource/engine_adapter.dart';
import 'query.dart';

class EntityRepository<T extends Entity, P extends PartialEntity<T>> {
  EntityRepository(this._descriptor, this._engine, this._fieldsContext);

  final EntityDescriptor<T, P> _descriptor;
  final EngineAdapter _engine;
  final QueryFieldsContext<T> _fieldsContext;

  /// Executes a query and returns partial entities based on the [select] options.
  /// 
  /// Use this method when you only need specific columns. The returned [P] partial
  /// entities have all fields nullable since not all columns may be selected.
  /// 
  /// To get full entities with type safety, use [findBy] instead.
  Future<List<P>> find({
    required SelectOptions<T, P> select,
    QueryBuilder<T>? where,
    List<OrderBy>? orderBy,
    int? limit,
    int? offset,
  }) async {
    final alias = 't';
    final runtime = QueryRuntimeContext(rootAlias: alias);
    final boundContext = _fieldsContext.bind(runtime, alias);
    final projection = select.compile(boundContext);
    final cols = projection.sql;
    final params = <Object?>[];
    final whereSql = where?.toSql(boundContext, params);
    final limitSql = limit != null ? ' LIMIT $limit' : '';
    final offsetSql = offset != null ? ' OFFSET $offset' : '';
    final orderBySql = orderBy == null || orderBy.isEmpty
        ? ''
        : ' ORDER BY ${orderBy
            .map((o) => '"$alias"."${o.field}" ${o.ascending ? 'ASC' : 'DESC'}')
            .join(', ')}';
    final joinsSql = runtime.joins.map(_renderJoinClause).join(' ');
    final sql = 'SELECT $cols FROM ${_renderTableReference(_descriptor.qualifiedTableName)} AS "$alias"'
        '${joinsSql.isEmpty ? '' : ' $joinsSql'}'
        '${whereSql != null ? ' WHERE $whereSql' : ''}'
        '$orderBySql$limitSql$offsetSql';
    final rows = await _engine.query(sql, params);
    // Use aggregator if available (for collection relations), otherwise map each row
    final aggregator = projection.aggregator;
    if (aggregator != null) {
      return aggregator(rows);
    }
    return rows.map(projection.mapper).toList();
  }

  /// Executes a query and returns a single partial entity, or null if not found.
  Future<P?> findOne({
    required SelectOptions<T, P> select,
    QueryBuilder<T>? where,
    List<OrderBy>? orderBy,
    int? offset,
  }) async {
    final results = await find(
      select: select,
      where: where,
      orderBy: orderBy,
      limit: 1,
      offset: offset,
    );
    return results.firstOrNull;
  }

  /// Executes a query and returns full entities.
  /// 
  /// This method always selects all columns and returns fully hydrated [T] entities.
  /// Use this when you need the complete entity with all fields.
  Future<List<T>> findBy({
    QueryBuilder<T>? where,
    List<OrderBy>? orderBy,
    int? offset,
    int? limit,
  }) async {
    final alias = 't';
    final runtime = QueryRuntimeContext(rootAlias: alias);
    final boundContext = _fieldsContext.bind(runtime, alias);
    final cols = _descriptor.columns.map((c) => '"$alias"."${c.name}"').join(', ');
    final params = <Object?>[];
    final whereSql = where?.toSql(boundContext, params);
    final limitSql = limit != null ? ' LIMIT $limit' : '';
    final offsetSql = offset != null ? ' OFFSET $offset' : '';
    final orderBySql = orderBy == null || orderBy.isEmpty
        ? ''
        : ' ORDER BY ${orderBy
            .map((o) => '"$alias"."${o.field}" ${o.ascending ? 'ASC' : 'DESC'}')
            .join(', ')}';
    final joinsSql = runtime.joins.map(_renderJoinClause).join(' ');
    final sql = 'SELECT $cols FROM ${_renderTableReference(_descriptor.qualifiedTableName)} AS "$alias"'
        '${joinsSql.isEmpty ? '' : ' $joinsSql'}'
        '${whereSql != null ? ' WHERE $whereSql' : ''}'
        '$orderBySql$limitSql$offsetSql';
    final rows = await _engine.query(sql, params);
    return rows.map(_descriptor.fromRow).toList();
  }

  /// Returns a single full entity, or null if not found.
  Future<T?> findOneBy({
    QueryBuilder<T>? where,
    List<OrderBy>? orderBy,
    int? offset,
  }) async {
    final results = await findBy(
      where: where,
      orderBy: orderBy,
      limit: 1,
      offset: offset,
    );
    return results.firstOrNull;
  }

  Future<int> insert(InsertDto<T> values) async {
    final map = values.toMap();
    final cols = map.keys.map((k) => '"$k"').join(', ');
    final placeholders = List.filled(map.length, '?').join(', ');
    final sql = 'INSERT INTO ${_descriptor.tableName} ($cols) VALUES ($placeholders)';
    final affected = await _engine.execute(sql, map.values.toList());
    return affected;
  }

  Future<int> update(
    UpdateDto<T> values,
    QueryBuilder<T> where,
  ) async {
    final sets = <String>[];
    final params = <Object?>[];
    final map = values.toMap();
    for (final entry in map.entries) {
      sets.add('"${entry.key}" = ?');
      params.add(entry.value);
    }
    final runtime = QueryRuntimeContext(rootAlias: 't');
    final boundContext = _fieldsContext.bind(runtime, 't');
    final whereSql = where.toSql(boundContext, params);
    if (runtime.joins.isNotEmpty) {
      throw UnsupportedError('Relation filters are not yet supported for update queries.');
    }
    final sql = 'UPDATE ${_descriptor.tableName} AS "t" SET ${sets.join(', ')} WHERE $whereSql';
    return _engine.execute(sql, params);
  }

  Future<int> delete(QueryBuilder<T> where) async {
    final params = <Object?>[];
    final runtime = QueryRuntimeContext(rootAlias: 't');
    final boundContext = _fieldsContext.bind(runtime, 't');
    final whereSql = where.toSql(boundContext, params);
    if (runtime.joins.isNotEmpty) {
      throw UnsupportedError('Relation filters are not yet supported for delete queries.');
    }
    final sql = 'DELETE FROM ${_descriptor.tableName} AS "t" WHERE $whereSql';
    return _engine.execute(sql, params);
  }

  String _renderJoinClause(RelationJoinSpec spec) {
    final joinKeyword = spec.joinType == JoinType.left ? 'LEFT JOIN' : 'INNER JOIN';
    final tableRef = _renderTableReference(spec.tableName);
    final left = '"${spec.alias}"."${spec.foreignColumn}"';
    final right = '"${spec.localAlias}"."${spec.localColumn}"';
    return '$joinKeyword $tableRef AS "${spec.alias}" ON $left = $right';
  }

  String _renderTableReference(String name) =>
      name.split('.').map((part) => '"$part"').join('.');
}