class OrderBy {
  final String field;
  final bool ascending;

  const OrderBy(this.field, {this.ascending = true});
}

/// Base interface for any WHERE fragment.
abstract class WhereExpression {
  /// Returns the SQL fragment or `null` if no conditions were provided.
  String? toSql(String alias, List<Object?> params);
}

class RelationJoinSpec {
  const RelationJoinSpec({
    required this.alias,
    required this.tableName,
    required this.localAlias,
    required this.localColumn,
    required this.foreignColumn,
    required this.joinType,
  });

  final String alias;
  final String tableName;
  final String localAlias;
  final String localColumn;
  final String foreignColumn;
  final JoinType joinType;
}

enum JoinType { left, inner }

class QueryRuntimeContext {
  QueryRuntimeContext({required this.rootAlias});

  final String rootAlias;
  final Map<String, RelationJoinSpec> _joins = {};

  void ensureJoin(RelationJoinSpec spec) {
    _joins.putIfAbsent(spec.alias, () => spec);
  }

  List<RelationJoinSpec> get joins => _joins.values.toList(growable: false);
}

abstract class QueryFieldsContext<E> {
  const QueryFieldsContext([this.runtimeContext, this.alias]);

  final QueryRuntimeContext? runtimeContext;
  final String? alias;

  QueryFieldsContext<E> bind(QueryRuntimeContext runtime, String alias);

  String get currentAlias {
    final resolved = alias ?? runtimeContext?.rootAlias;
    if (resolved == null) {
      throw StateError('QueryFieldsContext is not bound to a runtime.');
    }
    return resolved;
  }

  QueryRuntimeContext get runtimeOrThrow {
    final value = runtimeContext;
    if (value == null) {
      throw StateError('QueryFieldsContext is not bound to a runtime.');
    }
    return value;
  }

  QueryField<T> field<T>(String name) => QueryField<T>(name, currentAlias);

  String ensureRelationJoin({
    required String relationName,
    required String targetTableName,
    required String localColumn,
    required String foreignColumn,
    JoinType joinType = JoinType.left,
  }) {
    final runtime = runtimeOrThrow;
    final parentAlias = currentAlias;
    final alias = _composeRelationAlias(parentAlias, relationName);
    runtime.ensureJoin(
      RelationJoinSpec(
        alias: alias,
        tableName: targetTableName,
        localAlias: parentAlias,
        localColumn: localColumn,
        foreignColumn: foreignColumn,
        joinType: joinType,
      ),
    );
    return alias;
  }

  /// Ensures a join from a specific alias (e.g., a join table) to a target table.
  /// Used for ManyToMany relations where we need to join through an intermediate table.
  String ensureRelationJoinFrom({
    required String fromAlias,
    required String relationName,
    required String targetTableName,
    required String localColumn,
    required String foreignColumn,
    JoinType joinType = JoinType.left,
  }) {
    final runtime = runtimeOrThrow;
    final alias = _composeRelationAlias(currentAlias, relationName);
    runtime.ensureJoin(
      RelationJoinSpec(
        alias: alias,
        tableName: targetTableName,
        localAlias: fromAlias,
        localColumn: localColumn,
        foreignColumn: foreignColumn,
        joinType: joinType,
      ),
    );
    return alias;
  }

  String _composeRelationAlias(String parentAlias, String relationName) =>
      '${parentAlias}_$relationName';
}

typedef QueryPredicate<E> =
    WhereExpression Function(QueryFieldsContext<E> context);

abstract class QueryBuilder<E> {
  const QueryBuilder();

  factory QueryBuilder.from(QueryPredicate<E> builder) = _LambdaQueryBuilder<E>;

  WhereExpression build(QueryFieldsContext<E> context);

  WhereExpression call(QueryFieldsContext<E> context) => build(context);

  String? toSql(QueryFieldsContext<E> context, List<Object?> params) =>
      build(context).toSql(context.currentAlias, params);
}

class _LambdaQueryBuilder<E> extends QueryBuilder<E> {
  const _LambdaQueryBuilder(this._builder);

  final QueryPredicate<E> _builder;

  @override
  WhereExpression build(QueryFieldsContext<E> context) => _builder(context);
}

QueryBuilder<E> queryWhere<E>(QueryPredicate<E> builder) =>
    QueryBuilder<E>.from(builder);

extension WhereExpressionComposer on WhereExpression {
  WhereExpression and(WhereExpression other) =>
      _CompositeWhere._from(_LogicalOperator.and, this, other);

  WhereExpression or(WhereExpression other) =>
      _CompositeWhere._from(_LogicalOperator.or, this, other);

  WhereExpression not() => _NotWhere(this);
}

enum _LogicalOperator { and, or }

class _CompositeWhere implements WhereExpression {
  const _CompositeWhere(this._operator, this._expressions);

