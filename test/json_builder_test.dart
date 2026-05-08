import 'package:code_builder/code_builder.dart';
import 'package:loxia/loxia.dart';
import 'package:loxia/src/generator/builders/json_extension_builder.dart';
import 'package:loxia/src/generator/builders/models.dart';
import 'package:loxia/src/generator/builders/partial_entity_builder.dart';
import 'package:test/test.dart';

void main() {
  group('Json relation serialization', () {
    test(
      'entity json builder skips null-aware access under omit-null guard',
      () {
        final code = _emit(_jsonBuilder.build(_contextWithRelations()));

        expect(
          code,
          contains(
            "if (tags != null) 'tags': tags!.map((e) => e.toJson()).toList()",
          ),
        );
        expect(code, contains("if (user != null) 'user': user!.toJson()"));
        expect(code, isNot(contains('tags?.map((e) => e.toJson()).toList()')));
        expect(code, isNot(contains("user?.toJson()")));
      },
    );

    test(
      'partial entity builder skips null-aware access under omit-null guard',
      () {
        final code = _emit(_partialBuilder.build(_contextWithRelations()));

        expect(
          code,
          contains(
            "if (tags != null) 'tags': tags!.map((e) => e.toJson()).toList()",
          ),
        );
        expect(code, contains("if (user != null) 'user': user!.toJson()"));
        expect(code, isNot(contains('tags?.map((e) => e.toJson()).toList()')));
        expect(code, isNot(contains('user?.toJson()')));
      },
    );
  });

  group('Enum serialization', () {
    test('entity json builder uses custom enum value accessors', () {
      final code = _emit(_jsonBuilder.build(_contextWithCustomStringEnum()));

      expect(code, contains("if (status != null) 'status': status?.value"));
      expect(code, isNot(contains("'status': status.name")));
    });

    test('partial entity builder uses custom enum value accessors', () {
      final code = _emit(_partialBuilder.build(_contextWithCustomStringEnum()));

      expect(code, contains("if (status != null) 'status': status?.value"));
      expect(code, isNot(contains("status?.name")));
    });
  });
}

const _jsonBuilder = JsonExtensionBuilder();
const _partialBuilder = PartialEntityBuilder();

EntityGenerationContext _contextWithRelations() {
  return EntityGenerationContext(
    className: 'Post',
    tableName: 'posts',
    columns: [
      GenColumn(
        name: 'id',
        prop: 'id',
        type: ColumnType.integer,
        dartTypeCode: 'int?',
        isEnum: false,
        nullable: true,
        unique: false,
        isPk: true,
        autoIncrement: true,
        uuid: false,
      ),
      GenColumn(
        name: 'title',
        prop: 'title',
        type: ColumnType.text,
        dartTypeCode: 'String',
        isEnum: false,
        nullable: false,
        unique: false,
        isPk: false,
        autoIncrement: false,
        uuid: false,
      ),
    ],
    queries: const [],
    relations: [
      GenRelation(
        fieldName: 'user',
        type: RelationKind.manyToOne,
        targetTypeCode: 'User',
        isOwningSide: true,
        mappedBy: null,
        fetchLiteral: 'RelationFetchStrategy.lazy',
        cascadeLiteral: 'const []',
        cascadePersist: false,
        cascadeMerge: false,
        cascadeRemove: false,
        joinColumn: GenJoinColumn(
          name: 'user_id',
          referencedColumnName: 'id',
          nullable: true,
          unique: false,
        ),
        joinColumnPropertyName: 'userId',
        joinColumnBaseDartType: 'int',
        joinColumnNullable: true,
      ),
      GenRelation(
        fieldName: 'tags',
        type: RelationKind.manyToMany,
        targetTypeCode: 'Tag',
        isOwningSide: true,
        mappedBy: null,
        fetchLiteral: 'RelationFetchStrategy.lazy',
        cascadeLiteral: 'const []',
        cascadePersist: false,
        cascadeMerge: false,
        cascadeRemove: false,
        isCollection: true,
      ),
    ],
  );
}

EntityGenerationContext _contextWithCustomStringEnum() {
  return EntityGenerationContext(
    className: 'Post',
    tableName: 'posts',
    columns: [
      GenColumn(
        name: 'status',
        prop: 'status',
        type: ColumnType.text,
        dartTypeCode: 'PostStatus?',
        isEnum: true,
        enumTypeName: 'PostStatus',
        enumValueAccessor: 'value',
        nullable: true,
        unique: false,
        isPk: false,
        autoIncrement: false,
        uuid: false,
      ),
    ],
    queries: const [],
    relations: const [],
  );
}

String _emit(Spec spec) {
  return spec.accept(DartEmitter(useNullSafetySyntax: true)).toString();
}
