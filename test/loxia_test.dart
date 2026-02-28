import 'package:loxia/loxia.dart';
import 'package:loxia/src/migrations/schema.dart';
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

  group('EntityRepository.findBy relations hydration', () {
    test('hydrates relation when relations are requested', () async {
      final engine = _RepoFakeEngine(
        rows: [
          {
            'id': 1,
            'name': 'Downtown',
            'merchant_id': 10,
            'merchant_name': 'Acme',
          },
        ],
      );
      final descriptor = _buildStoreDescriptor();
      final repository = EntityRepository<_StoreEntity, _StorePartial>(
        descriptor,
        engine,
        const _StoreFields(),
      );

      final stores = await repository.findBy(
        where: QueryBuilder<_StoreEntity>.from(
          (q) => q.field<int>('merchant_id').equals(10),
        ),
        relations: const _StoreRelations(
          merchant: _MerchantSelect(id: true, name: true),
        ),
      );

      expect(stores, hasLength(1));
      expect(stores.first.name, 'Downtown');
      expect(stores.first.merchant?.id, 10);
      expect(stores.first.merchant?.name, 'Acme');
      expect(engine.lastSql, contains('LEFT JOIN "merchants" AS "t_merchant"'));
      expect(engine.lastParams, [10]);
    });

    test('findOneBy forwards relations and hydrates relation', () async {
      final engine = _RepoFakeEngine(
        rows: [
          {
            'id': 2,
            'name': 'Airport',
            'merchant_id': 11,
            'merchant_name': 'Sky Trade',
          },
        ],
      );
      final descriptor = _buildStoreDescriptor();
      final repository = EntityRepository<_StoreEntity, _StorePartial>(
        descriptor,
        engine,
        const _StoreFields(),
      );

      final store = await repository.findOneBy(
        where: QueryBuilder<_StoreEntity>.from(
          (q) => q.field<int>('id').equals(2),
        ),
        relations: const _StoreRelations(
          merchant: _MerchantSelect(id: true, name: true),
        ),
      );

      expect(store != null, isTrue);
      expect(store?.merchant?.name, 'Sky Trade');
      expect(engine.lastSql, contains('LIMIT 1'));
      expect(engine.lastParams, [2]);
    });

    test('keeps legacy findBy behavior when withSelect is omitted', () async {
      final engine = _RepoFakeEngine(
        rows: [
          {'id': 3, 'name': 'Old Path', 'merchant_id': 99},
        ],
      );
      final descriptor = _buildStoreDescriptor();
      final repository = EntityRepository<_StoreEntity, _StorePartial>(
        descriptor,
        engine,
        const _StoreFields(),
      );

      final stores = await repository.findBy(
        where: QueryBuilder<_StoreEntity>.from(
          (q) => q.field<int>('id').equals(3),
        ),
      );

      expect(stores, hasLength(1));
      expect(stores.first.id, 3);
      expect(stores.first.merchant == null, isTrue);
      expect(engine.lastSql, isNot(contains('LEFT JOIN merchants')));
    });
  });

  group('EntityRepository soft delete filtering', () {
    test('find adds deleted_at IS NULL by default', () async {
      final engine = _RepoFakeEngine(
        rows: [
          {'id': 1, 'name': 'Visible', 'merchant_id': null},
        ],
      );
      final descriptor = _buildStoreDescriptorWithDeletedAt();
      final repository = EntityRepository<_StoreEntity, _StorePartial>(
        descriptor,
        engine,
        const _StoreFields(),
      );

      final stores = await repository.find();

      expect(stores, hasLength(1));
      expect(engine.lastSql, contains('"t"."deleted_at" IS NULL'));
    });

    test('findOne includeDeleted bypasses deleted_at filter', () async {
      final engine = _RepoFakeEngine(
        rows: [
          {'id': 2, 'name': 'Deleted', 'merchant_id': null},
        ],
      );
      final descriptor = _buildStoreDescriptorWithDeletedAt();
      final repository = EntityRepository<_StoreEntity, _StorePartial>(
        descriptor,
        engine,
        const _StoreFields(),
      );

      final store = await repository.findOne(includeDeleted: true);

      expect(store != null, isTrue);
      expect(engine.lastSql, isNot(contains('"t"."deleted_at" IS NULL')));
    });

    test(
      'findBy/findOneBy add filter by default and support includeDeleted',
      () async {
        final engine = _RepoFakeEngine(
          rows: [
            {'id': 3, 'name': 'Filtered', 'merchant_id': null},
          ],
        );
        final descriptor = _buildStoreDescriptorWithDeletedAt();
        final repository = EntityRepository<_StoreEntity, _StorePartial>(
          descriptor,
          engine,
          const _StoreFields(),
        );

        await repository.findBy();
        expect(engine.lastSql, contains('"t"."deleted_at" IS NULL'));

        await repository.findOneBy(includeDeleted: true);
        expect(engine.lastSql, isNot(contains('"t"."deleted_at" IS NULL')));
      },
    );

    test('paginate applies includeDeleted to count and page queries', () async {
      final engine = _RepoFakeEngine(
        rows: const [],
        queryResponses: [
          [
            {'c': 1},
          ],
          [
            {'id': 4, 'name': 'Row', 'merchant_id': null},
          ],
          [
            {'c': 1},
          ],
          [
            {'id': 4, 'name': 'Row', 'merchant_id': null},
          ],
        ],
      );
      final descriptor = _buildStoreDescriptorWithDeletedAt();
      final repository = EntityRepository<_StoreEntity, _StorePartial>(
        descriptor,
        engine,
        const _StoreFields(),
      );

      final result = await repository.paginate(page: 1, pageSize: 10);

      expect(result.total, 1);
      expect(engine.queryHistory, hasLength(2));
      expect(engine.queryHistory.first, contains('"t"."deleted_at" IS NULL'));
      expect(engine.queryHistory.last, contains('"t"."deleted_at" IS NULL'));

      await repository.paginate(page: 1, pageSize: 10, includeDeleted: true);
      expect(engine.queryHistory, hasLength(4));
      expect(
        engine.queryHistory[2],
        isNot(contains('"t"."deleted_at" IS NULL')),
      );
      expect(
        engine.queryHistory[3],
        isNot(contains('"t"."deleted_at" IS NULL')),
      );
    });

    test('softDelete updates DeletedAt column for matching rows', () async {
      final engine = _RepoFakeEngine(rows: const [], executeResult: 2);
      final descriptor = _buildStoreDescriptorWithDeletedAt();
      final repository = EntityRepository<_StoreEntity, _StorePartial>(
        descriptor,
        engine,
        const _StoreFields(),
      );

      final deleted = await repository.softDelete(
        QueryBuilder<_StoreEntity>.from((q) => q.field<int>('id').equals(1)),
      );

      expect(deleted, 2);
      expect(engine.executeHistory, isNotEmpty);
      expect(
        engine.executeHistory.first,
        contains(
          'UPDATE stores AS "t" SET "deleted_at" = ? WHERE "t"."id" = ?',
        ),
      );
      expect(engine.executeParamsHistory.first.length, 2);
      expect(engine.executeParamsHistory.first[1], 1);
    });

    test('softDeleteEntities soft deletes each entity', () async {
      final engine = _RepoFakeEngine(rows: const []);
      final descriptor = _buildStoreDescriptorWithDeletedAt();
      final repository = EntityRepository<_StoreEntity, _StorePartial>(
        descriptor,
        engine,
        const _StoreFields(),
      );

      await repository.softDeleteEntities([
        _StoreEntity(id: 10, name: 'A', merchant: null),
        _StoreEntity(id: 11, name: 'B', merchant: null),
      ]);

      expect(engine.executeHistory.length, 2);
      expect(
        engine.executeHistory[0],
        contains('UPDATE stores SET "deleted_at" = ? WHERE "id" = ?'),
      );
      expect(engine.executeParamsHistory[0][1], 10);
      expect(engine.executeParamsHistory[1][1], 11);
    });
  });

  group('EntityRepository.save boolean mapping', () {
    test(
      'returns updated boolean value when update RETURNING row contains bool',
      () async {
        final engine = _RepoFakeEngine(
          rows: const [],
          queryResponses: [
            [
              {'id': 1, 'is_active': true},
            ],
          ],
        );
        final descriptor = _buildLegacyBoolDescriptor();
        final repository =
            EntityRepository<_LegacyBoolEntity, _LegacyBoolPartial>(
              descriptor,
              engine,
              const _LegacyBoolFields(),
            );

        final updated = await repository.save(
          const _LegacyBoolPartial(id: 1, isActive: true),
        );

        expect(updated.isActive, isTrue);
      },
    );
  });
}

