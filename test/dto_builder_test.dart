import 'package:loxia/loxia.dart';
import 'package:loxia/src/generator/builders/dto_builders.dart';
import 'package:loxia/src/generator/builders/models.dart';
import 'package:test/test.dart';

void main() {
  group('InsertDtoBuilder', () {
    late InsertDtoBuilder builder;

    setUp(() {
      builder = const InsertDtoBuilder();
    });

    group('copyWith method', () {
      test(
        'copyWith parameter for non-nullable FK field should be nullable (issue #4)',
        () {
          final context = _createContextWithNonNullableFK();
          final dtoClass = builder.build(context);

          final copyWithMethod = dtoClass.methods.firstWhere(
            (m) => m.name == 'copyWith',
          );

          // Find the ownerId parameter in copyWith
          final ownerIdParam = copyWithMethod.optionalParameters.firstWhere(
            (p) => p.name == 'ownerId',
          );

          // The parameter type should be nullable (int?), not non-nullable (int)
          expect(ownerIdParam.type?.symbol, 'int?');
        },
      );

      test('copyWith parameter for nullable FK field should be nullable', () {
        final context = _createContextWithNullableFK();
        final dtoClass = builder.build(context);
        final copyWithMethod = dtoClass.methods.firstWhere(
          (m) => m.name == 'copyWith',
        );

        final categoryIdParam = copyWithMethod.optionalParameters.firstWhere(
          (p) => p.name == 'categoryId',
        );

        expect(categoryIdParam.type?.symbol, 'int?');
      });

      test(
        'copyWith parameter for regular non-nullable column should be nullable',
        () {
          final context = _createContextWithNonNullableColumn();
          final dtoClass = builder.build(context);

          final copyWithMethod = dtoClass.methods.firstWhere(
            (m) => m.name == 'copyWith',
          );

          final titleParam = copyWithMethod.optionalParameters.firstWhere(
            (p) => p.name == 'title',
          );

          expect(titleParam.type?.symbol, 'String?');
        },
      );
    });

    group('constructor', () {
      test('constructor parameter for non-nullable FK should be required', () {
        final context = _createContextWithNonNullableFK();
        final dtoClass = builder.build(context);

        final constructor = dtoClass.constructors.first;

        final ownerIdParam = constructor.optionalParameters.firstWhere(
          (p) => p.name == 'ownerId',
        );

        // Constructor should require the parameter
        expect(ownerIdParam.required, isTrue);
      });

      test('constructor parameter for nullable FK should not be required', () {
        final context = _createContextWithNullableFK();
        final dtoClass = builder.build(context);

        final constructor = dtoClass.constructors.first;

        final categoryIdParam = constructor.optionalParameters.firstWhere(
          (p) => p.name == 'categoryId',
        );

        // Constructor should not require the parameter
        expect(categoryIdParam.required, isFalse);
      });
    });

    group('field declarations', () {
      test('field for non-nullable FK should be non-nullable', () {
        final context = _createContextWithNonNullableFK();
        final dtoClass = builder.build(context);

        final ownerIdField = dtoClass.fields.firstWhere(
          (f) => f.name == 'ownerId',
        );

        // Field type should match the join column nullability
        expect(ownerIdField.type?.symbol, 'int');
      });

      test('field for nullable FK should be nullable', () {
        final context = _createContextWithNullableFK();
        final dtoClass = builder.build(context);

        final categoryIdField = dtoClass.fields.firstWhere(
          (f) => f.name == 'categoryId',
        );

        expect(categoryIdField.type?.symbol, 'int?');
      });
    });
  });
}

EntityGenerationContext _createContextWithNonNullableFK() {
  return EntityGenerationContext(
    className: 'Todo',
    tableName: 'todos',
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
    queries: [],
    relations: [
      GenRelation(
        fieldName: 'owner',
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
          name: 'owner_id',
          referencedColumnName: 'id',
          nullable: false,
          unique: false,
        ),
        joinColumnPropertyName: 'ownerId',
        joinColumnBaseDartType: 'int',
        joinColumnNullable: false,
      ),
    ],
  );
}

EntityGenerationContext _createContextWithNullableFK() {
  return EntityGenerationContext(
    className: 'Comment',
    tableName: 'comments',
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
        name: 'content',
        prop: 'content',
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
    queries: [],
    relations: [
      GenRelation(
        fieldName: 'category',
        type: RelationKind.manyToOne,
        targetTypeCode: 'Category',
        isOwningSide: true,
        mappedBy: null,
        fetchLiteral: 'RelationFetchStrategy.lazy',
        cascadeLiteral: 'const []',
        cascadePersist: false,
        cascadeMerge: false,
        cascadeRemove: false,
        joinColumn: GenJoinColumn(
          name: 'category_id',
          referencedColumnName: 'id',
          nullable: true,
          unique: false,
        ),
        joinColumnPropertyName: 'categoryId',
        joinColumnBaseDartType: 'int',
        joinColumnNullable: true,
      ),
    ],
  );
}

EntityGenerationContext _createContextWithNonNullableColumn() {
  return EntityGenerationContext(
    className: 'Article',
    tableName: 'articles',
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
    queries: [],
    relations: [],
  );
}
