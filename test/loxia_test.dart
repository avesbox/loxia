import 'package:loxia/loxia.dart';
import 'package:test/test.dart';

class _Fields extends QueryFieldsContext<_FakeEntity> {
  const _Fields([super.runtime, super.alias]);

  @override
  _Fields bind(QueryRuntimeContext runtime, String alias) =>
      _Fields(runtime, alias);

  QueryField<String> get email => field<String>('email');
  QueryField<int> get age => field<int>('age');
  QueryField<int?> get score => field<int?>('score');

  _Fields get child {
    final alias = ensureRelationJoin(
      relationName: 'child',
      targetTableName: 'child_table',
      localColumn: 'id',
      foreignColumn: 'parent_id',
    );
    return _Fields(runtimeOrThrow, alias);
  }
}

_Fields _fieldsForAlias(String alias) {
  final runtime = QueryRuntimeContext(rootAlias: alias);
  return const _Fields().bind(runtime, alias);
}

void main() {
  group('QueryField + WhereExpression builder', () {
    test('supports equals/and/or composition', () {
      final fields = _fieldsForAlias('t');
      final expr = fields.email
          .equals('foo@bar.com')
          .and(fields.age.gte(18))
          .or(fields.score.isNull());
      final params = <Object?>[];
      final sql = expr.toSql('t', params);
      expect(
        sql,
        '(("t"."email" = ?) AND ("t"."age" >= ?)) OR ("t"."score" IS NULL)',
      );
    });

    test('supports NOT wrapper', () {
      final fields = _fieldsForAlias('u');
      final expr = fields.email.equals('blocked').not();
      final params = <Object?>[];
      final sql = expr.toSql('u', params);
      expect(sql, 'NOT ("u"."email" = ?)');
      expect(params, ['blocked']);
    });

    test('handles IN clauses and empty lists', () {
      final fields = _fieldsForAlias('alias');
      final nonEmpty = fields.age.inList([1, 2, 3]);
      final empty = fields.age.inList([]);
      final params = <Object?>[];
      final sql = nonEmpty.and(empty).toSql('alias', params);
      expect(sql, '("alias"."age" IN (?, ?, ?)) AND (1 = 0)');
      expect(params, [1, 2, 3]);
    });

    test('support complex nested expressions', () {
      final fields = _fieldsForAlias('x');
      final expr = fields.email
          .equals('foo@bar.com')
          .and(
            fields.age
                .gt(18)
                .or(
                  fields.score
                      .isNotNull()
                      .and(fields.score.lt(100))
                      .or(fields.field<int>('level').equals(5)),
                ),
          );
      final params = <Object?>[];
      final sql = expr.toSql('x', params);
      expect(
        sql,
        '("x"."email" = ?) AND (("x"."age" > ?) OR (("x"."score" IS NOT NULL) AND ("x"."score" < ?)) OR ("x"."level" = ?))',
      );
      expect(params, ['foo@bar.com', 18, 100, 5]);
    });

    test('compares columns with isSmallerThan', () {
      final fields = _fieldsForAlias('tbl');
      final expr = fields.age.isSmallerThan(fields.field<int>('max_age'));
      final params = <Object?>[];
      final sql = expr.toSql('tbl', params);
      expect(sql, '"tbl"."age" < "tbl"."max_age"');
      expect(params, isEmpty);
    });

    test('QueryBuilder.from builds expressions', () {
      final builder = QueryBuilder<_FakeEntity>.from(
        (q) => q.field<int>('age').equals(42),
      );
      final params = <Object?>[];
      final context = _fieldsForAlias('u');
      final sql = builder.toSql(context, params);
      expect(sql, '"u"."age" = ?');
      expect(params, [42]);
    });
  });

  group('SelectOptions', () {
    test('renders selected columns', () {
      final select = _FakeSelect(email: true, age: true);
      final context = _fieldsForAlias('root');
      final sql = select.compile(context).sql;
      expect(sql, '"root"."email", "root"."age"');
    });

    test('throws when no selections provided', () {
      final select = _FakeSelect();
      final context = _fieldsForAlias('t');
      expect(() => select.compile(context).sql, throwsStateError);
    });

    test('handles relation selections with alias prefixes', () {
      final select = _FakeSelect(
        email: true,
        relations: _FakeRelations(child: _ChildSelect(score: true)),
      );
      final context = _fieldsForAlias('t');
      final sql = select.compile(context).sql;
      expect(sql, '"t"."email", "t_child"."score" AS "child_score"');
      final joins = context.runtimeOrThrow.joins;
      expect(joins, hasLength(1));
      final spec = joins.single;
      expect(spec.alias, 't_child');
      expect(spec.tableName, 'child_table');
      expect(spec.localColumn, 'id');
      expect(spec.foreignColumn, 'parent_id');
    });
  });
}