EntityDescriptor<_StoreEntity, _StorePartial> _buildStoreDescriptor() {
  late final EntityDescriptor<_StoreEntity, _StorePartial> descriptor;
  descriptor = EntityDescriptor<_StoreEntity, _StorePartial>(
    entityType: _StoreEntity,
    tableName: 'stores',
    columns: [
      ColumnDescriptor(
        name: 'id',
        propertyName: 'id',
        type: ColumnType.integer,
        isPrimaryKey: true,
      ),
      ColumnDescriptor(
        name: 'name',
        propertyName: 'name',
        type: ColumnType.text,
      ),
      ColumnDescriptor(
        name: 'merchant_id',
        propertyName: 'merchant',
        type: ColumnType.integer,
        nullable: true,
      ),
    ],
    relations: const [
      RelationDescriptor(
        fieldName: 'merchant',
        type: RelationType.manyToOne,
        target: _MerchantEntity,
        isOwningSide: true,
        joinColumn: JoinColumnDescriptor(
          name: 'merchant_id',
          referencedColumnName: 'id',
        ),
      ),
    ],
    fromRow: (row) => _StoreEntity(
      id: row['id'] as int,
      name: row['name'] as String,
      merchant: null,
    ),
    toRow: (entity) => {
      'id': entity.id,
      'name': entity.name,
      'merchant_id': entity.merchant?.id,
    },
    fieldsContext: const _StoreFields(),
    repositoryFactory: (engine) =>
        EntityRepository<_StoreEntity, _StorePartial>(
          descriptor,
          engine,
          const _StoreFields(),
        ),
    defaultSelect: () => const _StoreSelect(id: true, name: true),
  );
  return descriptor;
}

