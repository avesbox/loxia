import 'dart:async';
import 'dart:convert';

import 'package:loxia/src/repository/dtos.dart';
import 'package:uuid/uuid.dart';

import '../annotations/column.dart';
import '../entity.dart';
import '../metadata/column_descriptor.dart';
import '../metadata/entity_descriptor.dart';
import '../metadata/relation_descriptor.dart';
import '../datasource/engine_adapter.dart';
import 'query.dart';

class EntityRepository<T extends Entity, P extends PartialEntity<T>> {
  EntityRepository(this._descriptor, this._engine, this._fieldsContext)
    : _jsonColumnNames = _descriptor.columns
          .where((column) => column.type == ColumnType.json)
          .map((column) => column.name)
          .toList(growable: false);

  final EntityDescriptor<T, P> _descriptor;
  final EngineAdapter _engine;
  final QueryFieldsContext<T> _fieldsContext;
  final List<String> _jsonColumnNames;
  static final Uuid _uuidGenerator = Uuid();
  static final Expando<Map<String, dynamic>> _entitySnapshots =
      Expando<Map<String, dynamic>>('loxia_entity_snapshots');
  static final Expando<Map<String, dynamic>> _partialSnapshots =
      Expando<Map<String, dynamic>>('loxia_partial_snapshots');

  EntityDescriptor<T, P> get descriptor => _descriptor;
  EngineAdapter get engine => _engine;

  late final String _qualifiedTableName = _renderTableReference(
    _descriptor.qualifiedTableName,
  );

  void _encodeJsonColumns(Map<String, dynamic> map) {
    for (final key in _jsonColumnNames) {
      final value = map[key];
      if (value == null) continue;
      if (value is String) continue;
      map[key] = jsonEncode(value);
    }
  }

  void _encodeJsonColumnsForDescriptor(
    EntityDescriptor descriptor,
    Map<String, dynamic> map,
  ) {
    for (final column in descriptor.columns) {
      if (column.type != ColumnType.json) continue;
      final value = map[column.name];
      if (value == null || value is String) continue;
      map[column.name] = jsonEncode(value);
    }
  }

  /// Executes a query and returns partial entities based on the [select] options.
  ///
  /// Use this method when you only need specific columns. The returned [P] partial
  /// entities have all fields nullable since not all columns may be selected.
  ///
  /// To get full entities with type safety, use [findBy] instead.
  Future<List<P>> find({
    SelectOptions<T, P>? select,
    QueryBuilder<T>? where,
    List<OrderBy>? orderBy,
    int? limit,
    int? offset,
    bool includeDeleted = false,
  }) async {
    final alias = 't';
    final runtime = QueryRuntimeContext(rootAlias: alias);
    final boundContext = _fieldsContext.bind(runtime, alias);
    final effectiveSelect = select ?? _descriptor.defaultSelect?.call();
    if (effectiveSelect == null) {
      throw ArgumentError(
        'select is optional only if defaultSelect is provided in '
        'EntityDescriptor. Otherwise, it must be provided.',
      );
    }
    final projection = effectiveSelect.compile(boundContext);
    final cols = projection.sql;
    final params = <Object?>[];
    final whereSql = _buildSelectWhereSql(
      alias: alias,
      where: where,
      boundContext: boundContext,
      params: params,
      includeDeleted: includeDeleted,
    );
    final limitSql = limit != null ? ' LIMIT $limit' : '';
    final offsetSql = offset != null ? ' OFFSET $offset' : '';
    final orderBySql = orderBy == null || orderBy.isEmpty
        ? ''
        : ' ORDER BY ${orderBy.map((o) => '"$alias"."${o.field}" ${o.ascending ? 'ASC' : 'DESC'}').join(', ')}';
    final joinsSql = runtime.joins.map(_renderJoinClause).join(' ');
    final sql = StringBuffer();
    sql.write('SELECT $cols FROM $_qualifiedTableName AS "$alias"');
    if (joinsSql.isNotEmpty) {
      sql.write(' $joinsSql');
    }
    if (whereSql != null) {
      sql.write(' WHERE $whereSql');
    }
    sql.write(orderBySql);
    sql.write(limitSql);
    sql.write(offsetSql);
    final rows = await _engine.query(sql.toString(), params);
    // Use aggregator if available (for collection relations), otherwise map each row
    final aggregator = projection.aggregator;
    if (aggregator != null) {
      return aggregator(rows);
    }
    final items = rows.map(projection.mapper).toList();
    _trackPartialSnapshots(items, rows);
    _applyPostLoad(items);
    return items;
  }

  /// Executes a query and returns a single partial entity, or null if not found.
  Future<P?> findOne({
    SelectOptions<T, P>? select,
    QueryBuilder<T>? where,
    List<OrderBy>? orderBy,
    int? offset,
    bool includeDeleted = false,
  }) async {
    final results = await find(
      select: select,
      where: where,
      orderBy: orderBy,
      limit: 1,
      offset: offset,
      includeDeleted: includeDeleted,
    );
    return results.firstOrNull;
  }

  Future<T> save(P entity) async {
    final pk = _descriptor.primaryKey;
    if (pk == null) {
      throw StateError(
        'Cannot save without a primary key on ${_descriptor.tableName}',
      );
    }
    final pkValue = entity.primaryKeyValue;
    if (pkValue == null) {
      final insertDto = entity.toInsertDto();
      final insertedRow = await _insertRowWithEngine(insertDto, engine);
      final insertedEntity = _descriptor.fromRow(insertedRow);
      _trackEntitySnapshot(insertedEntity);
      _applyPostLoad([insertedEntity]);
      return insertedEntity;
    } else {
      final updateDto = entity.toUpdateDto();
      final updateMap = Map<String, dynamic>.from(updateDto.toMap());
      _encodeJsonColumns(updateMap);
      final dirtyMap = _dirtyPartialMap(entity, updateMap);
      if (dirtyMap.isEmpty) {
        return _resolveSavedEntity(entity, pk.name, pkValue);
      }
      final updatedRow = await _updateRowByPkWithEngine(
        _DirtyUpdateDto<T>(dirtyMap),
        pk.name,
        pkValue,
        engine,
      );
      final updatedEntity = _descriptor.fromRow(updatedRow);
      _trackEntitySnapshot(updatedEntity);
      _applyPostLoad([updatedEntity]);
      return updatedEntity;
    }
  }

  /// Executes a paginated query and returns partial entities with metadata.
  ///
  /// Throws [RangeError] if [page] or [pageSize] are less than 1, or if
  /// [maxPageSize] is provided and [pageSize] exceeds it.
  Future<PaginatedResult<P>> paginate({
    SelectOptions<T, P>? select,
    QueryBuilder<T>? where,
    List<OrderBy>? orderBy,
    required int page,
    required int pageSize,
    int? maxPageSize,
    bool includeDeleted = false,
  }) async {
    if (page < 1) {
      throw RangeError.range(page, 1, null, 'page');
    }
    if (pageSize < 1) {
      throw RangeError.range(pageSize, 1, null, 'pageSize');
    }
    if (maxPageSize != null && pageSize > maxPageSize) {
      throw RangeError.range(pageSize, 1, maxPageSize, 'pageSize');
    }
    final resolvedOrderBy = (orderBy == null || orderBy.isEmpty)
        ? _defaultOrderBy()
        : orderBy;
    final offset = (page - 1) * pageSize;
    final results = await Future.wait<dynamic>([
      count(select: select, where: where, includeDeleted: includeDeleted),
      find(
        select: select,
        where: where,
        orderBy: resolvedOrderBy,
        limit: pageSize,
        offset: offset,
        includeDeleted: includeDeleted,
      ),
    ]);
    final total = results[0] as int;
    final items = results[1] as List<P>;
    final pageCount = total == 0 ? 0 : ((total + pageSize - 1) ~/ pageSize);
    return PaginatedResult<P>(
      items: items,
      total: total,
      page: page,
      pageSize: pageSize,
      pageCount: pageCount,
    );
  }