  final _LogicalOperator _operator;
  final List<WhereExpression> _expressions;

  static WhereExpression _from(
    _LogicalOperator op,
    WhereExpression left,
    WhereExpression right,
  ) {
    final parts = <WhereExpression>[];

    void collect(WhereExpression expr) {
      if (expr is _CompositeWhere && expr._operator == op) {
        parts.addAll(expr._expressions);
        return;
      }
      parts.add(expr);
    }

    collect(left);
    collect(right);
    return _CompositeWhere(op, parts);
  }

  @override
  String? toSql(String alias, List<Object?> params) {
    final clauses = <String>[];
    for (final expr in _expressions) {
      final sql = expr.toSql(alias, params);
      if (sql != null && sql.isNotEmpty) {
        clauses.add(sql);
      }
    }
    if (clauses.isEmpty) return null;
    if (clauses.length == 1) return clauses.single;
    final joiner = _operator == _LogicalOperator.and ? ' AND ' : ' OR ';
    return clauses.map((c) => '($c)').join(joiner);
  }
}

class _NotWhere implements WhereExpression {
  const _NotWhere(this._inner);

  final WhereExpression _inner;

  @override
  String? toSql(String alias, List<Object?> params) {
    final sql = _inner.toSql(alias, params);
    if (sql == null || sql.isEmpty) return null;
    return 'NOT ($sql)';
  }
}

class QueryField<T> {
  const QueryField(this._column, this._alias);

  final String _column;
  final String _alias;

  ColumnPredicate<T> equals(T value) => ColumnPredicate<T>._(
    _alias,
    _column,
    WhereCondition<T>._(_WhereConditionKind.equals, value: value),
  );

  WhereExpression equalsField<S>(QueryField<S> other) =>
      _compareWith(other, '=');

  WhereExpression differsFromField<S>(QueryField<S> other) =>
      _compareWith(other, '<>');

  WhereExpression isSmallerThan<S>(QueryField<S> other) =>
      _compareWith(other, '<');

  WhereExpression isSmallerOrEqualThan<S>(QueryField<S> other) =>
      _compareWith(other, '<=');

  WhereExpression isGreaterThan<S>(QueryField<S> other) =>
      _compareWith(other, '>');

  WhereExpression isGreaterOrEqualThan<S>(QueryField<S> other) =>
      _compareWith(other, '>=');

  ColumnPredicate<T> notEquals(T value) => ColumnPredicate<T>._(
    _alias,
    _column,
    WhereCondition<T>._(_WhereConditionKind.notEquals, value: value),
  );

  ColumnPredicate<T> greaterThan(T value) => ColumnPredicate<T>._(
    _alias,
    _column,
    WhereCondition<T>._(_WhereConditionKind.greaterThan, value: value),
  );

  ColumnPredicate<T> greaterOrEqual(T value) => ColumnPredicate<T>._(
    _alias,
    _column,
    WhereCondition<T>._(_WhereConditionKind.greaterOrEqual, value: value),
  );

  ColumnPredicate<T> lessThan(T value) => ColumnPredicate<T>._(
    _alias,
    _column,
    WhereCondition<T>._(_WhereConditionKind.lessThan, value: value),
  );

  ColumnPredicate<T> lessOrEqual(T value) => ColumnPredicate<T>._(
    _alias,
    _column,
    WhereCondition<T>._(_WhereConditionKind.lessOrEqual, value: value),
  );

  ColumnPredicate<T> isNull() => ColumnPredicate<T>._(
    _alias,
    _column,
    WhereCondition<T>._(_WhereConditionKind.isNull),
  );

  ColumnPredicate<T> isNotNull() => ColumnPredicate<T>._(
    _alias,
    _column,
    WhereCondition<T>._(_WhereConditionKind.isNotNull),
  );

  ColumnPredicate<T> inList(List<T?> values) => ColumnPredicate<T>._(
    _alias,
    _column,
    WhereCondition<T>._(_WhereConditionKind.inList, values: values),
  );

  WhereExpression _compareWith<S>(QueryField<S> other, String operator) =>
      _ColumnComparisonPredicate(
        _alias,
        _column,
        other._alias,
        other._column,
        operator,
      );
}

extension QueryFieldNumShortcuts<T extends num> on QueryField<T> {
  ColumnPredicate<T> gt(T value) => this.greaterThan(value);
  ColumnPredicate<T> gte(T value) => this.greaterOrEqual(value);
  ColumnPredicate<T> lt(T value) => this.lessThan(value);
  ColumnPredicate<T> lte(T value) => this.lessOrEqual(value);
}

