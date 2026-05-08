import 'package:loxia/loxia.dart';
import 'package:loxia/src/generator/builders/dto_builders.dart';
import 'package:loxia/src/generator/builders/models.dart';
import 'package:test/test.dart';
import 'package:code_builder/code_builder.dart';

void main() {
  group('InsertDtoBuilder', () {
    late InsertDtoBuilder builder;

    setUp(() {
      builder = const InsertDtoBuilder();
    });

    group('copyWith method', () {
      test(
        'copyWith parameter for non-nullable FK field should be nullable',
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

    group('fromMap factory', () {
      test('generates a fromMap factory with snake_case and cascade parsing', () {
        final context = EntityGenerationContext(
          className: 'Order',
          tableName: 'orders',
          columns: [
            GenColumn(
              name: 'attempts',
              prop: 'attempts',
              type: ColumnType.integer,
              dartTypeCode: 'int',
              isEnum: false,
              nullable: false,
              unique: false,
              isPk: false,
              autoIncrement: false,
              uuid: false,
              defaultLiteral: '0',
            ),
            GenColumn(
              name: 'status',
              prop: 'status',
              type: ColumnType.text,
              dartTypeCode: 'OrderStatus',
              enumTypeName: 'OrderStatus',
              isEnum: true,
              nullable: false,
              unique: false,
              isPk: false,
              autoIncrement: false,
              uuid: false,
            ),
            GenColumn(
              name: 'created_at',
              prop: 'createdAt',
              type: ColumnType.dateTime,
              dartTypeCode: 'DateTime?',
              isEnum: false,
              nullable: true,
              unique: false,
              isPk: false,
              autoIncrement: false,
              uuid: false,
              isCreatedAt: true,
            ),
          ],
          queries: [],
          relations: [
            GenRelation(
              fieldName: 'customer',
              type: RelationKind.manyToOne,
              targetTypeCode: 'Customer',
              isOwningSide: true,
              mappedBy: null,
              fetchLiteral: 'RelationFetchStrategy.lazy',
              cascadeLiteral: 'const [Cascade.persist]',
              cascadePersist: true,
              cascadeMerge: false,
              cascadeRemove: false,
              joinColumn: GenJoinColumn(
                name: 'customer_id',
                referencedColumnName: 'id',
                nullable: false,
                unique: false,
              ),
              joinColumnPropertyName: 'customerId',
              joinColumnBaseDartType: 'int',
              joinColumnNullable: false,
            ),
            GenRelation(
              fieldName: 'items',
              type: RelationKind.oneToMany,
              targetTypeCode: 'OrderItem',
              isOwningSide: false,
              mappedBy: 'order',
              fetchLiteral: 'RelationFetchStrategy.lazy',
              cascadeLiteral: 'const [Cascade.persist]',
              cascadePersist: true,
              cascadeMerge: false,
              cascadeRemove: false,
              isCollection: true,
            ),
          ],
        );

        final code = _emitClass(builder.build(context));

        expect(
          code,
          contains('factory OrderInsertDto.fromMap(Map<String, dynamic> map)'),
        );
        expect(
          code,
          contains(
            "attempts: map.containsKey('attempts') ? map['attempts'] as int : 0",
          ),
        );
        expect(
          code,
          contains(
            "status: OrderStatus.values.byName(map['status'] as String)",
          ),
        );
        expect(code, contains("createdAt: map['created_at'] == null ? null"));
        expect(code, contains("DateTime.parse(map['created_at'].toString())"));
        expect(code, contains("customerId: map['customer_id'] as int"));
        expect(
          code,
          contains(
            'OrderItemInsertDto.fromMap((entry as Map).cast<String, dynamic>())',
          ),
        );
      });

      test('generates json decoding with a non-null cast receiver', () {
        final context = EntityGenerationContext(
          className: 'Movie',
          tableName: 'movies',
          columns: [
            GenColumn(
              name: 'genres',
              prop: 'genres',
              type: ColumnType.json,
              dartTypeCode: 'List<String>',
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

        final code = _emitClass(builder.build(context));

        expect(
          code,
          contains(
            "genres: ((map['genres'] is String ? decodeJsonColumn(map['genres']) : map['genres']) as List).cast<String>()",
          ),
        );
      });

      test('uses custom enum value accessors for text-backed enums', () {
        final context = EntityGenerationContext(
          className: 'Order',
          tableName: 'orders',
          columns: [
            GenColumn(
              name: 'status',
              prop: 'status',
              type: ColumnType.text,
              dartTypeCode: 'OrderStatus',
              isEnum: true,
              enumTypeName: 'OrderStatus',
              enumValueAccessor: 'value',
              nullable: false,
              unique: false,
              isPk: false,
              autoIncrement: false,
              uuid: false,
              defaultLiteral: 'OrderStatus.pending',
            ),
          ],
          queries: [],
          relations: [],
        );

        final code = _emitClass(builder.build(context));

        expect(
          code,
          contains(
            "status: map.containsKey('status') ? OrderStatus.values.firstWhere((entry) => entry.value == (map['status'] as String)) : OrderStatus.pending",
          ),
        );
        expect(code, contains("'status': status.value"));
        expect(code, contains('this.status = OrderStatus.pending'));
      });
    });

    group('Foreign Key copyWith handling', () {
      test('Non-nullable FK in copyWith is nullable', () {
        // @ManyToOne with @JoinColumn(nullable: false)
        final context = EntityGenerationContext(
          className: 'TodoModel',
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
              targetTypeCode: 'UserModel',
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

        final dtoClass = builder.build(context);

        // Find the copyWith method
        final copyWithMethod = dtoClass.methods.firstWhere(
          (m) => m.name == 'copyWith',
        );

        // Verify the ownerId parameter is nullable
        final ownerIdParam = copyWithMethod.optionalParameters.firstWhere(
          (p) => p.name == 'ownerId',
        );

        // The parameter type should be int? (nullable)
        expect(
          ownerIdParam.type?.symbol,
          'int?',
          reason: 'copyWith parameter for non-nullable FK should be nullable',
        );

        // Verify the field itself is still non-nullable
        final ownerIdField = dtoClass.fields.firstWhere(
          (f) => f.name == 'ownerId',
        );
        expect(
          ownerIdField.type?.symbol,
          'int',
          reason: 'Field should remain non-nullable',
        );

        // Verify constructor still requires the parameter
        final constructor = dtoClass.constructors.first;
        final ownerIdCtorParam = constructor.optionalParameters.firstWhere(
          (p) => p.name == 'ownerId',
        );
        expect(
          ownerIdCtorParam.required,
          isTrue,
          reason: 'Constructor should still require the parameter',
        );
      });

      test('copyWith can be used for selective updates', () {
        final context = EntityGenerationContext(
          className: 'TodoModel',
          tableName: 'todos',
          columns: [
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
              targetTypeCode: 'UserModel',
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

        final dtoClass = builder.build(context);

        // All copyWith parameters should be nullable
        final copyWithMethod = dtoClass.methods.firstWhere(
          (m) => m.name == 'copyWith',
        );

        for (final param in copyWithMethod.optionalParameters) {
          final typeSymbol = param.type?.symbol ?? '';
          expect(
            typeSymbol.endsWith('?'),
            isTrue,
            reason: 'Parameter ${param.name} should be nullable in copyWith',
          );
        }
      });
    });
  });

  group('UpdateDtoBuilder', () {
    test('generates a fromMap factory for update cascades', () {
      final builder = const UpdateDtoBuilder();
      final context = EntityGenerationContext(
        className: 'Post',
        tableName: 'posts',
        columns: [
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
            fieldName: 'tags',
            type: RelationKind.manyToMany,
            targetTypeCode: 'Tag',
            isOwningSide: true,
            mappedBy: null,
            fetchLiteral: 'RelationFetchStrategy.lazy',
            cascadeLiteral: 'const [Cascade.merge]',
            cascadePersist: false,
            cascadeMerge: true,
            cascadeRemove: false,
            isCollection: true,
          ),
        ],
      );

      final code = _emitClass(builder.build(context));

      expect(
        code,
        contains('factory PostUpdateDto.fromMap(Map<String, dynamic> map)'),
      );
      expect(
        code,
        contains("title: map['title'] == null ? null : map['title'] as String"),
      );
      expect(
        code,
        contains(
          'TagUpdateDto.fromMap((entry as Map).cast<String, dynamic>())',
        ),
      );
    });
  });
}

String _emitClass(Class clazz) {
  return clazz.accept(DartEmitter(useNullSafetySyntax: true)).toString();
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