  /// Executes a query and returns full entities.
  ///
  /// This method always selects all columns and returns fully hydrated [T] entities.
  /// Use this when you need the complete entity with all fields.
  ///
  /// If [relations] is provided, this method delegates to [find] using the
  /// entity default select with the supplied relations injected, then converts
  /// each partial entity to [T] via [PartialEntity.toEntity].
  Future<List<T>> findBy({
    QueryBuilder<T>? where,
    List<OrderBy>? orderBy,
    int? offset,
    int? limit,
    RelationsOptions<T, P>? relations,
    bool includeDeleted = false,
  }) async {
    if (relations != null) {
      final defaultSelectFactory = _descriptor.defaultSelect;
      if (defaultSelectFactory == null) {
        throw StateError(
          'findBy(relations: ...) requires a defaultSelect for '
          '${_descriptor.tableName}',
        );
      }
      final selectWithRelations = defaultSelectFactory().withRelations(
        relations,
      );
      final partialItems = await find(
        select: selectWithRelations,
        where: where,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
        includeDeleted: includeDeleted,
      );
      final items = partialItems.map((partial) => partial.toEntity()).toList();
      _applyPostLoad(items);
      return items;
    }

    final alias = 't';
    final runtime = QueryRuntimeContext(rootAlias: alias);
    final boundContext = _fieldsContext.bind(runtime, alias);
    final cols = _descriptor.columns
        .map((c) => '"$alias"."${c.name}"')
        .join(', ');
    final params = <Object?>[];
    final whereSql = _buildSelectWhereSql(
      alias: alias,
      where: where,
      boundContext: boundContext,
      params: params,
      includeDeleted: includeDeleted,
    );
    final limitSql = limit != null ? ' LIMIT $limit' : '';
    final offsetSql = offset != null ? ' OFFSET $offset' : '';
    final orderBySql = orderBy == null || orderBy.isEmpty
        ? ''
        : ' ORDER BY ${orderBy.map((o) => '"$alias"."${o.field}" ${o.ascending ? 'ASC' : 'DESC'}').join(', ')}';
    final joinsSql = runtime.joins.map(_renderJoinClause).join(' ');
    final sql = StringBuffer();
    sql.write('SELECT $cols FROM $_qualifiedTableName AS "$alias"');
    if (joinsSql.isNotEmpty) {
      sql.write(' $joinsSql');
    }
    if (whereSql != null) {
      sql.write(' WHERE $whereSql');
    }
    sql.write(orderBySql);
    sql.write(limitSql);
    sql.write(offsetSql);
    final rows = await _engine.query(sql.toString(), params);
    final items = rows.map(_descriptor.fromRow).toList();
    _trackEntitySnapshots(items);
    _applyPostLoad(items);
    return items;
  }

  /// Returns a single full entity, or null if not found.
  Future<T?> findOneBy({
    QueryBuilder<T>? where,
    List<OrderBy>? orderBy,
    int? offset,
    RelationsOptions<T, P>? relations,
    bool includeDeleted = false,
  }) async {
    final results = await findBy(
      where: where,
      orderBy: orderBy,
      limit: 1,
      offset: offset,
      relations: relations,
      includeDeleted: includeDeleted,
    );
    return results.firstOrNull;
  }

  Future<Object?> insert(InsertDto<T> values) async {
    return _insertWithEngine(values, _engine);
  }

  Future<T> insertEntity(T entity) async {
    _descriptor.hooks?.prePersist?.call(entity);
    final map = Map<String, dynamic>.from(_descriptor.toRow(entity));
    final pk = _descriptor.primaryKey;
    if (pk == null) {
      throw StateError(
        'Cannot insert without a primary key on ${_descriptor.tableName}',
      );
    }
    final pkValue = map[pk.name];
    if (pkValue == null) {
      map.remove(pk.name);
    }
    _encodeJsonColumns(map);
    final cols = map.keys.map((k) => '"$k"').join(', ');
    final params = map.values.toList(growable: false);
    final placeholders = _placeholderList(
      engine,
      startAt: 1,
      count: params.length,
    );
    final sql =
        'INSERT INTO ${_descriptor.tableName} ($cols) VALUES ($placeholders) RETURNING *';
    final result = await engine.query(sql, params);
    if (result.isEmpty) {
      throw StateError(
        'Insert did not return a row for ${_descriptor.tableName}',
      );
    }
    final inserted = _descriptor.fromRow(result.first);
    _trackEntitySnapshot(inserted);
    if (pkValue == null) {
      final newId = result.first[pk.name];
      _trySetPrimaryKey(entity, pk.propertyName, newId);
    }
    _descriptor.hooks?.postPersist?.call(inserted);
    return inserted;
  }

  Future<T> updateEntity(T entity) async {
    _descriptor.hooks?.preUpdate?.call(entity);
    final map = Map<String, dynamic>.from(_descriptor.toRow(entity));
    final pk = _descriptor.primaryKey;
    if (pk == null) {
      throw StateError(
        'Cannot update without a primary key on ${_descriptor.tableName}',
      );
    }
    final pkValue = map[pk.name];
    if (pkValue == null) {
      throw StateError(
        'Cannot update without primary key value for ${_descriptor.tableName}',
      );
    }
    map.remove(pk.name);
    _encodeJsonColumns(map);
    final dirtyMap = _dirtyEntityMap(entity, map);
    if (dirtyMap.isEmpty) {
      await _cascadeMergeEntityRelations(entity, pkValue, engine);
      _descriptor.hooks?.postUpdate?.call(entity);
      return entity;
    }
    final sets = <String>[];
    final params = <Object?>[];
    for (final entry in dirtyMap.entries) {
      params.add(entry.value);
      sets.add('"${entry.key}" = ${engine.placeholderFor(params.length)}');
    }
    params.add(pkValue);
    final pkPlaceholder = engine.placeholderFor(params.length);
    final sql =
        'UPDATE ${_descriptor.tableName} SET ${sets.join(', ')} WHERE "${pk.name}" = $pkPlaceholder';
    await engine.execute(sql, params);
    // Cascade merge: update related entities if they are present
    await _cascadeMergeEntityRelations(entity, pkValue, engine);
    _trackEntitySnapshot(entity);
    _descriptor.hooks?.postUpdate?.call(entity);
    return entity;
  }

