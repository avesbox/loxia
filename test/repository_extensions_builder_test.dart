import 'package:code_builder/code_builder.dart';
import 'package:loxia/loxia.dart';
import 'package:loxia/src/generator/builders/models.dart';
import 'package:loxia/src/generator/builders/repository_extensions_builder.dart';
import 'package:loxia/src/generator/util/sql_analyzer.dart';
import 'package:test/test.dart';

void main() {
  group('RepositoryExtensionsBuilder', () {
    const builder = RepositoryExtensionsBuilder();

    test('infers typed repeated custom placeholders for select queries', () {
      final context = _createUserContext(
        queries: [
          GenQuery(
            name: 'findByLogin',
            sql:
                'SELECT * FROM users WHERE email = @login OR username = @login',
            lifecycleHooks: const [],
          ),
        ],
      );
      _applyAnalysis(context);
      final analysis = context.queries.single.analysisResult!;
      final extension = builder.build(context);

      final method = extension.methods.firstWhere(
        (m) => m.name == 'findByLogin',
      );
      final code = _emitExtension(extension);

      expect(analysis.variableTypes, {'login': 'String'});
      expect(method.requiredParameters.map((p) => p.name), ['login']);
      expect(method.requiredParameters.single.type?.symbol, 'String');
      expect(code, contains('findByLogin(String login) async'));
      expect(
        code,
        contains(
          "final rows = await engine.query('SELECT * FROM users WHERE email = ? OR username = ?', [login, login]);",
        ),
      );
    });

    test(
      'supports custom placeholders alongside entity-backed lifecycle mutations',
      () {
        final extension = builder.build(
          EntityGenerationContext(
            className: 'User',
            tableName: 'users',
            columns: [
              GenColumn(
                name: 'id',
                prop: 'id',
                type: ColumnType.integer,
                dartTypeCode: 'int',
                isEnum: false,
                nullable: false,
                unique: false,
                isPk: true,
                autoIncrement: false,
                uuid: false,
              ),
            ],
            queries: [
              GenQuery(
                name: 'auditUpdate',
                sql: 'UPDATE users SET audit_actor = @actorId WHERE id = @id',
                lifecycleHooks: const ['preUpdate'],
              ),
            ],
            relations: [],
          ),
        );

        final method = extension.methods.firstWhere(
          (m) => m.name == 'auditUpdate',
        );
        final code = _emitExtension(extension);

        expect(method.requiredParameters.map((p) => p.name), [
          'entity',
          'actorId',
        ]);
        expect(method.requiredParameters.last.type?.symbol, 'Object?');
        expect(
          code,
          contains(
            "await engine.query('UPDATE users SET audit_actor = ? WHERE id = ?', [actorId, entity.id]);",
          ),
        );
      },
    );
  });
}

String _emitExtension(Extension extension) {
  return extension.accept(DartEmitter(useNullSafetySyntax: true)).toString();
}

EntityGenerationContext _createUserContext({required List<GenQuery> queries}) {
  return EntityGenerationContext(
    className: 'User',
    tableName: 'users',
    columns: [
      GenColumn(
        name: 'id',
        prop: 'id',
        type: ColumnType.integer,
        dartTypeCode: 'int',
        isEnum: false,
        nullable: false,
        unique: false,
        isPk: true,
        autoIncrement: false,
        uuid: false,
      ),
      GenColumn(
        name: 'email',
        prop: 'email',
        type: ColumnType.text,
        dartTypeCode: 'String',
        isEnum: false,
        nullable: false,
        unique: true,
        isPk: false,
        autoIncrement: false,
        uuid: false,
      ),
      GenColumn(
        name: 'username',
        prop: 'username',
        type: ColumnType.text,
        dartTypeCode: 'String',
        isEnum: false,
        nullable: false,
        unique: true,
        isPk: false,
        autoIncrement: false,
        uuid: false,
      ),
    ],
    queries: queries,
    relations: [],
  );
}

void _applyAnalysis(EntityGenerationContext context) {
  final analyzer = SqlAnalyzer(context);
  for (final query in context.queries) {
    final analysis = analyzer.analyze(query.name, query.sql);
    query.analysisResult = GenQueryAnalysisResult(
      columns: analysis.columns
          .map(
            (c) => GenQueryColumn(
              name: c.name,
              dartType: c.dartType,
              nullable: c.nullable,
              originalColumnName: c.originalColumnName,
            ),
          )
          .toList(),
      matchesEntity: analysis.matchesEntity,
      matchesPartialEntity: analysis.matchesPartialEntity,
      hasJoins: analysis.hasJoins,
      hasAggregates: analysis.hasAggregates,
      isSingleResult: analysis.isSingleResult,
      dtoClassName: analysis.dtoClassName,
      variableTypes: analysis.variableTypes,
    );
  }
}
