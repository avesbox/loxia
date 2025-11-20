import 'package:loxia/loxia.dart';
import 'package:test/test.dart';

class _Fields extends QueryFieldsContext<void> {
  const _Fields();

  QueryField<String> get email => const QueryField<String>('email');
  QueryField<int> get age => const QueryField<int>('age');
  QueryField<int?> get score => const QueryField<int?>('score');
}

void main() {
  group('QueryField + WhereExpression builder', () {
    test('supports equals/and/or composition', () {
      const fields = _Fields();
      final expr = fields.email
        .equals('foo@bar.com')
        .and(fields.age.gte(18))
        .or(fields.score.isNull());
      final params = <Object?>[];
      final sql = expr.toSql('t', params);
      expect(sql, '(("t"."email" = ?) AND ("t"."age" >= ?)) OR ("t"."score" IS NULL)');
    });

    test('supports NOT wrapper', () {
      const fields = _Fields();
      final expr = fields.email.equals('blocked').not();
      final params = <Object?>[];
      final sql = expr.toSql('u', params);
      expect(sql, 'NOT ("u"."email" = ?)');
      expect(params, ['blocked']);
    });

    test('handles IN clauses and empty lists', () {
      const fields = _Fields();
      final nonEmpty = fields.age.inList([1, 2, 3]);
      final empty = fields.age.inList([]);
      final params = <Object?>[];
      final sql = nonEmpty.and(empty).toSql('alias', params);
      expect(sql, '("alias"."age" IN (?, ?, ?)) AND (1 = 0)');
      expect(params, [1, 2, 3]);
    });

    test('support complex nested expressions', () {
      const fields = _Fields();
      final expr = fields.email.equals('foo@bar.com').and(
        fields.age.gt(18).or(
          fields.score.isNotNull().and(
            fields.score.lt(100),
          ).or(fields.field<int>('level').equals(5)),
        ),
      );
      final params = <Object?>[];
      final sql = expr.toSql('x', params);
      expect(sql,
        '("x"."email" = ?) AND (("x"."age" > ?) OR (("x"."score" IS NOT NULL) AND ("x"."score" < ?)) OR ("x"."level" = ?))');
      expect(params, ['foo@bar.com', 18, 100, 5]);
    });

    test('compares columns with isSmallerThan', () {
      const fields = _Fields();
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
      final sql = builder.toSql(const QueryFieldsContext<_FakeEntity>(), 'u', params);
      expect(sql, '"u"."age" = ?');
      expect(params, [42]);
    });
  });
}

class _FakeEntity extends Entity {}