  Future<int> count({
    SelectOptions<T, P>? select,
    QueryBuilder<T>? where,
    bool includeDeleted = false,
  }) async {
    final alias = 't';
    final runtime = QueryRuntimeContext(rootAlias: alias);
    final boundContext = _fieldsContext.bind(runtime, alias);
    final fields = <SelectField>[];
    if (select != null) {
      select.collect(boundContext, fields, path: null);
    }
    final params = <Object?>[];
    final whereSql = _buildSelectWhereSql(
      alias: alias,
      where: where,
      boundContext: boundContext,
      params: params,
      includeDeleted: includeDeleted,
    );
    final joinsSql = runtime.joins.map(_renderJoinClause).join(' ');
    final countTarget = _buildCountTarget(select, alias, fields);
    final sql = StringBuffer();
    sql.write('SELECT $countTarget AS c FROM $_qualifiedTableName AS "$alias"');
    if (joinsSql.isNotEmpty) {
      sql.write(' $joinsSql');
    }
    if (whereSql != null) {
      sql.write(' WHERE $whereSql');
    }
    final rows = await _engine.query(sql.toString(), params);
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<int> update(
    UpdateDto<T> values, {
    required QueryBuilder<T> where,
  }) async {
    return _updateWithCascade(values, where, _engine);
  }

  Future<int> _updateWithCascade(
    UpdateDto<T> values,
    QueryBuilder<T> where,
    EngineAdapter engine,
  ) async {
    final sets = <String>[];
    final params = <Object?>[];
    final map = values.toMap();
    _encodeJsonColumns(map);
    for (final entry in map.entries) {
      params.add(entry.value);
      sets.add('"${entry.key}" = ${engine.placeholderFor(params.length)}');
    }
    final runtime = QueryRuntimeContext(rootAlias: 't');
    final boundContext = _fieldsContext.bind(runtime, 't');
    final whereSql = where.toSql(
      boundContext,
      params,
      placeholderForIndex: engine.placeholderFor,
    );
    if (runtime.joins.isNotEmpty) {
      throw UnsupportedError(
        'Relation filters are not yet supported for update queries.',
      );
    }

    var updated = 0;
    if (sets.isNotEmpty) {
      final sql =
          'UPDATE ${_descriptor.tableName} AS "t" SET ${sets.join(', ')} WHERE $whereSql';
      updated = await engine.execute(sql, params);
    }

    // Handle cascade updates
    final cascades = _readUpdateCascades(values);
    if (cascades.isNotEmpty) {
      await _applyCascadeUpdates(cascades, where, engine);
    }

    return updated;
  }

  Future<void> _applyCascadeUpdates(
    Map<String, dynamic> cascades,
    QueryBuilder<T> parentWhere,
    EngineAdapter engine,
  ) async {
    for (final relation in _descriptor.relations) {
      if (!relation.shouldCascadeMerge) continue;

      final cascadeDto = cascades[relation.fieldName];
      if (cascadeDto == null) continue;

      if (relation.type == RelationType.manyToMany) {
        // ManyToMany cascade update: sync the collection
        await _cascadeUpdateManyToMany(
          relation,
          cascadeDto,
          parentWhere,
          engine,
        );
        continue;
      }

      final targetDescriptor = EntityDescriptor.lookup(relation.target);
      if (targetDescriptor == null) {
        throw StateError('Missing EntityDescriptor for ${relation.target}');
      }
      final targetPk = targetDescriptor.primaryKey;
      if (targetPk == null) {
        throw StateError('Target entity ${relation.target} has no primary key');
      }

      if (relation.isOwningSide) {
        // Owning side (many-to-one, one-to-one owning): update by FK
        // We need to get the FK values from the parent entities matching the where clause
        await _cascadeUpdateOwning(relation, cascadeDto, parentWhere, engine);
      } else {
        // Inverse side (one-to-many, one-to-one mappedBy): update children by their PKs
        await _cascadeUpdateInverse(relation, cascadeDto, parentWhere, engine);
      }
    }
  }

  Future<void> _cascadeUpdateOwning(
    RelationDescriptor relation,
    dynamic cascadeDto,
    QueryBuilder<T> parentWhere,
    EngineAdapter engine,
  ) async {
    if (cascadeDto is! UpdateDto) {
      throw StateError(
        'Cascade value for ${relation.fieldName} must be an UpdateDto.',
      );
    }

    final joinColumn = relation.joinColumn;
    if (joinColumn == null) {
      throw StateError(
        'Owning relation ${relation.fieldName} is missing joinColumn metadata.',
      );
    }

    // Get the FK values from parents matching the where clause
    final pk = _descriptor.primaryKey;
    if (pk == null) return;

    final alias = 't';
    final runtime = QueryRuntimeContext(rootAlias: alias);
    final boundContext = _fieldsContext.bind(runtime, alias);
    final params = <Object?>[];
    final whereSql = parentWhere.toSql(boundContext, params);
    final selectSql =
        'SELECT DISTINCT "$alias"."${joinColumn.name}" FROM ${_renderTableReference(_descriptor.qualifiedTableName)} AS "$alias" WHERE $whereSql';
    final rows = await engine.query(selectSql, params);

    if (rows.isEmpty) return;

    final fkValues = rows
        .map((r) => r[joinColumn.name])
        .where((v) => v != null)
        .toList();
    if (fkValues.isEmpty) return;

    // Update the target entities
    final targetDescriptor = EntityDescriptor.lookup(relation.target);
    if (targetDescriptor == null) return;
    final targetPk = targetDescriptor.primaryKey;
    if (targetPk == null) return;

    final updateMap = cascadeDto.toMap();
    if (updateMap.isEmpty) return;

    final sets = <String>[];
    final updateParams = <Object?>[];
    for (final entry in updateMap.entries) {
      sets.add('"${entry.key}" = ?');
      updateParams.add(entry.value);
    }
    updateParams.addAll(fkValues);

    final placeholders = List.filled(fkValues.length, '?').join(', ');
    final targetTable = _renderTableReference(
      targetDescriptor.qualifiedTableName,
    );
    final updateSql =
        'UPDATE $targetTable SET ${sets.join(', ')} WHERE "${targetPk.name}" IN ($placeholders)';
    await engine.execute(updateSql, updateParams);
  }

  Future<void> _cascadeUpdateInverse(
    RelationDescriptor relation,
    dynamic cascadeDto,
    QueryBuilder<T> parentWhere,
    EngineAdapter engine,
  ) async {
    final targetDescriptor = EntityDescriptor.lookup(relation.target);
    if (targetDescriptor == null) {
      throw StateError('Missing EntityDescriptor for ${relation.target}');
    }

    final mappedBy = relation.mappedBy;
    if (mappedBy == null || mappedBy.isEmpty) {
      throw StateError(
        'Inverse relation ${relation.fieldName} must define mappedBy.',
      );
    }

    // Find the owning relation on the target entity
    final owningRelation = targetDescriptor.relations.firstWhere(
      (r) => r.fieldName == mappedBy,
      orElse: () => throw StateError(
        'Owning relation $mappedBy not found on ${targetDescriptor.tableName}',
      ),
    );
    final joinColumn = owningRelation.joinColumn;
    if (joinColumn == null) {
      throw StateError(
        'Owning relation $mappedBy is missing joinColumn metadata.',
      );
    }

    // Get the parent PKs
    final pk = _descriptor.primaryKey;
    if (pk == null) return;

    final alias = 't';
    final runtime = QueryRuntimeContext(rootAlias: alias);
    final boundContext = _fieldsContext.bind(runtime, alias);
    final params = <Object?>[];
    final whereSql = parentWhere.toSql(boundContext, params);
    final selectSql =
        'SELECT "$alias"."${pk.name}" FROM ${_renderTableReference(_descriptor.qualifiedTableName)} AS "$alias" WHERE $whereSql';
    final parentRows = await engine.query(selectSql, params);

    if (parentRows.isEmpty) return;

    final parentIds = parentRows
        .map((r) => r[pk.name])
        .where((id) => id != null)
        .toList();
    if (parentIds.isEmpty) return;

    // Handle list of UpdateDtos or single UpdateDto
    final dtos = cascadeDto is List ? cascadeDto : [cascadeDto];
    for (final dto in dtos) {
      if (dto is! UpdateDto) continue;

      final updateMap = dto.toMap();
      if (updateMap.isEmpty) continue;

      final sets = <String>[];
      final updateParams = <Object?>[];
      for (final entry in updateMap.entries) {
        sets.add('"${entry.key}" = ?');
        updateParams.add(entry.value);
      }
      updateParams.addAll(parentIds);

      final placeholders = List.filled(parentIds.length, '?').join(', ');
      final targetTable = _renderTableReference(
        targetDescriptor.qualifiedTableName,
      );
      final updateSql =
          'UPDATE $targetTable SET ${sets.join(', ')} WHERE "${joinColumn.name}" IN ($placeholders)';
      await engine.execute(updateSql, updateParams);
    }
  }

  /// Cascade update for ManyToMany relations (DTO-based).
  ///
  /// The cascade DTO for ManyToMany can be:
  /// - A `ManyToManyCascadeUpdate` with `add`, `remove`, and `set` operations
  /// - A list of target IDs to set as the complete collection
  Future<void> _cascadeUpdateManyToMany(
    RelationDescriptor relation,
    dynamic cascadeDto,
    QueryBuilder<T> parentWhere,
    EngineAdapter engine,
  ) async {
    final joinTable = relation.joinTable;
    if (joinTable == null) {
      throw StateError(
        'ManyToMany relation ${relation.fieldName} is missing joinTable metadata.',
      );
    }
    if (joinTable.joinColumns.isEmpty || joinTable.inverseJoinColumns.isEmpty) {
      throw StateError(
        'ManyToMany relation ${relation.fieldName} has incomplete joinTable metadata.',
      );
    }

    final ownerJoinColumn = joinTable.joinColumns.first;
    final targetJoinColumn = joinTable.inverseJoinColumns.first;

    // Get the parent PKs
    final pk = _descriptor.primaryKey;
    if (pk == null) return;

    final alias = 't';
    final runtime = QueryRuntimeContext(rootAlias: alias);
    final boundContext = _fieldsContext.bind(runtime, alias);
    final params = <Object?>[];
    final whereSql = parentWhere.toSql(boundContext, params);
    final selectSql =
        'SELECT "$alias"."${pk.name}" FROM ${_renderTableReference(_descriptor.qualifiedTableName)} AS "$alias" WHERE $whereSql';
    final parentRows = await engine.query(selectSql, params);

    if (parentRows.isEmpty) return;

    final parentIds = parentRows
        .map((r) => r[pk.name])
        .whereType<Object>()
        .toList();
    if (parentIds.isEmpty) return;

    // Check what type of cascade update we're dealing with
    if (cascadeDto is ManyToManyCascadeUpdate) {
      // Structured update with add/remove/set operations
      for (final ownerId in parentIds) {
        await _applyManyToManyCascadeUpdate(
          joinTable.name,
          ownerJoinColumn.name,
          targetJoinColumn.name,
          ownerId,
          cascadeDto,
          engine,
        );
      }
    } else if (cascadeDto is List) {
      // List of target IDs - treat as a "set" operation
      final targetIds = cascadeDto.whereType<Object>().toSet();
      for (final ownerId in parentIds) {
        await _setManyToManyCollection(
          joinTable.name,
          ownerJoinColumn.name,
          targetJoinColumn.name,
          ownerId,
          targetIds,
          engine,
        );
      }
    } else {
      throw StateError(
        'Cascade value for ManyToMany ${relation.fieldName} must be ManyToManyCascadeUpdate or List of IDs',
      );
    }
  }

  Future<void> _applyManyToManyCascadeUpdate(
    String joinTableName,
    String ownerColumn,
    String targetColumn,
    Object ownerId,
    ManyToManyCascadeUpdate update,
    EngineAdapter engine,
  ) async {
    // Handle "set" - replace entire collection
    if (update.set != null) {
      await _setManyToManyCollection(
        joinTableName,
        ownerColumn,
        targetColumn,
        ownerId,
        update.set!.toSet(),
        engine,
      );
      return;
    }

    // Handle "remove"
    if (update.remove != null && update.remove!.isNotEmpty) {
      final placeholders = List.filled(update.remove!.length, '?').join(', ');
      final deleteSql =
          'DELETE FROM $joinTableName WHERE "$ownerColumn" = ? AND "$targetColumn" IN ($placeholders)';
      await engine.execute(deleteSql, [ownerId, ...update.remove!]);
    }

    // Handle "add"
    if (update.add != null && update.add!.isNotEmpty) {
      for (final targetId in update.add!) {
        // Use INSERT OR IGNORE to avoid duplicate key errors
        final insertSql =
            'INSERT INTO $joinTableName ("$ownerColumn", "$targetColumn") VALUES (?, ?) ON CONFLICT DO NOTHING';
        await engine.execute(insertSql, [ownerId, targetId]);
      }
    }
  }

  Future<void> _setManyToManyCollection(
    String joinTableName,
    String ownerColumn,
    String targetColumn,
    Object ownerId,
    Set<Object> targetIds,
    EngineAdapter engine,
  ) async {
    // Get current associations
    final selectSql =
        'SELECT "$targetColumn" FROM $joinTableName WHERE "$ownerColumn" = ?';
    final currentRows = await engine.query(selectSql, [ownerId]);
    final currentIds = currentRows
        .map((r) => r[targetColumn])
        .whereType<Object>()
        .toSet();

    // Determine what to add and remove
    final toRemove = currentIds.difference(targetIds);
    final toAdd = targetIds.difference(currentIds);

    // Delete removed associations
    if (toRemove.isNotEmpty) {
      final placeholders = List.filled(toRemove.length, '?').join(', ');
      final deleteSql =
          'DELETE FROM $joinTableName WHERE "$ownerColumn" = ? AND "$targetColumn" IN ($placeholders)';
      await engine.execute(deleteSql, [ownerId, ...toRemove]);
    }

    // Insert new associations
    for (final targetId in toAdd) {
      final insertSql =
          'INSERT INTO $joinTableName ("$ownerColumn", "$targetColumn") VALUES (?, ?)';
      await engine.execute(insertSql, [ownerId, targetId]);
    }
  }

  Map<String, dynamic> _readUpdateCascades(UpdateDto values) {
    try {
      final dyn = values as dynamic;
      final cascades = dyn.cascades;
      if (cascades is Map) {
        return Map<String, dynamic>.from(cascades);
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  Future<int> delete(QueryBuilder<T> where) async {
    return _engine.transaction((txEngine) async {
      final params = <Object?>[];
      final runtime = QueryRuntimeContext(rootAlias: 't');
      final boundContext = _fieldsContext.bind(runtime, 't');
      final whereSql = where.toSql(
        boundContext,
        params,
        placeholderForIndex: txEngine.placeholderFor,
      );
      if (runtime.joins.isNotEmpty) {
        throw UnsupportedError(
          'Relation filters are not yet supported for delete queries.',
        );
      }
      final sql = 'DELETE FROM ${_descriptor.tableName} AS "t" WHERE $whereSql';
      return txEngine.execute(sql, params);
    });
  }

  Future<int> softDelete(QueryBuilder<T> where) async {
    return _softDeleteWithCascade(where, _engine);
  }

  Future<void> softDeleteEntities(Iterable<T> entities) async {
    for (final entity in entities) {
      await _softDeleteEntityWithEngine(entity, _engine);
    }
  }

  Future<int> _softDeleteWithCascade(
    QueryBuilder<T> where,
    EngineAdapter engine,
  ) async {
    final deletedAtColumn = _deletedAtColumnOrThrow();
    final deletedAtValue = _nowForDeletedAt();

    final params = <Object?>[];
    final runtime = QueryRuntimeContext(rootAlias: 't');
    final boundContext = _fieldsContext.bind(runtime, 't');
    final whereSql = where.toSql(boundContext, params);
    if (runtime.joins.isNotEmpty) {
      throw UnsupportedError(
        'Relation filters are not yet supported for soft delete queries.',
      );
    }

    // Cascade soft delete: inverse-side relations first (children before parent)
    for (final relation in _descriptor.relations) {
      if (!relation.shouldCascadeRemove) continue;
      if (relation.type == RelationType.manyToMany) continue;
      if (relation.isOwningSide) continue;

      final targetDescriptor = EntityDescriptor.lookup(relation.target);
      if (targetDescriptor == null) continue;

      final targetDeletedAtColumn = _deletedAtColumnFor(targetDescriptor);
      if (targetDeletedAtColumn == null) continue;

      final mappedBy = relation.mappedBy;
      if (mappedBy == null || mappedBy.isEmpty) continue;

      final owningRelation = targetDescriptor.relations.firstWhere(
        (r) => r.fieldName == mappedBy,
        orElse: () => throw StateError(
          'Owning relation $mappedBy not found on ${targetDescriptor.tableName}',
        ),
      );
      final joinColumn = owningRelation.joinColumn;
      if (joinColumn == null) continue;

      final pk = _descriptor.primaryKey;
      if (pk == null) {
        throw StateError(
          'Cannot cascade soft delete without primary key on ${_descriptor.tableName}',
        );
      }

      final selectAlias = 't';
      final selectRuntime = QueryRuntimeContext(rootAlias: selectAlias);
      final selectBoundContext = _fieldsContext.bind(
        selectRuntime,
        selectAlias,
      );
      final selectParams = <Object?>[];
      final selectWhereSql = where.toSql(selectBoundContext, selectParams);
      final selectSql =
          'SELECT "$selectAlias"."${pk.name}" FROM ${_renderTableReference(_descriptor.qualifiedTableName)} AS "$selectAlias" WHERE $selectWhereSql';
      final parentRows = await engine.query(selectSql, selectParams);
      final parentIds = parentRows
          .map((r) => r[pk.name])
          .where((id) => id != null)
          .toList();
      if (parentIds.isEmpty) continue;

      final placeholders = List.filled(parentIds.length, '?').join(', ');
      final targetTable = _renderTableReference(
        targetDescriptor.qualifiedTableName,
      );
      final childUpdateSql =
          'UPDATE $targetTable SET "${targetDeletedAtColumn.name}" = ? WHERE "${joinColumn.name}" IN ($placeholders)';
      await engine.execute(childUpdateSql, [deletedAtValue, ...parentIds]);
    }

    // Collect FK values for owning-side cascade soft deletes BEFORE parent update
    final owningCascadeTargets = <RelationDescriptor, List<Object>>{};
    for (final relation in _descriptor.relations) {
      if (!relation.shouldCascadeRemove) continue;
      if (!relation.isOwningSide) continue;
      if (relation.type == RelationType.manyToMany) continue;

      final targetDescriptor = EntityDescriptor.lookup(relation.target);
      if (targetDescriptor == null) continue;
      final targetDeletedAtColumn = _deletedAtColumnFor(targetDescriptor);
      if (targetDeletedAtColumn == null) continue;

      final joinColumn = relation.joinColumn;
      if (joinColumn == null) continue;

      final alias = 't';
      final selectRuntime = QueryRuntimeContext(rootAlias: alias);
      final selectBoundContext = _fieldsContext.bind(selectRuntime, alias);
      final selectParams = <Object?>[];
      final selectWhereSql = where.toSql(selectBoundContext, selectParams);
      final selectSql =
          'SELECT DISTINCT "$alias"."${joinColumn.name}" FROM ${_renderTableReference(_descriptor.qualifiedTableName)} AS "$alias" WHERE $selectWhereSql';
      final rows = await engine.query(selectSql, selectParams);

      final fkValues = rows
          .map((r) => r[joinColumn.name])
          .where((v) => v != null)
          .cast<Object>()
          .toList();
      if (fkValues.isNotEmpty) {
        owningCascadeTargets[relation] = fkValues;
      }
    }

    final sql =
        'UPDATE ${_descriptor.tableName} AS "t" SET "${deletedAtColumn.name}" = ? WHERE $whereSql';
    final deleted = await engine.execute(sql, [deletedAtValue, ...params]);

    // Cascade soft delete: owning-side relations after parent update
    for (final entry in owningCascadeTargets.entries) {
      final relation = entry.key;
      final fkValues = entry.value;

      final targetDescriptor = EntityDescriptor.lookup(relation.target);
      if (targetDescriptor == null) continue;
      final targetPk = targetDescriptor.primaryKey;
      if (targetPk == null) continue;
      final targetDeletedAtColumn = _deletedAtColumnFor(targetDescriptor);
      if (targetDeletedAtColumn == null) continue;

      final placeholders = List.filled(fkValues.length, '?').join(', ');
      final targetTable = _renderTableReference(
        targetDescriptor.qualifiedTableName,
      );
      final updateSql =
          'UPDATE $targetTable SET "${targetDeletedAtColumn.name}" = ? WHERE "${targetPk.name}" IN ($placeholders)';
      await engine.execute(updateSql, [deletedAtValue, ...fkValues]);
    }

    return deleted;
  }

  Future<void> deleteEntity(T entity) async {
    await _engine.transaction((txEngine) async {
      _descriptor.hooks?.preRemove?.call(entity);
      final pk = _descriptor.primaryKey;
      if (pk == null) {
        throw StateError(
          'Cannot delete without a primary key on ${_descriptor.tableName}',
        );
      }
      final map = _descriptor.toRow(entity);
      final pkValue = map[pk.name];
      if (pkValue == null) {
        throw StateError(
          'Cannot delete without primary key value for ${_descriptor.tableName}',
        );
      }

      final sql =
          'DELETE FROM ${_descriptor.tableName} WHERE "${pk.name}" = ${txEngine.placeholderFor(1)}';
      await txEngine.execute(sql, [pkValue]);

      _descriptor.hooks?.postRemove?.call(entity);
    });
  }

  Future<void> softDeleteEntity(T entity) async {
    _softDeleteEntityWithEngine(entity, engine);
  }

  Future<void> _softDeleteEntityWithEngine(
    T entity,
    EngineAdapter engine,
  ) async {
    final deletedAtColumn = _deletedAtColumnOrThrow();
    final deletedAtValue = _nowForDeletedAt();

    _descriptor.hooks?.preRemove?.call(entity);
    final pk = _descriptor.primaryKey;
    if (pk == null) {
      throw StateError(
        'Cannot soft delete without a primary key on ${_descriptor.tableName}',
      );
    }
    final map = _descriptor.toRow(entity);
    final pkValue = map[pk.name];
    if (pkValue == null) {
      throw StateError(
        'Cannot soft delete without primary key value for ${_descriptor.tableName}',
      );
    }

    // Cascade soft delete: inverse-side relations first (children before parent)
    await _cascadeSoftDeleteEntityInverseRelations(entity, pkValue, engine);

    // Collect FK values for owning-side cascade BEFORE updating the parent
    final owningCascadeTargets = _collectOwningCascadeTargets(entity);

    // Soft delete the parent entity
    final sql =
        'UPDATE ${_descriptor.tableName} SET "${deletedAtColumn.name}" = ${engine.placeholderFor(1)} WHERE "${pk.name}" = ${engine.placeholderFor(2)}';
    await engine.execute(sql, [deletedAtValue, pkValue]);

    // Cascade soft delete: owning-side relations AFTER parent is updated
    await _cascadeSoftDeleteEntityOwningRelations(owningCascadeTargets, engine);

    _descriptor.hooks?.postRemove?.call(entity);
  }

  Future<void> _cascadeSoftDeleteEntityInverseRelations(
    T entity,
    Object pkValue,
    EngineAdapter engine,
  ) async {
    for (final relation in _descriptor.relations) {
      if (!relation.shouldCascadeRemove) continue;
      if (relation.type == RelationType.manyToMany) continue;
      if (relation.isOwningSide) continue;

      final targetDescriptor = EntityDescriptor.lookup(relation.target);
      if (targetDescriptor == null) continue;
      final targetDeletedAtColumn = _deletedAtColumnFor(targetDescriptor);
      if (targetDeletedAtColumn == null) continue;

      final mappedBy = relation.mappedBy;
      if (mappedBy == null || mappedBy.isEmpty) continue;

      final owningRelation = targetDescriptor.relations.firstWhere(
        (r) => r.fieldName == mappedBy,
        orElse: () => throw StateError(
          'Owning relation $mappedBy not found on ${targetDescriptor.tableName}',
        ),
      );
      final joinColumn = owningRelation.joinColumn;
      if (joinColumn == null) continue;

      final targetTable = _renderTableReference(
        targetDescriptor.qualifiedTableName,
      );
      final updateChildrenSql =
          'UPDATE $targetTable SET "${targetDeletedAtColumn.name}" = ? WHERE "${joinColumn.name}" = ?';
      await engine.execute(updateChildrenSql, [_nowForDeletedAt(), pkValue]);
    }
  }

  Future<void> _cascadeSoftDeleteEntityOwningRelations(
    Map<RelationDescriptor, Object> targets,
    EngineAdapter engine,
  ) async {
    for (final entry in targets.entries) {
      final relation = entry.key;
      final fkValue = entry.value;

      final targetDescriptor = EntityDescriptor.lookup(relation.target);
      if (targetDescriptor == null) continue;
      final targetDeletedAtColumn = _deletedAtColumnFor(targetDescriptor);
      if (targetDeletedAtColumn == null) continue;

      final targetPk = targetDescriptor.primaryKey;
      if (targetPk == null) continue;

      final targetTable = _renderTableReference(
        targetDescriptor.qualifiedTableName,
      );
      final updateSql =
          'UPDATE $targetTable SET "${targetDeletedAtColumn.name}" = ? WHERE "${targetPk.name}" = ?';
      await engine.execute(updateSql, [_nowForDeletedAt(), fkValue]);
    }
  }

  Map<RelationDescriptor, Object> _collectOwningCascadeTargets(T entity) {
    final targets = <RelationDescriptor, Object>{};
    final entityRow = _descriptor.toRow(entity);

    for (final relation in _descriptor.relations) {
      if (!relation.shouldCascadeRemove) continue;
      if (!relation.isOwningSide) continue;
      if (relation.type == RelationType.manyToMany) continue;

      final joinColumn = relation.joinColumn;
      if (joinColumn == null) continue;

      final fkValue = entityRow[joinColumn.name];
      if (fkValue != null) {
        targets[relation] = fkValue;
      }
    }
    return targets;
  }

  Future<void> _cascadeMergeEntityRelations(
    T entity,
    Object pkValue,
    EngineAdapter engine,
  ) async {
    final batchStatements = <String>[];

    for (final relation in _descriptor.relations) {
      if (!relation.shouldCascadeMerge) continue;

      if (relation.type == RelationType.manyToMany) {
        // ManyToMany: sync the join table with the current collection
        if (batchStatements.isNotEmpty) {
          await engine.executeBatch(batchStatements);
          batchStatements.clear();
        }
        await _cascadeMergeEntityManyToMany(entity, pkValue, relation, engine);
        continue;
      }

      // Get the related entity/entities from the parent entity
      final relatedValue = _getRelationValue(entity, relation.fieldName);
      if (relatedValue == null) continue;

      final targetDescriptor = EntityDescriptor.lookup(relation.target);
      if (targetDescriptor == null) continue;

      final targetPk = targetDescriptor.primaryKey;
      if (targetPk == null) continue;

      if (relation.isOwningSide) {
        // Owning side (many-to-one, one-to-one owning): update the related entity
        if (relatedValue is Entity) {
          final relatedRow = targetDescriptor.toRow(relatedValue);
          final relatedPkValue = relatedRow[targetPk.name];
          if (relatedPkValue != null) {
            final statement = _buildRelatedUpdateStatement(
              targetDescriptor,
              relatedValue,
              relatedPkValue,
            );
            if (statement != null) {
              batchStatements.add(statement);
            }
          }
        }
      } else {
        // Inverse side (one-to-many, one-to-one mappedBy): update children
        final entities = relatedValue is List ? relatedValue : [relatedValue];
        for (final child in entities) {
          if (child is! Entity) continue;
          final childRow = targetDescriptor.toRow(child);
          final childPkValue = childRow[targetPk.name];
          if (childPkValue != null) {
            final statement = _buildRelatedUpdateStatement(
              targetDescriptor,
              child,
              childPkValue,
            );
            if (statement != null) {
              batchStatements.add(statement);
            }
          }
        }
      }
    }

    if (batchStatements.isNotEmpty) {
      await engine.executeBatch(batchStatements);
    }
  }

  /// Cascade merge for ManyToMany relations (entity-based).
  ///
  /// This syncs the join table to match the current collection in the entity.
  /// - Deletes join table entries for items no longer in the collection
  /// - Inserts join table entries for new items in the collection
  /// - Updates existing target entities if they have changes
  Future<void> _cascadeMergeEntityManyToMany(
    T entity,
    Object pkValue,
    RelationDescriptor relation,
    EngineAdapter engine,
  ) async {
    final joinTable = relation.joinTable;
    if (joinTable == null) {
      throw StateError(
        'ManyToMany relation ${relation.fieldName} is missing joinTable metadata.',
      );
    }
    if (joinTable.joinColumns.isEmpty || joinTable.inverseJoinColumns.isEmpty) {
      throw StateError(
        'ManyToMany relation ${relation.fieldName} has incomplete joinTable metadata.',
      );
    }

    final targetDescriptor = EntityDescriptor.lookup(relation.target);
    if (targetDescriptor == null) {
      throw StateError('Missing EntityDescriptor for ${relation.target}');
    }
    final targetPk = targetDescriptor.primaryKey;
    if (targetPk == null) {
      throw StateError('Target entity ${relation.target} has no primary key');
    }

    final ownerJoinColumn = joinTable.joinColumns.first;
    final targetJoinColumn = joinTable.inverseJoinColumns.first;

    // Get the current collection from the entity
    final relatedValue = _getRelationValue(entity, relation.fieldName);
    final newCollection = relatedValue is List
        ? relatedValue
        : (relatedValue != null ? [relatedValue] : []);

    // Extract target IDs from the new collection
    final newTargetIds = <int>{};
    final updateStatements = <String>[];
    for (final item in newCollection) {
      if (item is Entity) {
        final row = targetDescriptor.toRow(item);
        final targetId = row[targetPk.name];
        if (targetId is int) {
          newTargetIds.add(targetId);
          // Also update the target entity if cascade merge is enabled
          final statement = _buildRelatedUpdateStatement(
            targetDescriptor,
            item,
            targetId,
          );
          if (statement != null) {
            updateStatements.add(statement);
          }
        }
      }
    }
    if (updateStatements.isNotEmpty) {
      await engine.executeBatch(updateStatements);
    }

    // Get current join table entries
    final selectJoinSql =
        'SELECT "${targetJoinColumn.name}" FROM ${joinTable.name} WHERE "${ownerJoinColumn.name}" = ?';
    final currentRows = await engine.query(selectJoinSql, [pkValue]);
    final currentTargetIds = currentRows
        .map((r) => r[targetJoinColumn.name])
        .whereType<int>()
        .toSet();

    // Determine what to add and what to remove
    final toRemove = currentTargetIds.difference(newTargetIds);
    final toAdd = newTargetIds.difference(currentTargetIds);

    // Delete removed associations
    if (toRemove.isNotEmpty) {
      final placeholders = List.filled(toRemove.length, '?').join(', ');
      final deleteJoinSql =
          'DELETE FROM ${joinTable.name} WHERE "${ownerJoinColumn.name}" = ? AND "${targetJoinColumn.name}" IN ($placeholders)';
      await engine.execute(deleteJoinSql, [pkValue, ...toRemove]);
    }

    // Insert new associations
    for (final targetId in toAdd) {
      final insertJoinSql =
          'INSERT INTO ${joinTable.name} ("${ownerJoinColumn.name}", "${targetJoinColumn.name}") VALUES (?, ?)';
      await engine.execute(insertJoinSql, [pkValue, targetId]);
    }
  }

  Object? _getRelationValue(T entity, String fieldName) {
    final asMap = _entityToMap(entity);
    if (asMap == null) {
      return null;
    }
    return asMap[fieldName];
  }

  Map<String, dynamic>? _entityToMap(dynamic entity) {
    if (entity is Map<String, dynamic>) {
      return entity;
    }
    if (entity is Entity) {
      try {
        return entity.toJson();
      } on UnsupportedError {
        return null;
      }
    }
    try {
      final dynamicEntity = entity as dynamic;
      final map = dynamicEntity.toMap();
      if (map is Map) {
        return Map<String, dynamic>.from(map);
      }
    } on NoSuchMethodError {
      return null;
    }
    return null;
  }

  String? _buildRelatedUpdateStatement(
    EntityDescriptor targetDescriptor,
    Entity entity,
    Object pkValue,
  ) {
    final map = Map<String, dynamic>.from(targetDescriptor.toRow(entity));
    final pk = targetDescriptor.primaryKey;
    if (pk == null) return null;

    map.remove(pk.name);
    _encodeJsonColumnsForDescriptor(targetDescriptor, map);
    if (map.isEmpty) return null;

    final sets = <String>[];
    for (final entry in map.entries) {
      sets.add('"${entry.key}" = ${_toSqlLiteral(entry.value)}');
    }

    final targetTable = _renderTableReference(
      targetDescriptor.qualifiedTableName,
    );
    return 'UPDATE $targetTable SET ${sets.join(', ')} WHERE "${pk.name}" = ${_toSqlLiteral(pkValue)}';
  }

  /// Executes the provided action within a transactional context.
  Future<R> transaction<R>(
    Future<R> Function(EntityRepository<T, P> txRepo) action,
  ) {
    return _engine.transaction((txEngine) async {
      final txRepo = _descriptor.repositoryFactory(txEngine);
      return action(txRepo);
    });
  }

  Future<Object?> _insertWithEngine(
    InsertDto values,
    EngineAdapter engine,
  ) async {
    final insertedRow = await _insertRowWithEngine(values, engine);
    final primaryKey = _descriptor.primaryKey?.name;
    if (primaryKey == null || primaryKey.isEmpty) {
      throw StateError(
        'Cannot insert without a primary key on ${_descriptor.tableName}',
      );
    }
    if (!insertedRow.containsKey(primaryKey)) {
      throw StateError(
        'Insert did not return a primary key for ${_descriptor.tableName}',
      );
    }
    return insertedRow[primaryKey];
  }

  Future<Map<String, dynamic>> _insertRowWithEngine(
    InsertDto values,
    EngineAdapter engine,
  ) async {
    final map = Map<String, dynamic>.from(values.toMap());
    final cascades = _readCascades(values);

    // Pre-insert: owning side (many-to-one / one-to-one owning)
    for (final relation in _descriptor.relations) {
      if (!relation.isOwningSide) continue;
      if (relation.type != RelationType.manyToOne &&
          relation.type != RelationType.oneToOne) {
        continue;
      }
      final cascadeDto = cascades[relation.fieldName];
      if (cascadeDto == null) continue;
      if (relation.joinColumn == null) {
        throw StateError(
          'Owning relation ${relation.fieldName} is missing joinColumn metadata.',
        );
      }
      if (cascadeDto is List) {
        throw StateError(
          'Owning relation ${relation.fieldName} must be a single DTO, not a list.',
        );
      }
      if (cascadeDto is! InsertDto) {
        throw StateError(
          'Cascade value for ${relation.fieldName} must be an InsertDto.',
        );
      }
      final targetRepo = _resolveRepository(relation.target, engine);
      final childId = await targetRepo._insertWithEngine(
        cascadeDto as dynamic,
        engine,
      );
      map[relation.joinColumn!.name] = childId;
    }

    // Main insert
    final primaryKeyDescriptor = _descriptor.primaryKey;
    final primaryKey = primaryKeyDescriptor?.name;
    if (primaryKey == null ||
        primaryKey.isEmpty ||
        primaryKeyDescriptor == null) {
      throw StateError(
        'Cannot insert without a primary key on ${_descriptor.tableName}',
      );
    }
    if (primaryKeyDescriptor.uuid && !map.containsKey(primaryKey)) {
      map[primaryKey] = _generateUuid();
    }
    _encodeJsonColumns(map);
    final cols = map.keys.map((k) => '"$k"').join(', ');
    final params = map.values.toList(growable: false);
    final placeholders = _placeholderList(
      engine,
      startAt: 1,
      count: params.length,
    );
    final sql =
        'INSERT INTO ${_descriptor.tableName} ($cols) VALUES ($placeholders) RETURNING *';
    final result = await engine.query(sql, params);
    if (result.isEmpty || !result.first.containsKey(primaryKey)) {
      throw StateError(
        'Insert did not return a primary key for ${_descriptor.tableName}',
      );
    }
    final insertedRow = result.first;
    final newId = insertedRow[primaryKey];

    // Post-insert: inverse side (one-to-many / one-to-one mappedBy)
    for (final relation in _descriptor.relations) {
      if (relation.isOwningSide) continue;
      if (relation.type != RelationType.oneToMany &&
          relation.type != RelationType.oneToOne) {
        continue;
      }
      final cascadeDto = cascades[relation.fieldName];
      if (cascadeDto == null) continue;
      final targetDescriptor = EntityDescriptor.lookup(relation.target);
      if (targetDescriptor == null) {
        throw StateError('Missing EntityDescriptor for ${relation.target}');
      }
      final mappedBy = relation.mappedBy;
      if (mappedBy == null || mappedBy.isEmpty) {
        throw StateError(
          'Inverse relation ${relation.fieldName} must define mappedBy.',
        );
      }
      final owningRelation = targetDescriptor.relations.firstWhere(
        (r) => r.fieldName == mappedBy,
        orElse: () => throw StateError(
          'Owning relation $mappedBy not found on ${targetDescriptor.tableName}',
        ),
      );
      final joinColumn = owningRelation.joinColumn;
      if (joinColumn == null) {
        throw StateError(
          'Owning relation $mappedBy is missing joinColumn metadata.',
        );
      }

      final targetRepo = _resolveRepository(relation.target, engine);
      if (cascadeDto is List) {
        for (final child in cascadeDto) {
          if (child == null) continue;
          if (child is! InsertDto) {
            throw StateError(
              'Cascade value for ${relation.fieldName} must be InsertDto entries.',
            );
          }
          final injected = _InjectedInsertDto(child, {joinColumn.name: newId});
          await targetRepo._insertWithEngine(injected as dynamic, engine);
        }
      } else {
        if (cascadeDto is! InsertDto) {
          throw StateError(
            'Cascade value for ${relation.fieldName} must be an InsertDto.',
          );
        }
        final injected = _InjectedInsertDto(cascadeDto, {
          joinColumn.name: newId,
        });
        await targetRepo._insertWithEngine(injected as dynamic, engine);
      }
    }

    // Post-insert: ManyToMany relations
    for (final relation in _descriptor.relations) {
      if (relation.type != RelationType.manyToMany) continue;
      if (!relation.shouldCascadePersist) continue;

      final cascadeDto = cascades[relation.fieldName];
      if (cascadeDto == null) continue;

      await _cascadePersistManyToMany(relation, newId, cascadeDto, engine);
    }

    return insertedRow;
  }

  String _generateUuid() => _uuidGenerator.v4();

  Future<Map<String, dynamic>> _updateRowByPkWithEngine(
    UpdateDto<T> values,
    String pkColumnName,
    Object? pkValue,
    EngineAdapter engine,
  ) async {
    final map = Map<String, dynamic>.from(values.toMap());
    _encodeJsonColumns(map);
    if (map.isEmpty) {
      return _findRowByPkWithEngine(pkColumnName, pkValue, engine);
    }
    final sets = <String>[];
    final params = <Object?>[];
    for (final entry in map.entries) {
      params.add(entry.value);
      sets.add('"${entry.key}" = ${engine.placeholderFor(params.length)}');
    }
    params.add(pkValue);
    final pkPlaceholder = engine.placeholderFor(params.length);

    final sql =
        'UPDATE ${_descriptor.tableName} SET ${sets.join(', ')} WHERE "$pkColumnName" = $pkPlaceholder RETURNING *';
    final rows = await engine.query(sql, params);
    if (rows.isEmpty) {
      throw StateError('Unable to update ${_descriptor.tableName}.');
    }
    final updated = rows.first;
    _trackEntitySnapshot(_descriptor.fromRow(updated));
    return updated;
  }

  Future<Map<String, dynamic>> _findRowByPkWithEngine(
    String pkColumnName,
    Object? pkValue,
    EngineAdapter engine,
  ) async {
    final sql =
        'SELECT * FROM ${_descriptor.tableName} WHERE "$pkColumnName" = ${engine.placeholderFor(1)} LIMIT 1';
    final rows = await engine.query(sql, [pkValue]);
    if (rows.isEmpty) {
      throw StateError('Unable to load ${_descriptor.tableName}.');
    }
    return rows.first;
  }

  /// Cascade persist for ManyToMany relations.
  ///
  /// For each item in the cascade:
  /// - If it's an InsertDto: insert the target entity and get its new ID
  /// - Insert a join table entry linking the owner to the target
  Future<void> _cascadePersistManyToMany(
    RelationDescriptor relation,
    Object? ownerId,
    dynamic cascadeData,
    EngineAdapter engine,
  ) async {
    final joinTable = relation.joinTable;
    if (joinTable == null) {
      throw StateError(
        'ManyToMany relation ${relation.fieldName} is missing joinTable metadata.',
      );
    }
    if (joinTable.joinColumns.isEmpty || joinTable.inverseJoinColumns.isEmpty) {
      throw StateError(
        'ManyToMany relation ${relation.fieldName} has incomplete joinTable metadata.',
      );
    }

    final targetDescriptor = EntityDescriptor.lookup(relation.target);
    if (targetDescriptor == null) {
      throw StateError('Missing EntityDescriptor for ${relation.target}');
    }
    final targetPk = targetDescriptor.primaryKey;
    if (targetPk == null) {
      throw StateError('Target entity ${relation.target} has no primary key');
    }

    final ownerJoinColumn = joinTable.joinColumns.first;
    final targetJoinColumn = joinTable.inverseJoinColumns.first;
    final targetRepo = _resolveRepository(relation.target, engine);

    final items = cascadeData is List ? cascadeData : [cascadeData];

    for (final item in items) {
      if (item == null) continue;

      late final Object targetId;

      if (item is InsertDto) {
        // Insert the target entity and get its new ID
        final insertedId = await targetRepo._insertWithEngine(
          item as dynamic,
          engine,
        );
        if (insertedId == null) {
          throw StateError(
            'Insert on ${relation.fieldName} did not return an ID',
          );
        }
        targetId = insertedId;
      } else if (item is num || item is String) {
        // Item is just an ID reference to an existing entity
        targetId = item;
      } else {
        throw StateError(
          'Cascade value for ManyToMany ${relation.fieldName} must be InsertDto or scalar ID, got ${item.runtimeType}',
        );
      }

      // Insert the join table entry
      final joinSql =
          'INSERT INTO ${joinTable.name} ("${ownerJoinColumn.name}", "${targetJoinColumn.name}") VALUES (?, ?)';
      await engine.execute(joinSql, [ownerId, targetId]);
    }
  }

  EntityRepository _resolveRepository(Type target, EngineAdapter engine) {
    final descriptor = EntityDescriptor.lookup(target);
    if (descriptor == null) {
      throw StateError('Missing EntityDescriptor for $target');
    }
    return descriptor.repositoryFactory(engine);
  }

  Map<String, dynamic> _readCascades(InsertDto values) {
    try {
      final dyn = values as dynamic;
      final cascades = dyn.cascades;
      if (cascades is Map) {
        return Map<String, dynamic>.from(cascades);
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  void _applyPostLoad(Iterable<dynamic> items) {
    final hook = _descriptor.hooks?.postLoad;
    if (hook == null) return;
    for (final item in items) {
      if (item is T) {
        hook(item);
      }
    }
  }

  String _toSqlLiteral(Object? value) {
    if (value == null) return 'NULL';
    if (value is bool) return value ? 'TRUE' : 'FALSE';
    if (value is num) return value.toString();
    final raw = value is DateTime
        ? value.toUtc().toIso8601String()
        : value.toString();
    final escaped = raw.replaceAll("'", "''");
    return "'$escaped'";
  }

  void _trySetPrimaryKey(Object entity, String propertyName, Object? value) {
    if (propertyName == 'id') {
      try {
        (entity as dynamic).id = value;
      } catch (_) {}
    }
  }

  String _renderJoinClause(RelationJoinSpec spec) {
    final joinKeyword = spec.joinType == JoinType.left
        ? 'LEFT JOIN'
        : 'INNER JOIN';
    final tableRef = _renderTableReference(spec.tableName);
    final left = '"${spec.alias}"."${spec.foreignColumn}"';
    final right = '"${spec.localAlias}"."${spec.localColumn}"';
    return '$joinKeyword $tableRef AS "${spec.alias}" ON $left = $right';
  }

  String _buildCountTarget(
    SelectOptions<T, P>? select,
    String alias,
    List<SelectField> fields,
  ) {
    if (select == null || !select.hasSelections) {
      return 'COUNT(*)';
    }
    final primaryKey = select.primaryKeyColumn ?? _descriptor.primaryKey?.name;
    if (primaryKey == null || primaryKey.isEmpty) {
      final visible = fields.where((f) => f.visible).toList(growable: false);
      if (visible.isEmpty) {
        return 'COUNT(*)';
      }
      final columns = visible
          .map((f) => '"${f.tableAlias ?? alias}"."${f.name}"')
          .join(', ');
      return 'COUNT(DISTINCT $columns)';
    }
    return 'COUNT(DISTINCT "$alias"."$primaryKey")';
  }

  List<OrderBy>? _defaultOrderBy() {
    final primaryKey = _descriptor.primaryKey?.name;
    if (primaryKey == null || primaryKey.isEmpty) {
      return null;
    }
    return [OrderBy(primaryKey)];
  }

  ColumnDescriptor _deletedAtColumnOrThrow() {
    final deletedAtColumn = _deletedAtColumnFor(_descriptor);
    if (deletedAtColumn == null) {
      throw StateError(
        'Cannot soft delete ${_descriptor.tableName}: no @DeletedAt column found.',
      );
    }
    return deletedAtColumn;
  }

  ColumnDescriptor? _deletedAtColumnFor(EntityDescriptor descriptor) {
    return descriptor.columns.where((column) => column.isDeletedAt).firstOrNull;
  }

  Object _nowForDeletedAt() => DateTime.now().toUtc().toIso8601String();

  String _renderTableReference(String name) =>
      name.split('.').map((part) => '"$part"').join('.');

  String? _buildSelectWhereSql({
    required String alias,
    required QueryBuilder<T>? where,
    required QueryFieldsContext<T> boundContext,
    required List<Object?> params,
    required bool includeDeleted,
  }) {
    final baseWhere = where?.toSql(
      boundContext,
      params,
      placeholderForIndex: _engine.placeholderFor,
    );
    return _appendNotDeletedSql(
      alias: alias,
      whereSql: baseWhere,
      includeDeleted: includeDeleted,
    );
  }

  void _trackEntitySnapshot(T entity) {
    _entitySnapshots[entity] = Map<String, dynamic>.from(
      _descriptor.toRow(entity),
    );
  }

  void _trackEntitySnapshots(Iterable<T> entities) {
    for (final entity in entities) {
      _trackEntitySnapshot(entity);
    }
  }

  void _trackPartialSnapshots(List<P> items, List<Map<String, dynamic>> rows) {
    final len = items.length < rows.length ? items.length : rows.length;
    for (var i = 0; i < len; i++) {
      final snapshot = <String, dynamic>{};
      final row = rows[i];
      for (final column in _descriptor.columns) {
        if (row.containsKey(column.name)) {
          snapshot[column.name] = row[column.name];
        }
      }
      if (snapshot.isNotEmpty) {
        _partialSnapshots[items[i]] = snapshot;
      }
    }
  }

  Map<String, dynamic> _dirtyEntityMap(T entity, Map<String, dynamic> current) {
    final baseline = _entitySnapshots[entity];
    if (baseline == null) return current;
    final dirty = <String, dynamic>{};
    for (final entry in current.entries) {
      if (!baseline.containsKey(entry.key) ||
          baseline[entry.key] != entry.value) {
        dirty[entry.key] = entry.value;
      }
    }
    return dirty;
  }

  Map<String, dynamic> _dirtyPartialMap(
    P entity,
    Map<String, dynamic> current,
  ) {
    final baseline = _partialSnapshots[entity];
    if (baseline == null) return current;
    final dirty = <String, dynamic>{};
    for (final entry in current.entries) {
      if (!baseline.containsKey(entry.key) ||
          baseline[entry.key] != entry.value) {
        dirty[entry.key] = entry.value;
      }
    }
    return dirty;
  }

  String _placeholderList(
    EngineAdapter engine, {
    required int startAt,
    required int count,
  }) {
    return List<String>.generate(
      count,
      (index) => engine.placeholderFor(startAt + index),
      growable: false,
    ).join(', ');
  }

  Future<T> _resolveSavedEntity(
    P entity,
    String pkColumnName,
    Object? pkValue,
  ) async {
    try {
      return entity.toEntity();
    } on StateError {
      if (pkValue == null) {
        rethrow;
      }
    }
    final where = QueryBuilder<T>.from(
      (context) => context.field<Object?>(pkColumnName).equals(pkValue),
    );
    final items = await findBy(where: where, limit: 1);
    if (items.isEmpty) {
      throw StateError('Unable to reload ${_descriptor.tableName} after save.');
    }
    return items.first;
  }

  String? _appendNotDeletedSql({
    required String alias,
    required String? whereSql,
    required bool includeDeleted,
  }) {
    if (includeDeleted) {
      return whereSql;
    }
    final deletedColumn = _descriptor.columns
        .where((column) => column.isDeletedAt)
        .firstOrNull;
    if (deletedColumn == null) {
      return whereSql;
    }
    final deletedCondition = '"$alias"."${deletedColumn.name}" IS NULL';
    if (whereSql == null || whereSql.isEmpty) {
      return deletedCondition;
    }
    return '($whereSql) AND ($deletedCondition)';
  }
}

class _InjectedInsertDto implements InsertDto {
  _InjectedInsertDto(this._base, this._extra);

  final InsertDto _base;
  final Map<String, dynamic> _extra;

  @override
  Map<String, dynamic> toMap() {
    final map = Map<String, dynamic>.from(_base.toMap());
    map.addAll(_extra);
    return map;
  }

  Map<String, dynamic> get cascades {
    try {
      final dyn = _base as dynamic;
      final cascades = dyn.cascades;
      if (cascades is Map) {
        return Map<String, dynamic>.from(cascades);
      }
    } catch (_) {}
    return const <String, dynamic>{};
  }
}

class _DirtyUpdateDto<T extends Entity> implements UpdateDto<T> {
  _DirtyUpdateDto(this._map, [Map<String, dynamic>? cascades])
    : _cascades = cascades ?? const <String, dynamic>{};

  final Map<String, dynamic> _map;
  final Map<String, dynamic> _cascades;

  @override
  Map<String, dynamic> toMap() => Map<String, dynamic>.from(_map);

  Map<String, dynamic> get cascades => _cascades;
}