class _FakeEntity extends Entity {}

class _PartialFakeEntity extends PartialEntity<_FakeEntity> {
  @override
  Object? get primaryKeyValue => null;

  @override
  _FakeEntity toEntity() {
    // TODO: implement toEntity
    throw UnimplementedError();
  }

  @override
  InsertDto<_FakeEntity> toInsertDto() {
    throw UnimplementedError();
  }

  @override
  UpdateDto<_FakeEntity> toUpdateDto() {
    throw UnimplementedError();
  }
}

class _FakeSelect extends SelectOptions<_FakeEntity, _PartialFakeEntity> {
  const _FakeSelect({this.email = false, this.age = false, this.relations});

  final bool email;
  final bool age;
  final _FakeRelations? relations;

  @override
  bool get hasSelections => email || age || (relations?.hasSelections ?? false);

  @override
  void collect(
    QueryFieldsContext<_FakeEntity> context,
    List<SelectField> out, {
    String? path,
  }) {
    if (context is! _Fields) {
      throw ArgumentError('Expected _Fields for _FakeSelect');
    }
    final _Fields scoped = context;
    String? aliasFor(String column) {
      final current = path;
      if (current == null || current.isEmpty) return null;
      return '${current}_$column';
    }

    final tableAlias = scoped.currentAlias;
    if (email) {
      out.add(
        SelectField('email', tableAlias: tableAlias, alias: aliasFor('email')),
      );
    }
    if (age) {
      out.add(
        SelectField('age', tableAlias: tableAlias, alias: aliasFor('age')),
      );
    }
    final rels = relations;
    if (rels != null && rels.hasSelections) {
      rels.collect(scoped, out, path: path);
    }
  }

  @override
  _PartialFakeEntity hydrate(Map<String, dynamic> row, {String? path}) {
    return _PartialFakeEntity();
  }
}

class _FakeRelations {
  const _FakeRelations({this.child});

  final _ChildSelect? child;

  bool get hasSelections => child?.hasSelections ?? false;

  void collect(_Fields context, List<SelectField> out, {String? path}) {
    final childSelect = child;
    if (childSelect != null && childSelect.hasSelections) {
      final relationPath = path == null || path.isEmpty
          ? 'child'
          : '${path}_child';
      final relationContext = context.child;
      childSelect.collect(relationContext, out, path: relationPath);
    }
  }
}

class _ChildSelect extends SelectOptions<_FakeEntity, _PartialFakeEntity> {
  const _ChildSelect({this.score = false});

  final bool score;

  @override
  bool get hasSelections => score;

  @override
  void collect(
    QueryFieldsContext<_FakeEntity> context,
    List<SelectField> out, {
    String? path,
  }) {
    if (context is! _Fields) {
      throw ArgumentError('Expected _Fields for _ChildSelect');
    }
    final _Fields scoped = context;
    String? aliasFor(String column) {
      final current = path;
      if (current == null || current.isEmpty) return null;
      return '${current}_$column';
    }

    final tableAlias = scoped.currentAlias;
    if (score) {
      out.add(
        SelectField('score', tableAlias: tableAlias, alias: aliasFor('score')),
      );
    }
  }

  @override
  _PartialFakeEntity hydrate(Map<String, dynamic> row, {String? path}) {
    return _PartialFakeEntity();
  }
}