EntityDescriptor<_StoreEntity, _StorePartial>
_buildStoreDescriptorWithDeletedAt() {
  late final EntityDescriptor<_StoreEntity, _StorePartial> descriptor;
  descriptor = EntityDescriptor<_StoreEntity, _StorePartial>(
    entityType: _StoreEntity,
    tableName: 'stores',
    columns: [
      ColumnDescriptor(
        name: 'id',
        propertyName: 'id',
        type: ColumnType.integer,
        isPrimaryKey: true,
      ),
      ColumnDescriptor(
        name: 'name',
        propertyName: 'name',
        type: ColumnType.text,
      ),
      ColumnDescriptor(
        name: 'merchant_id',
        propertyName: 'merchant',
        type: ColumnType.integer,
        nullable: true,
      ),
      ColumnDescriptor(
        name: 'deleted_at',
        propertyName: 'deletedAt',
        type: ColumnType.dateTime,
        nullable: true,
        isDeletedAt: true,
      ),
    ],
    relations: const [
      RelationDescriptor(
        fieldName: 'merchant',
        type: RelationType.manyToOne,
        target: _MerchantEntity,
        isOwningSide: true,
        joinColumn: JoinColumnDescriptor(
          name: 'merchant_id',
          referencedColumnName: 'id',
        ),
      ),
    ],
    fromRow: (row) => _StoreEntity(
      id: row['id'] as int,
      name: row['name'] as String,
      merchant: null,
    ),
    toRow: (entity) => {
      'id': entity.id,
      'name': entity.name,
      'merchant_id': entity.merchant?.id,
      'deleted_at': null,
    },
    fieldsContext: const _StoreFields(),
    repositoryFactory: (engine) =>
        EntityRepository<_StoreEntity, _StorePartial>(
          descriptor,
          engine,
          const _StoreFields(),
        ),
    defaultSelect: () => const _StoreSelect(id: true, name: true),
  );
  return descriptor;
}

