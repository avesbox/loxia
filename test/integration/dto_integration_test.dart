@TestOn('vm')
library;

import 'package:loxia/loxia.dart';
import 'package:loxia/src/generator/builders/dto_builders.dart';
import 'package:loxia/src/generator/builders/models.dart';
import 'package:test/test.dart';

/// Integration-style tests that verify the fix for issue #4
/// by testing the actual builder output instead of using build_test
void main() {
  group('Issue #4 Fix Verification', () {
    final builder = const InsertDtoBuilder();

    test('Non-nullable FK in copyWith is nullable (issue #4)', () {
      // This reproduces the exact scenario from issue #4:
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
              nullable: false, // This is the key: nullable=false
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

      // Verify the ownerId parameter is nullable (the fix!)
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
      // This test demonstrates that copyWith now works correctly
      // for selective updates of DTO fields
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
}
