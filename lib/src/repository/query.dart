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

class QueryFieldsContext<E> {
	const QueryFieldsContext();

	QueryField<T> field<T>(String name) => QueryField<T>(name);
}

typedef QueryPredicate<E> = WhereExpression Function(QueryFieldsContext<E> context);

abstract class QueryBuilder<E> {
	const QueryBuilder();

	factory QueryBuilder.from(QueryPredicate<E> builder) = _LambdaQueryBuilder<E>;

	WhereExpression build(QueryFieldsContext<E> context);

	WhereExpression call(QueryFieldsContext<E> context) => build(context);

	String? toSql(QueryFieldsContext<E> context, String alias, List<Object?> params) {
		return build(context).toSql(alias, params);
	}
}

class _LambdaQueryBuilder<E> extends QueryBuilder<E> {
	const _LambdaQueryBuilder(this._builder);

	final QueryPredicate<E> _builder;

	@override
	WhereExpression build(QueryFieldsContext<E> context) => _builder(context);
}

QueryBuilder<E> queryWhere<E>(QueryPredicate<E> builder) => QueryBuilder<E>.from(builder);

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
	const QueryField(this._column);

	final String _column;

	ColumnPredicate<T> equals(T value) => ColumnPredicate<T>._(
		_column,
		WhereCondition<T>._(
			_WhereConditionKind.equals,
			value: value,
		),
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
		_column,
		WhereCondition<T>._(
			_WhereConditionKind.notEquals,
			value: value,
		),
	);

	ColumnPredicate<T> greaterThan(T value) => ColumnPredicate<T>._(
		_column,
		WhereCondition<T>._(
			_WhereConditionKind.greaterThan,
			value: value,
		),
	);

	ColumnPredicate<T> greaterOrEqual(T value) => ColumnPredicate<T>._(
		_column,
		WhereCondition<T>._(
			_WhereConditionKind.greaterOrEqual,
			value: value,
		),
	);

	ColumnPredicate<T> lessThan(T value) => ColumnPredicate<T>._(
		_column,
		WhereCondition<T>._(
			_WhereConditionKind.lessThan,
			value: value,
		),
	);

	ColumnPredicate<T> lessOrEqual(T value) => ColumnPredicate<T>._(
		_column,
		WhereCondition<T>._(
			_WhereConditionKind.lessOrEqual,
			value: value,
		),
	);

	ColumnPredicate<T> isNull() => ColumnPredicate<T>._(
		_column,
		WhereCondition<T>._(_WhereConditionKind.isNull),
	);

	ColumnPredicate<T> isNotNull() => ColumnPredicate<T>._(
		_column,
		WhereCondition<T>._(_WhereConditionKind.isNotNull),
	);

	ColumnPredicate<T> inList(List<T?> values) => ColumnPredicate<T>._(
		_column,
		WhereCondition<T>._(
			_WhereConditionKind.inList,
			values: values,
		),
	);

	WhereExpression _compareWith<S>(QueryField<S> other, String operator) =>
		_ColumnComparisonPredicate(_column, other._column, operator);
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
		_column,
		WhereCondition<String>._(
			_WhereConditionKind.like,
			value: pattern,
		),
	);
}

extension QueryFieldNullableStringOps on QueryField<String?> {
	ColumnPredicate<String?> like(String pattern) => ColumnPredicate<String?>._(
		_column,
		WhereCondition<String?>._(
			_WhereConditionKind.like,
			value: pattern,
		),
	);
}

class ColumnPredicate<T> implements WhereExpression {
	const ColumnPredicate._(this._column, this._condition);

	final String _column;
	final WhereCondition<T> _condition;

	@override
	String? toSql(String alias, List<Object?> params) {
		return _condition.toSql(alias, _column, params);
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
		const _ColumnComparisonPredicate(this._leftColumn, this._rightColumn, this._operator);

		final String _leftColumn;
		final String _rightColumn;
		final String _operator;

		@override
		String? toSql(String alias, List<Object?> params) {
			final left = '"$alias"."$_leftColumn"';
			final right = '"$alias"."$_rightColumn"';
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