extension QueryFieldNullableNumShortcuts<T extends num> on QueryField<T?> {
  ColumnPredicate<T?> gt(T value) => this.greaterThan(value);
  ColumnPredicate<T?> gte(T value) => this.greaterOrEqual(value);
  ColumnPredicate<T?> lt(T value) => this.lessThan(value);
  ColumnPredicate<T?> lte(T value) => this.lessOrEqual(value);
}

extension QueryFieldStringOps on QueryField<String> {
  ColumnPredicate<String> like(String pattern) => ColumnPredicate<String>._(
    _alias,
    _column,
    WhereCondition<String>._(_WhereConditionKind.like, value: pattern),
  );
}

extension QueryFieldNullableStringOps on QueryField<String?> {
  ColumnPredicate<String?> like(String pattern) => ColumnPredicate<String?>._(
    _alias,
    _column,
    WhereCondition<String?>._(_WhereConditionKind.like, value: pattern),
  );
}

class ColumnPredicate<T> implements WhereExpression {
  const ColumnPredicate._(this._alias, this._column, this._condition);

  final String _alias;
  final String _column;
  final WhereCondition<T> _condition;

  @override
  String? toSql(String alias, List<Object?> params) {
    return _condition.toSql(_alias, _column, params);
  }
}

/// Represents a typed comparison against a single column.
class WhereCondition<T> {
  const WhereCondition._(this._kind, {this.value, this.values});

  final _WhereConditionKind _kind;
  final T? value;
  final List<T?>? values;

  String toSql(String alias, String column, List<Object?> params) {
    final colRef = '"$alias"."$column"';
    switch (_kind) {
      case _WhereConditionKind.equals:
        if (value == null) return '$colRef IS NULL';
        params.add(value);
        return '$colRef = ?';
      case _WhereConditionKind.notEquals:
        if (value == null) return '$colRef IS NOT NULL';
        params.add(value);
        return '$colRef <> ?';
      case _WhereConditionKind.greaterThan:
        params.add(value);
        return '$colRef > ?';
      case _WhereConditionKind.greaterOrEqual:
        params.add(value);
        return '$colRef >= ?';
      case _WhereConditionKind.lessThan:
        params.add(value);
        return '$colRef < ?';
      case _WhereConditionKind.lessOrEqual:
        params.add(value);
        return '$colRef <= ?';
      case _WhereConditionKind.like:
        params.add(value);
        return '$colRef LIKE ?';
      case _WhereConditionKind.isNull:
        return '$colRef IS NULL';
      case _WhereConditionKind.isNotNull:
        return '$colRef IS NOT NULL';
      case _WhereConditionKind.inList:
        final items = values ?? const [];
        if (items.isEmpty) {
          return '1 = 0';
        }
        params.addAll(items);
        final placeholders = List.filled(items.length, '?').join(', ');
        return '$colRef IN ($placeholders)';
    }
  }
}

class _ColumnComparisonPredicate implements WhereExpression {
  const _ColumnComparisonPredicate(
    this._leftAlias,
    this._leftColumn,
    this._rightAlias,
    this._rightColumn,
    this._operator,
  );

  final String _leftAlias;
  final String _leftColumn;
  final String _rightAlias;
  final String _rightColumn;
  final String _operator;

  @override
  String? toSql(String alias, List<Object?> params) {
    final left = '"$_leftAlias"."$_leftColumn"';
    final right = '"$_rightAlias"."$_rightColumn"';
    return '$left $_operator $right';
  }
}

enum _WhereConditionKind {
  equals,
  notEquals,
  greaterThan,
  greaterOrEqual,
  lessThan,
  lessOrEqual,
  like,
  isNull,
  isNotNull,
  inList,
}

// Condition builders with type inference support.
WhereCondition<T> equals<T>(T? value) =>
    WhereCondition<T>._(_WhereConditionKind.equals, value: value);

WhereCondition<T> notEquals<T>(T? value) =>
    WhereCondition<T>._(_WhereConditionKind.notEquals, value: value);

WhereCondition<T> greaterThan<T>(T value) =>
    WhereCondition<T>._(_WhereConditionKind.greaterThan, value: value);

WhereCondition<T> greaterOrEqual<T>(T value) =>
    WhereCondition<T>._(_WhereConditionKind.greaterOrEqual, value: value);

WhereCondition<T> lessThan<T>(T value) =>
    WhereCondition<T>._(_WhereConditionKind.lessThan, value: value);

WhereCondition<T> lessOrEqual<T>(T value) =>
    WhereCondition<T>._(_WhereConditionKind.lessOrEqual, value: value);

WhereCondition<String> like(String pattern) =>
    WhereCondition<String>._(_WhereConditionKind.like, value: pattern);

WhereCondition<T> isNull<T>() =>
    WhereCondition<T>._(_WhereConditionKind.isNull);