EntityDescriptor<_LegacyBoolEntity, _LegacyBoolPartial>
_buildLegacyBoolDescriptor() {
  late final EntityDescriptor<_LegacyBoolEntity, _LegacyBoolPartial> descriptor;
  descriptor = EntityDescriptor<_LegacyBoolEntity, _LegacyBoolPartial>(
    entityType: _LegacyBoolEntity,
    tableName: 'legacy_bool_entities',
    columns: [
      ColumnDescriptor(
        name: 'id',
        propertyName: 'id',
        type: ColumnType.integer,
        isPrimaryKey: true,
      ),
      ColumnDescriptor(
        name: 'is_active',
        propertyName: 'isActive',
        type: ColumnType.boolean,
      ),
    ],
    fromRow: (row) => _LegacyBoolEntity(
      id: row['id'] as int,
      isActive: row['is_active'] == 1,
    ),
    toRow: (entity) => {'id': entity.id, 'is_active': entity.isActive},
    fieldsContext: const _LegacyBoolFields(),
    repositoryFactory: (engine) =>
        EntityRepository<_LegacyBoolEntity, _LegacyBoolPartial>(
          descriptor,
          engine,
          const _LegacyBoolFields(),
        ),
  );
  return descriptor;
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

  @override
  Map<String, dynamic> toJson() {
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

class _StoreEntity extends Entity {
  _StoreEntity({required this.id, required this.name, this.merchant});

  final int id;
  final String name;
  final _MerchantEntity? merchant;
}

class _MerchantEntity extends Entity {
  _MerchantEntity({required this.id, required this.name});

  final int id;
  final String name;
}

class _LegacyBoolEntity extends Entity {
  _LegacyBoolEntity({required this.id, required this.isActive});

  final int id;
  final bool isActive;
}

class _LegacyBoolPartial extends PartialEntity<_LegacyBoolEntity> {
  const _LegacyBoolPartial({this.id, this.isActive});

  final int? id;
  final bool? isActive;

  @override
  Object? get primaryKeyValue => id;

  @override
  _LegacyBoolEntity toEntity() {
    if (id == null || isActive == null) {
      throw StateError('Missing required fields for _LegacyBoolEntity');
    }
    return _LegacyBoolEntity(id: id!, isActive: isActive!);
  }

  @override
  InsertDto<_LegacyBoolEntity> toInsertDto() {
    if (isActive == null) {
      throw StateError('Missing required fields for _LegacyBoolInsertDto');
    }
    return _LegacyBoolInsertDto(isActive: isActive!);
  }

  @override
  UpdateDto<_LegacyBoolEntity> toUpdateDto() {
    if (isActive == null) {
      throw StateError('Missing required fields for _LegacyBoolUpdateDto');
    }
    return _LegacyBoolUpdateDto(isActive: isActive!);
  }

  @override
  Map<String, dynamic> toJson() => {'id': id, 'isActive': isActive};
}

class _LegacyBoolInsertDto extends InsertDto<_LegacyBoolEntity> {
  _LegacyBoolInsertDto({required this.isActive});

  final bool isActive;

  @override
  Map<String, dynamic> toMap() => {'is_active': isActive};
}

class _LegacyBoolUpdateDto extends UpdateDto<_LegacyBoolEntity> {
  _LegacyBoolUpdateDto({required this.isActive});

  final bool isActive;

  @override
  Map<String, dynamic> toMap() => {'is_active': isActive};
}

class _StorePartial extends PartialEntity<_StoreEntity> {
  const _StorePartial({this.id, this.name, this.merchant});

  final int? id;
  final String? name;
  final _MerchantPartial? merchant;

  @override
  Object? get primaryKeyValue => id;

  @override
  _StoreEntity toEntity() {
    if (id == null || name == null) {
      throw StateError('Missing required fields for _StoreEntity');
    }
    return _StoreEntity(id: id!, name: name!, merchant: merchant?.toEntity());
  }

  @override
  InsertDto<_StoreEntity> toInsertDto() {
    throw UnimplementedError();
  }

  @override
  UpdateDto<_StoreEntity> toUpdateDto() {
    throw UnimplementedError();
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'merchant': merchant?.toJson(),
  };
}

class _MerchantPartial extends PartialEntity<_MerchantEntity> {
  const _MerchantPartial({this.id, this.name});

  final int? id;
  final String? name;

  @override
  Object? get primaryKeyValue => id;

  @override
  _MerchantEntity toEntity() {
    if (id == null || name == null) {
      throw StateError('Missing required fields for _MerchantEntity');
    }
    return _MerchantEntity(id: id!, name: name!);
  }

  @override
  InsertDto<_MerchantEntity> toInsertDto() {
    throw UnimplementedError();
  }

  @override
  UpdateDto<_MerchantEntity> toUpdateDto() {
    throw UnimplementedError();
  }

  @override
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class _StoreFields extends QueryFieldsContext<_StoreEntity> {
  const _StoreFields([super.runtime, super.alias]);

  @override
  _StoreFields bind(QueryRuntimeContext runtime, String alias) =>
      _StoreFields(runtime, alias);

  QueryField<int> get id => field<int>('id');

  QueryField<String> get name => field<String>('name');

  QueryField<int?> get merchantId => field<int?>('merchant_id');

  _MerchantFields get merchant {
    final relAlias = ensureRelationJoin(
      relationName: 'merchant',
      targetTableName: 'merchants',
      localColumn: 'merchant_id',
      foreignColumn: 'id',
    );
    return _MerchantFields(runtimeOrThrow, relAlias);
  }
}

class _MerchantFields extends QueryFieldsContext<_StoreEntity> {
  const _MerchantFields([super.runtime, super.alias]);

  @override
  _MerchantFields bind(QueryRuntimeContext runtime, String alias) =>
      _MerchantFields(runtime, alias);

  QueryField<int> get id => field<int>('id');

  QueryField<String> get name => field<String>('name');
}

class _LegacyBoolFields extends QueryFieldsContext<_LegacyBoolEntity> {
  const _LegacyBoolFields([super.runtime, super.alias]);

  @override
  _LegacyBoolFields bind(QueryRuntimeContext runtime, String alias) =>
      _LegacyBoolFields(runtime, alias);

  QueryField<int> get id => field<int>('id');

  QueryField<bool> get isActive => field<bool>('is_active');
}

class _StoreSelect extends SelectOptions<_StoreEntity, _StorePartial> {
  const _StoreSelect({this.id = false, this.name = false, this.relations});

  final bool id;
  final bool name;
  final _StoreRelations? relations;

  @override
  SelectOptions<_StoreEntity, _StorePartial> withRelations(
    RelationsOptions<_StoreEntity, _StorePartial>? relations,
  ) {
    return _StoreSelect(
      id: id,
      name: name,
      relations: relations as _StoreRelations?,
    );
  }

  @override
  bool get hasSelections => id || name || (relations?.hasSelections ?? false);

  @override
  void collect(
    QueryFieldsContext<_StoreEntity> context,
    List<SelectField> out, {
    String? path,
  }) {
    if (context is! _StoreFields) {
      throw ArgumentError('Expected _StoreFields for _StoreSelect');
    }
    final tableAlias = context.currentAlias;
    if (id) {
      out.add(
        SelectField(
          'id',
          tableAlias: tableAlias,
          alias: composeAlias(path, 'id'),
        ),
      );
    }
    if (name) {
      out.add(
        SelectField(
          'name',
          tableAlias: tableAlias,
          alias: composeAlias(path, 'name'),
        ),
      );
    }
    final selectedRelations = relations;
    if (selectedRelations != null && selectedRelations.hasSelections) {
      selectedRelations.collect(context, out, path: path);
    }
  }

  @override
  _StorePartial hydrate(Map<String, dynamic> row, {String? path}) {
    final selectedRelations = relations;
    _MerchantPartial? merchantPartial;
    if (selectedRelations?.merchant != null) {
      final relationPath = extendPath(path, 'merchant');
      final merchantId = selectedRelations!.merchant!.readValue(
        row,
        'id',
        path: relationPath,
      );
      if (merchantId != null) {
        merchantPartial = selectedRelations.merchant!.hydrate(
          row,
          path: relationPath,
        );
      }
    }
    return _StorePartial(
      id: readValue(row, 'id', path: path) as int?,
      name: readValue(row, 'name', path: path) as String?,
      merchant: merchantPartial,
    );
  }
}

class _StoreRelations extends RelationsOptions<_StoreEntity, _StorePartial> {
  const _StoreRelations({this.merchant});

  final _MerchantSelect? merchant;

  @override
  bool get hasSelections => merchant?.hasSelections ?? false;

  @override
  void collect(
    QueryFieldsContext<_StoreEntity> context,
    List<SelectField> out, {
    String? path,
  }) {
    if (context is! _StoreFields) {
      throw ArgumentError('Expected _StoreFields for _StoreRelations');
    }
    final merchantSelect = merchant;
    if (merchantSelect != null && merchantSelect.hasSelections) {
      final relationPath = merchantSelect.extendPath(path, 'merchant');
      merchantSelect.collect(context.merchant, out, path: relationPath);
    }
  }
}

class _MerchantSelect extends SelectOptions<_StoreEntity, _MerchantPartial> {
  const _MerchantSelect({this.id = false, this.name = false});

  final bool id;
  final bool name;

  @override
  bool get hasSelections => id || name;

  @override
  void collect(
    QueryFieldsContext<_StoreEntity> context,
    List<SelectField> out, {
    String? path,
  }) {
    if (context is! _MerchantFields) {
      throw ArgumentError('Expected _MerchantFields for _MerchantSelect');
    }
    final tableAlias = context.currentAlias;
    if (id) {
      out.add(
        SelectField(
          'id',
          tableAlias: tableAlias,
          alias: composeAlias(path, 'id'),
        ),
      );
    }
    if (name) {
      out.add(
        SelectField(
          'name',
          tableAlias: tableAlias,
          alias: composeAlias(path, 'name'),
        ),
      );
    }
  }

  @override
  _MerchantPartial hydrate(Map<String, dynamic> row, {String? path}) {
    return _MerchantPartial(
      id: readValue(row, 'id', path: path) as int?,
      name: readValue(row, 'name', path: path) as String?,
    );
  }
}

class _RepoFakeEngine implements EngineAdapter {
  _RepoFakeEngine({
    required this.rows,
    this.queryResponses,
    this.executeResult = 0,
  });

  final List<Map<String, dynamic>> rows;
  final List<List<Map<String, dynamic>>>? queryResponses;
  final int executeResult;
  String? lastSql;
  List<Object?> lastParams = const [];
  final List<String> queryHistory = [];
  final List<String> executeHistory = [];
  final List<List<Object?>> executeParamsHistory = [];
  int _queryIndex = 0;

  @override
  bool get supportsAlterTableAddConstraint => true;

  @override
  String placeholderFor(int index) => '?';

  @override
  Future<void> open() async {}

  @override
  Future<void> close() async {}

  @override
  Future<SchemaState> readSchema() async => SchemaState.empty();

  @override
  Future<void> executeBatch(List<ParameterizedQuery> statements) async {}

  @override
  Future<List<Map<String, dynamic>>> query(
    String sql, [
    List<Object?> params = const [],
  ]) async {
    lastSql = sql;
    lastParams = params;
    queryHistory.add(sql);
    if (queryResponses != null && _queryIndex < queryResponses!.length) {
      final response = queryResponses![_queryIndex];
      _queryIndex += 1;
      return response;
    }
    return rows;
  }

  @override
  Future<int> execute(String sql, [List<Object?> params = const []]) async {
    lastSql = sql;
    lastParams = params;
    executeHistory.add(sql);
    executeParamsHistory.add(params);
    return executeResult;
  }

  @override
  Future<T> transaction<T>(Future<T> Function(EngineAdapter txEngine) action) {
    return action(this);
  }

  @override
  Future<void> ensureHistoryTable() async {}

  @override
  Future<List<int>> getAppliedVersions() async => const [];
}
