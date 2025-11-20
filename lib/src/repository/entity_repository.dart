import 'package:loxia/src/repository/dtos.dart';

import '../entity.dart';
import '../metadata/entity_descriptor.dart';
import '../datasource/engine_adapter.dart';
import 'query.dart';

class EntityRepository<T extends Entity> {
  EntityRepository(this._descriptor, this._engine, this._fieldsContext);

  final EntityDescriptor<T> _descriptor;
  final EngineAdapter _engine;
  final QueryFieldsContext<T> _fieldsContext;

  Future<List<T>> find({
    QueryBuilder<T>? where,
    List<String>? select,
    List<OrderBy>? orderBy,
    int? limit,
    int? offset,
  }) async {
    final alias = 't';
    final fields = select ?? _descriptor.columns.map((c) => c.name).toList();
    final cols = fields.map((f) => '"$alias"."$f"').join(', ');
    final params = <Object?>[];
    final whereSql = where?.toSql(_fieldsContext, alias, params);
    final limitSql = limit != null ? ' LIMIT $limit' : '';
    final offsetSql = offset != null ? ' OFFSET $offset' : '';
    final orderBySql = orderBy == null || orderBy.isEmpty
        ? ''
        : ' ORDER BY ${orderBy
            .map((o) => '"$alias"."${o.field}" ${o.ascending ? 'ASC' : 'DESC'}')
            .join(', ')}';
    final sql = 'SELECT $cols FROM ${_descriptor.tableName} AS "$alias"${whereSql != null ? ' WHERE $whereSql' : ''}$orderBySql$limitSql$offsetSql';
    final rows = await _engine.query(sql, params);
    return rows.map((r) => _descriptor.fromMap(r)).toList();
  }

  Future<T?> findOne({
    QueryBuilder<T>? where,
    List<String>? select,
    List<OrderBy>? orderBy,
    int? offset,
  }) async {
    final results = await find(
      where: where,
      select: select,
      orderBy: orderBy,
      limit: 1,
      offset: offset,
    );
    return results.firstOrNull;
  }

  Future<List<T>> findBy({
    QueryBuilder<T>? where,
    List<OrderBy>? orderBy,
    int? offset,
    int? limit,
  }) {
    return find(
      where: where,
      orderBy: orderBy,
      offset: offset,
      limit: limit,
    );
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
    final whereSql = where.toSql(_fieldsContext, 't', params);
    final sql = 'UPDATE ${_descriptor.tableName} AS "t" SET ${sets.join(', ')} WHERE $whereSql';
    return _engine.execute(sql, params);
  }

  Future<int> delete(QueryBuilder<T> where) async {
    final params = <Object?>[];
    final whereSql = where.toSql(_fieldsContext, 't', params);
    final sql = 'DELETE FROM ${_descriptor.tableName} AS "t" WHERE $whereSql';
    return _engine.execute(sql, params);
  }
}