WhereCondition<T> isNotNull<T>() =>
    WhereCondition<T>._(_WhereConditionKind.isNotNull);

WhereCondition<T> inList<T>(List<T?> values) =>
    WhereCondition<T>._(_WhereConditionKind.inList, values: values);

/// Simple literal condition for raw SQL (escape responsibly).
class RawWhere implements WhereExpression {
  const RawWhere(this.sql, [this.parameters = const []]);

  final String sql;
  final List<Object?> parameters;

  @override
  String? toSql(String alias, List<Object?> params) {
    params.addAll(parameters);
    return sql;
  }
}

/// Projection result containing the SQL columns and a mapper function.
class SelectProjection<P> {
  const SelectProjection({
    required this.sql,
    required this.mapper,
    this.aggregator,
  });

  final String sql;
  final P Function(Map<String, dynamic> row) mapper;

  /// Optional aggregator for collection relations. If provided, the repository
  /// should use this to aggregate rows instead of mapping each row individually.
  final List<P> Function(List<Map<String, dynamic>> rows)? aggregator;
}

/// Base class for select options that define which columns to retrieve.
///
/// [T] is the entity type, [P] is the partial entity type that will be returned.
abstract class SelectOptions<T, P> {
  const SelectOptions();

  /// Returns a new select options instance with [relations] applied.
  ///
  /// Generated selects override this to return a properly typed clone.
  /// Base implementation throws to make unsupported custom selects explicit.
  SelectOptions<T, P> withRelations(RelationsOptions<T, P>? relations) {
    throw UnsupportedError(
      '$runtimeType does not support relation injection. '
      'Override withRelations in this select class.',
    );
  }

  /// Whether this selection exposes at least one column or relation.
  bool get hasSelections;

  /// Whether this selection includes any collection relations that require row aggregation.
  bool get hasCollectionRelations => false;

  /// The name of the primary key column for aggregation purposes.
  String? get primaryKeyColumn => null;

  /// Collects the list of fields that should appear in the SELECT clause.
  void collect(
    QueryFieldsContext<T> context,
    List<SelectField> out, {
    String? path,
  });

  /// Hydrates a partial entity from a row, using the path prefix for aliased columns.
  P hydrate(Map<String, dynamic> row, {String? path});

  /// Aggregates multiple rows into a list of partial entities, grouping by primary key
  /// and collecting collection relation items.
  ///
  /// Override this in generated code to handle collection relations properly.
  List<P> aggregateRows(List<Map<String, dynamic>> rows, {String? path}) {
    // Default implementation: just hydrate each row (no aggregation)
    return rows.map((row) => hydrate(row, path: path)).toList();
  }

  /// Compiles this selection into a projection with SQL and mapper.
  SelectProjection<P> compile(QueryFieldsContext<T> context) {
    if (!hasSelections) {
      throw StateError(
        '$runtimeType does not have any selections. Enable at least one field.',
      );
    }
    final fields = <SelectField>[];
    collect(context, fields, path: null);
    final visible = fields.where((f) => f.visible).toList(growable: false);
    if (visible.isEmpty) {
      throw StateError('$runtimeType did not yield any visible columns.');
    }
    final sql = visible.map((f) => f.toSql()).join(', ');
    return SelectProjection<P>(
      sql: sql,
      mapper: (row) => hydrate(row),
      aggregator: hasCollectionRelations ? (rows) => aggregateRows(rows) : null,
    );
  }

  /// Helper to compose a column alias with a path prefix.
  String? composeAlias(String? path, String column) {
    if (path == null || path.isEmpty) return null;
    return '${path}_$column';
  }

  /// Helper to extend a path with a new segment.
  String extendPath(String? path, String segment) {
    if (path == null || path.isEmpty) return segment;
    return '${path}_$segment';
  }

  /// Helper to read a value from a row, handling aliased columns.
  Object? readValue(Map<String, dynamic> row, String column, {String? path}) {
    final key = composeAlias(path, column) ?? column;
    return row[key];
  }
}

class SelectField {
  SelectField(this.name, {this.alias, this.tableAlias, this.visible = true});

  final String name;
  final String? alias;
  final String? tableAlias;
  bool visible;

  String toSql() {
    final buffer = StringBuffer();
    final table = tableAlias;
    if (table != null && table.isNotEmpty) {
      buffer.write('"$table"."$name"');
    } else {
      buffer.write('"$name"');
    }
    final aliasName = alias;
    if (aliasName != null && aliasName.isNotEmpty && aliasName != name) {
      buffer.write(' AS "$aliasName"');
    }
    return buffer.toString();
  }
}

abstract class RelationsOptions<T, P> {
  const RelationsOptions();

  bool get hasSelections;

  void collect(
    QueryFieldsContext<T> context,
    List<SelectField> out, {
    String? path,
  });
}
