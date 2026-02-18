// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'loxia_codegen_example.dart';

// **************************************************************************
// LoxiaEntityGenerator
// **************************************************************************

final EntityDescriptor<Merchant, MerchantPartial> $MerchantEntityDescriptor =
    () {
      $initMerchantJsonCodec();
      return EntityDescriptor(
        entityType: Merchant,
        tableName: 'merchants',
        columns: [
          ColumnDescriptor(
            name: 'id',
            propertyName: 'id',
            type: ColumnType.uuid,
            nullable: false,
            unique: false,
            isPrimaryKey: true,
            autoIncrement: false,
            uuid: true,
            isDeletedAt: false,
          ),
          ColumnDescriptor(
            name: 'name',
            propertyName: 'name',
            type: ColumnType.text,
            nullable: false,
            unique: false,
            isPrimaryKey: false,
            autoIncrement: false,
            uuid: false,
            isDeletedAt: false,
          ),
          ColumnDescriptor(
            name: 'business_name',
            propertyName: 'businessName',
            type: ColumnType.text,
            nullable: false,
            unique: false,
            isPrimaryKey: false,
            autoIncrement: false,
            uuid: false,
            isDeletedAt: false,
          ),
          ColumnDescriptor(
            name: 'mobile_number',
            propertyName: 'mobileNumber',
            type: ColumnType.text,
            nullable: false,
            unique: true,
            isPrimaryKey: false,
            autoIncrement: false,
            uuid: false,
            isDeletedAt: false,
          ),
          ColumnDescriptor(
            name: 'email',
            propertyName: 'email',
            type: ColumnType.text,
            nullable: false,
            unique: true,
            isPrimaryKey: false,
            autoIncrement: false,
            uuid: false,
            isDeletedAt: false,
          ),
          ColumnDescriptor(
            name: 'password_hash',
            propertyName: 'passwordHash',
            type: ColumnType.text,
            nullable: false,
            unique: false,
            isPrimaryKey: false,
            autoIncrement: false,
            uuid: false,
            isDeletedAt: false,
          ),
          ColumnDescriptor(
            name: 'created_at',
            propertyName: 'createdAt',
            type: ColumnType.dateTime,
            nullable: true,
            unique: false,
            isPrimaryKey: false,
            autoIncrement: false,
            uuid: false,
            isDeletedAt: false,
          ),
          ColumnDescriptor(
            name: 'updated_at',
            propertyName: 'updatedAt',
            type: ColumnType.dateTime,
            nullable: true,
            unique: false,
            isPrimaryKey: false,
            autoIncrement: false,
            uuid: false,
            isDeletedAt: false,
          ),
        ],
        relations: const [],
        fromRow: (row) => Merchant(
          id: (row['id'] as String),
          name: (row['name'] as String),
          businessName: (row['business_name'] as String),
          mobileNumber: (row['mobile_number'] as String),
          email: (row['email'] as String),
          passwordHash: (row['password_hash'] as String),
          createdAt: row['created_at'] == null
              ? null
              : row['created_at'] is String
              ? DateTime.parse(row['created_at'].toString())
              : row['created_at'] as DateTime,
          updatedAt: row['updated_at'] == null
              ? null
              : row['updated_at'] is String
              ? DateTime.parse(row['updated_at'].toString())
              : row['updated_at'] as DateTime,
        ),
        toRow: (e) => {
          'id': e.id,
          'name': e.name,
          'business_name': e.businessName,
          'mobile_number': e.mobileNumber,
          'email': e.email,
          'password_hash': e.passwordHash,
          'created_at': e.createdAt?.toIso8601String(),
          'updated_at': e.updatedAt?.toIso8601String(),
        },
        fieldsContext: const MerchantFieldsContext(),
        repositoryFactory: (EngineAdapter engine) => MerchantRepository(engine),
        hooks: EntityHooks<Merchant>(
          prePersist: (e) {
            e.createdAt = DateTime.now();
            e.updatedAt = DateTime.now();
          },
          preUpdate: (e) {
            e.updatedAt = DateTime.now();
          },
        ),
        defaultSelect: () => MerchantSelect(),
      );
    }();

class MerchantFieldsContext extends QueryFieldsContext<Merchant> {
  const MerchantFieldsContext([super.runtimeContext, super.alias]);

  @override
  MerchantFieldsContext bind(
    QueryRuntimeContext runtimeContext,
    String alias,
  ) => MerchantFieldsContext(runtimeContext, alias);

  QueryField<String> get id => field<String>('id');

  QueryField<String> get name => field<String>('name');

  QueryField<String> get businessName => field<String>('business_name');

  QueryField<String> get mobileNumber => field<String>('mobile_number');

  QueryField<String> get email => field<String>('email');

  QueryField<String> get passwordHash => field<String>('password_hash');

  QueryField<DateTime?> get createdAt => field<DateTime?>('created_at');

  QueryField<DateTime?> get updatedAt => field<DateTime?>('updated_at');
}

class MerchantQuery extends QueryBuilder<Merchant> {
  const MerchantQuery(this._builder);

  final WhereExpression Function(MerchantFieldsContext) _builder;

  @override
  WhereExpression build(QueryFieldsContext<Merchant> context) {
    if (context is! MerchantFieldsContext) {
      throw ArgumentError('Expected MerchantFieldsContext for MerchantQuery');
    }
    return _builder(context);
  }
}

class MerchantSelect extends SelectOptions<Merchant, MerchantPartial> {
  const MerchantSelect({
    this.id = true,
    this.name = true,
    this.businessName = true,
    this.mobileNumber = true,
    this.email = true,
    this.passwordHash = true,
    this.createdAt = true,
    this.updatedAt = true,
    this.relations,
  });

  final bool id;

  final bool name;

  final bool businessName;

  final bool mobileNumber;

  final bool email;

  final bool passwordHash;

  final bool createdAt;

  final bool updatedAt;

  final MerchantRelations? relations;

  @override
  bool get hasSelections =>
      id ||
      name ||
      businessName ||
      mobileNumber ||
      email ||
      passwordHash ||
      createdAt ||
      updatedAt ||
      (relations?.hasSelections ?? false);

  @override
  SelectOptions<Merchant, MerchantPartial> withRelations(
    RelationsOptions<Merchant, MerchantPartial>? relations,
  ) {
    return MerchantSelect(
      id: id,
      name: name,
      businessName: businessName,
      mobileNumber: mobileNumber,
      email: email,
      passwordHash: passwordHash,
      createdAt: createdAt,
      updatedAt: updatedAt,
      relations: relations as MerchantRelations?,
    );
  }

  @override
  void collect(
    QueryFieldsContext<Merchant> context,
    List<SelectField> out, {
    String? path,
  }) {
    if (context is! MerchantFieldsContext) {
      throw ArgumentError('Expected MerchantFieldsContext for MerchantSelect');
    }
    final MerchantFieldsContext scoped = context;
    String? aliasFor(String column) {
      final current = path;
      if (current == null || current.isEmpty) return null;
      return '${current}_$column';
    }

    final tableAlias = scoped.currentAlias;
    if (id) {
      out.add(SelectField('id', tableAlias: tableAlias, alias: aliasFor('id')));
    }
    if (name) {
      out.add(
        SelectField('name', tableAlias: tableAlias, alias: aliasFor('name')),
      );
    }
    if (businessName) {
      out.add(
        SelectField(
          'business_name',
          tableAlias: tableAlias,
          alias: aliasFor('business_name'),
        ),
      );
    }
    if (mobileNumber) {
      out.add(
        SelectField(
          'mobile_number',
          tableAlias: tableAlias,
          alias: aliasFor('mobile_number'),
        ),
      );
    }
    if (email) {
      out.add(
        SelectField('email', tableAlias: tableAlias, alias: aliasFor('email')),
      );
    }
    if (passwordHash) {
      out.add(
        SelectField(
          'password_hash',
          tableAlias: tableAlias,
          alias: aliasFor('password_hash'),
        ),
      );
    }
    if (createdAt) {
      out.add(
        SelectField(
          'created_at',
          tableAlias: tableAlias,
          alias: aliasFor('created_at'),
        ),
      );
    }
    if (updatedAt) {
      out.add(
        SelectField(
          'updated_at',
          tableAlias: tableAlias,
          alias: aliasFor('updated_at'),
        ),
      );
    }
    final rels = relations;
    if (rels != null && rels.hasSelections) {
      rels.collect(scoped, out, path: path);
    }
  }

  @override
  MerchantPartial hydrate(Map<String, dynamic> row, {String? path}) {
    return MerchantPartial(
      id: id ? readValue(row, 'id', path: path) as String : null,
      name: name ? readValue(row, 'name', path: path) as String : null,
      businessName: businessName
          ? readValue(row, 'business_name', path: path) as String
          : null,
      mobileNumber: mobileNumber
          ? readValue(row, 'mobile_number', path: path) as String
          : null,
      email: email ? readValue(row, 'email', path: path) as String : null,
      passwordHash: passwordHash
          ? readValue(row, 'password_hash', path: path) as String
          : null,
      createdAt: createdAt
          ? readValue(row, 'created_at', path: path) == null
                ? null
                : (readValue(row, 'created_at', path: path) is String
                      ? DateTime.parse(
                          readValue(row, 'created_at', path: path) as String,
                        )
                      : readValue(row, 'created_at', path: path) as DateTime)
          : null,
      updatedAt: updatedAt
          ? readValue(row, 'updated_at', path: path) == null
                ? null
                : (readValue(row, 'updated_at', path: path) is String
                      ? DateTime.parse(
                          readValue(row, 'updated_at', path: path) as String,
                        )
                      : readValue(row, 'updated_at', path: path) as DateTime)
          : null,
    );
  }

  @override
  bool get hasCollectionRelations => false;

  @override
  String? get primaryKeyColumn => 'id';
}

class MerchantRelations extends RelationsOptions<Merchant, MerchantPartial> {
  const MerchantRelations();

  @override
  bool get hasSelections => false;

  @override
  void collect(
    QueryFieldsContext<Merchant> context,
    List<SelectField> out, {
    String? path,
  }) {
    if (context is! MerchantFieldsContext) {
      throw ArgumentError(
        'Expected MerchantFieldsContext for MerchantRelations',
      );
    }
  }
}

class MerchantPartial extends PartialEntity<Merchant> {
  const MerchantPartial({
    this.id,
    this.name,
    this.businessName,
    this.mobileNumber,
    this.email,
    this.passwordHash,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;

  final String? name;

  final String? businessName;

  final String? mobileNumber;

  final String? email;

  final String? passwordHash;

  final DateTime? createdAt;

  final DateTime? updatedAt;

  @override
  Object? get primaryKeyValue {
    return id;
  }

  @override
  MerchantInsertDto toInsertDto() {
    final missing = <String>[];
    if (name == null) missing.add('name');
    if (businessName == null) missing.add('businessName');
    if (mobileNumber == null) missing.add('mobileNumber');
    if (email == null) missing.add('email');
    if (passwordHash == null) missing.add('passwordHash');
    if (missing.isNotEmpty) {
      throw StateError(
        'Cannot convert MerchantPartial to MerchantInsertDto: missing required fields: ${missing.join(', ')}',
      );
    }
    return MerchantInsertDto(
      name: name!,
      businessName: businessName!,
      mobileNumber: mobileNumber!,
      email: email!,
      passwordHash: passwordHash!,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  MerchantUpdateDto toUpdateDto() {
    return MerchantUpdateDto(
      name: name,
      businessName: businessName,
      mobileNumber: mobileNumber,
      email: email,
      passwordHash: passwordHash,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  Merchant toEntity() {
    final missing = <String>[];
    if (id == null) missing.add('id');
    if (name == null) missing.add('name');
    if (businessName == null) missing.add('businessName');
    if (mobileNumber == null) missing.add('mobileNumber');
    if (email == null) missing.add('email');
    if (passwordHash == null) missing.add('passwordHash');
    if (missing.isNotEmpty) {
      throw StateError(
        'Cannot convert MerchantPartial to Merchant: missing required fields: ${missing.join(', ')}',
      );
    }
    return Merchant(
      id: id!,
      name: name!,
      businessName: businessName!,
      mobileNumber: mobileNumber!,
      email: email!,
      passwordHash: passwordHash!,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (businessName != null) 'businessName': businessName,
      if (mobileNumber != null) 'mobileNumber': mobileNumber,
      if (email != null) 'email': email,
      if (passwordHash != null) 'passwordHash': passwordHash,
      if (createdAt != null) 'createdAt': createdAt?.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class MerchantInsertDto implements InsertDto<Merchant> {
  const MerchantInsertDto({
    required this.name,
    required this.businessName,
    required this.mobileNumber,
    required this.email,
    required this.passwordHash,
    this.createdAt,
    this.updatedAt,
  });

  final String name;

  final String businessName;

  final String mobileNumber;

  final String email;

  final String passwordHash;

  final DateTime? createdAt;

  final DateTime? updatedAt;

  @override
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'business_name': businessName,
      'mobile_number': mobileNumber,
      'email': email,
      'password_hash': passwordHash,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> get cascades {
    return const {};
  }

  MerchantInsertDto copyWith({
    String? name,
    String? businessName,
    String? mobileNumber,
    String? email,
    String? passwordHash,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MerchantInsertDto(
      name: name ?? this.name,
      businessName: businessName ?? this.businessName,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class MerchantUpdateDto implements UpdateDto<Merchant> {
  const MerchantUpdateDto({
    this.name,
    this.businessName,
    this.mobileNumber,
    this.email,
    this.passwordHash,
    this.createdAt,
    this.updatedAt,
  });

  final String? name;

  final String? businessName;

  final String? mobileNumber;

  final String? email;

  final String? passwordHash;

  final DateTime? createdAt;

  final DateTime? updatedAt;

  @override
  Map<String, dynamic> toMap() {
    return {
      if (name != null) 'name': name,
      if (businessName != null) 'business_name': businessName,
      if (mobileNumber != null) 'mobile_number': mobileNumber,
      if (email != null) 'email': email,
      if (passwordHash != null) 'password_hash': passwordHash,
      if (createdAt != null)
        'created_at': createdAt is DateTime
            ? (createdAt as DateTime).toIso8601String()
            : createdAt?.toString(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> get cascades {
    return const {};
  }
}

class MerchantRepository extends EntityRepository<Merchant, MerchantPartial> {
  MerchantRepository(EngineAdapter engine)
    : super(
        $MerchantEntityDescriptor,
        engine,
        $MerchantEntityDescriptor.fieldsContext,
      );
}

extension MerchantJson on Merchant {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'businessName': businessName,
      'mobileNumber': mobileNumber,
      'email': email,
      'passwordHash': passwordHash,
      if (createdAt != null) 'createdAt': createdAt?.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

extension MerchantCodec on Merchant {
  Object? toEncodable() {
    return toJson();
  }

  String toJsonString() {
    return encodeJsonColumn(toJson()) as String;
  }
}

extension MerchantPartialCodec on MerchantPartial {
  Object? toEncodable() {
    return toJson();
  }

  String toJsonString() {
    return encodeJsonColumn(toJson()) as String;
  }
}

var $isMerchantJsonCodecInitialized = false;
void $initMerchantJsonCodec() {
  if ($isMerchantJsonCodecInitialized) return;
  EntityJsonRegistry.register<Merchant>(
    (value) => MerchantJson(value).toJson(),
  );
  $isMerchantJsonCodecInitialized = true;
}

extension MerchantRepositoryExtensions
    on EntityRepository<Merchant, PartialEntity<Merchant>> {}

final EntityDescriptor<User, UserPartial> $UserEntityDescriptor = () {
  $initUserJsonCodec();
  return EntityDescriptor(
    entityType: User,
    tableName: 'users',
    columns: [
      ColumnDescriptor(
        name: 'id',
        propertyName: 'id',
        type: ColumnType.integer,
        nullable: false,
        unique: false,
        isPrimaryKey: true,
        autoIncrement: true,
        uuid: false,
        isDeletedAt: false,
      ),
      ColumnDescriptor(
        name: 'email',
        propertyName: 'email',
        type: ColumnType.text,
        nullable: false,
        unique: false,
        isPrimaryKey: false,
        autoIncrement: false,
        uuid: false,
        isDeletedAt: false,
      ),
      ColumnDescriptor(
        name: 'role',
        propertyName: 'role',
        type: ColumnType.text,
        nullable: false,
        unique: false,
        isPrimaryKey: false,
        autoIncrement: false,
        uuid: false,
        isDeletedAt: false,
      ),
      ColumnDescriptor(
        name: 'tags',
        propertyName: 'tags',
        type: ColumnType.json,
        nullable: false,
        unique: false,
        isPrimaryKey: false,
        autoIncrement: false,
        uuid: false,
        isDeletedAt: false,
      ),
    ],
    relations: const [
      RelationDescriptor(
        fieldName: 'posts',
        type: RelationType.oneToMany,
        target: Post,
        isOwningSide: false,
        mappedBy: 'user',
        fetch: RelationFetchStrategy.lazy,
        cascade: const [RelationCascade.persist],
        cascadePersist: true,
        cascadeMerge: false,
        cascadeRemove: false,
      ),
    ],
    fromRow: (row) => User(
      id: (row['id'] as int),
      email: (row['email'] as String),
      role: Role.values.byName(row['role'] as String),
      tags: (decodeJsonColumn(row['tags']) as List).cast<String>(),
      posts: const <Post>[],
    ),
    toRow: (e) => {
      'id': e.id,
      'email': e.email,
      'role': e.role.name,
      'tags': encodeJsonColumn(e.tags),
    },
    fieldsContext: const UserFieldsContext(),
    repositoryFactory: (EngineAdapter engine) => UserRepository(engine),
    defaultSelect: () => UserSelect(),
  );
}();

class UserFieldsContext extends QueryFieldsContext<User> {
  const UserFieldsContext([super.runtimeContext, super.alias]);

  @override
  UserFieldsContext bind(QueryRuntimeContext runtimeContext, String alias) =>
      UserFieldsContext(runtimeContext, alias);

  QueryField<int> get id => field<int>('id');

  QueryField<String> get email => field<String>('email');

  QueryField<Role> get role => field<Role>('role');

  QueryField<List<String>> get tags => field<List<String>>('tags');

  /// Find the owning relation on the target entity to get join column info
  PostFieldsContext get posts {
    final targetRelation = $PostEntityDescriptor.relations.firstWhere(
      (r) => r.fieldName == 'user',
    );
    final joinColumn = targetRelation.joinColumn!;
    final alias = ensureRelationJoin(
      relationName: 'posts',
      targetTableName: $PostEntityDescriptor.qualifiedTableName,
      localColumn: joinColumn.referencedColumnName,
      foreignColumn: joinColumn.name,
      joinType: JoinType.left,
    );
    return PostFieldsContext(runtimeOrThrow, alias);
  }
}

class UserQuery extends QueryBuilder<User> {
  const UserQuery(this._builder);

  final WhereExpression Function(UserFieldsContext) _builder;

  @override
  WhereExpression build(QueryFieldsContext<User> context) {
    if (context is! UserFieldsContext) {
      throw ArgumentError('Expected UserFieldsContext for UserQuery');
    }
    return _builder(context);
  }
}

class UserSelect extends SelectOptions<User, UserPartial> {
  const UserSelect({
    this.id = true,
    this.email = true,
    this.role = true,
    this.tags = true,
    this.relations,
  });

  final bool id;

  final bool email;

  final bool role;

  final bool tags;

  final UserRelations? relations;

  @override
  bool get hasSelections =>
      id || email || role || tags || (relations?.hasSelections ?? false);

  @override
  SelectOptions<User, UserPartial> withRelations(
    RelationsOptions<User, UserPartial>? relations,
  ) {
    return UserSelect(
      id: id,
      email: email,
      role: role,
      tags: tags,
      relations: relations as UserRelations?,
    );
  }

  @override
  void collect(
    QueryFieldsContext<User> context,
    List<SelectField> out, {
    String? path,
  }) {
    if (context is! UserFieldsContext) {
      throw ArgumentError('Expected UserFieldsContext for UserSelect');
    }
    final UserFieldsContext scoped = context;
    String? aliasFor(String column) {
      final current = path;
      if (current == null || current.isEmpty) return null;
      return '${current}_$column';
    }

    final tableAlias = scoped.currentAlias;
    if (id) {
      out.add(SelectField('id', tableAlias: tableAlias, alias: aliasFor('id')));
    }
    if (email) {
      out.add(
        SelectField('email', tableAlias: tableAlias, alias: aliasFor('email')),
      );
    }
    if (role) {
      out.add(
        SelectField('role', tableAlias: tableAlias, alias: aliasFor('role')),
      );
    }
    if (tags) {
      out.add(
        SelectField('tags', tableAlias: tableAlias, alias: aliasFor('tags')),
      );
    }
    final rels = relations;
    if (rels != null && rels.hasSelections) {
      rels.collect(scoped, out, path: path);
    }
  }

  @override
  UserPartial hydrate(Map<String, dynamic> row, {String? path}) {
    // Collection relation posts requires row aggregation
    return UserPartial(
      id: id ? readValue(row, 'id', path: path) as int : null,
      email: email ? readValue(row, 'email', path: path) as String : null,
      role: role
          ? Role.values.byName(readValue(row, 'role', path: path) as String)
          : null,
      tags: tags
          ? (decodeJsonColumn(readValue(row, 'tags', path: path)) as List)
                .cast<String>()
          : null,
      posts: null,
    );
  }

  @override
  bool get hasCollectionRelations => true;

  @override
  String? get primaryKeyColumn => 'id';

  @override
  List<UserPartial> aggregateRows(
    List<Map<String, dynamic>> rows, {
    String? path,
  }) {
    if (rows.isEmpty) return [];
    final grouped = <Object?, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final key = readValue(row, 'id', path: path);
      (grouped[key] ??= []).add(row);
    }
    return grouped.entries.map((entry) {
      final groupRows = entry.value;
      final firstRow = groupRows.first;
      final base = hydrate(firstRow, path: path);
      // Aggregate posts collection
      final postsSelect = relations?.posts;
      List<PostPartial>? postsList;
      if (postsSelect != null && postsSelect.hasSelections) {
        final relationPath = extendPath(path, 'posts');
        postsList = <PostPartial>[];
        final seenKeys = <Object?>{};
        for (final row in groupRows) {
          final itemKey = postsSelect.readValue(
            row,
            postsSelect.primaryKeyColumn ?? 'id',
            path: relationPath,
          );
          if (itemKey != null && seenKeys.add(itemKey)) {
            postsList.add(postsSelect.hydrate(row, path: relationPath));
          }
        }
      }
      return UserPartial(
        id: base.id,
        email: base.email,
        role: base.role,
        tags: base.tags,
        posts: postsList,
      );
    }).toList();
  }
}

class UserRelations extends RelationsOptions<User, UserPartial> {
  const UserRelations({this.posts});

  final PostSelect? posts;

  @override
  bool get hasSelections => (posts?.hasSelections ?? false);

  @override
  void collect(
    QueryFieldsContext<User> context,
    List<SelectField> out, {
    String? path,
  }) {
    if (context is! UserFieldsContext) {
      throw ArgumentError('Expected UserFieldsContext for UserRelations');
    }
    final UserFieldsContext scoped = context;

    final postsSelect = posts;
    if (postsSelect != null && postsSelect.hasSelections) {
      final relationPath = path == null || path.isEmpty
          ? 'posts'
          : '${path}_posts';
      final relationContext = scoped.posts;
      postsSelect.collect(relationContext, out, path: relationPath);
    }
  }
}

class UserPartial extends PartialEntity<User> {
  const UserPartial({this.id, this.email, this.role, this.tags, this.posts});

  final int? id;

  final String? email;

  final Role? role;

  final List<String>? tags;

  final List<PostPartial>? posts;

  @override
  Object? get primaryKeyValue {
    return id;
  }

  @override
  UserInsertDto toInsertDto() {
    final missing = <String>[];
    if (email == null) missing.add('email');
    if (role == null) missing.add('role');
    if (tags == null) missing.add('tags');
    if (missing.isNotEmpty) {
      throw StateError(
        'Cannot convert UserPartial to UserInsertDto: missing required fields: ${missing.join(', ')}',
      );
    }
    return UserInsertDto(
      email: email!,
      role: role!,
      tags: tags!,
      posts: posts?.map((p) => p.toInsertDto()).toList(),
    );
  }

  @override
  UserUpdateDto toUpdateDto() {
    return UserUpdateDto(email: email, role: role, tags: tags);
  }

  @override
  User toEntity() {
    final missing = <String>[];
    if (id == null) missing.add('id');
    if (email == null) missing.add('email');
    if (role == null) missing.add('role');
    if (tags == null) missing.add('tags');
    if (missing.isNotEmpty) {
      throw StateError(
        'Cannot convert UserPartial to User: missing required fields: ${missing.join(', ')}',
      );
    }
    return User(
      id: id!,
      email: email!,
      role: role!,
      tags: tags!,
      posts: posts?.map((p) => p.toEntity()).toList() ?? const <Post>[],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (email != null) 'email': email,
      if (role != null) 'role': role?.name,
      if (tags != null) 'tags': tags,
      if (posts != null) 'posts': posts?.map((e) => e.toJson()).toList(),
    };
  }
}

class UserInsertDto implements InsertDto<User> {
  const UserInsertDto({
    required this.email,
    required this.role,
    required this.tags,
    this.posts,
  });

  final String email;

  final Role role;

  final List<String> tags;

  final List<PostInsertDto>? posts;

  @override
  Map<String, dynamic> toMap() {
    return {'email': email, 'role': role.name, 'tags': tags};
  }

  Map<String, dynamic> get cascades {
    return {if (posts != null) 'posts': posts};
  }

  UserInsertDto copyWith({
    String? email,
    Role? role,
    List<String>? tags,
    List<PostInsertDto>? posts,
  }) {
    return UserInsertDto(
      email: email ?? this.email,
      role: role ?? this.role,
      tags: tags ?? this.tags,
      posts: posts ?? this.posts,
    );
  }
}

class UserUpdateDto implements UpdateDto<User> {
  const UserUpdateDto({this.email, this.role, this.tags});

  final String? email;

  final Role? role;

  final List<String>? tags;

  @override
  Map<String, dynamic> toMap() {
    return {
      if (email != null) 'email': email,
      if (role != null) 'role': role?.name,
      if (tags != null) 'tags': tags,
    };
  }

  Map<String, dynamic> get cascades {
    return const {};
  }
}

class UserRepository extends EntityRepository<User, UserPartial> {
  UserRepository(EngineAdapter engine)
    : super($UserEntityDescriptor, engine, $UserEntityDescriptor.fieldsContext);
}

extension UserJson on User {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role.name,
      'tags': tags,
      if (posts != null) 'posts': posts?.map((e) => e.toJson()).toList(),
    };
  }
}

extension UserCodec on User {
  Object? toEncodable() {
    return toJson();
  }

  String toJsonString() {
    return encodeJsonColumn(toJson()) as String;
  }
}

extension UserPartialCodec on UserPartial {
  Object? toEncodable() {
    return toJson();
  }

  String toJsonString() {
    return encodeJsonColumn(toJson()) as String;
  }
}

var $isUserJsonCodecInitialized = false;
void $initUserJsonCodec() {
  if ($isUserJsonCodecInitialized) return;
  EntityJsonRegistry.register<User>((value) => UserJson(value).toJson());
  $isUserJsonCodecInitialized = true;
}

/// Result DTO for the [countUsers] query.
final class CountUsersResult {
  const CountUsersResult({required this.total});

  factory CountUsersResult.fromMap(Map<String, dynamic> map) {
    return CountUsersResult(total: map['total'] as int);
  }

  final int total;
}

extension UserRepositoryExtensions
    on EntityRepository<User, PartialEntity<User>> {
  Future<User> findByEmail(String email) async {
    final rows = await engine.query(
      'SELECT * FROM users WHERE email = ? LIMIT 1',
      [email],
    );
    final entity = descriptor.fromRow(rows.first);
    return entity;
  }

  Future<CountUsersResult> countUsers() async {
    final rows = await engine.query('SELECT COUNT(*) as total FROM users', []);
    return CountUsersResult.fromMap(rows.first);
  }

  Future<List<PartialEntity<User>>> getUserEmailsAndRoles() async {
    final rows = await engine.query('SELECT email, role FROM users', []);
    final selectOpts = UserSelect();
    return rows.map((row) => selectOpts.hydrate(row)).toList();
  }

  Future<List<User>> findAllUsers() async {
    final rows = await engine.query('SELECT * FROM users', []);
    final entities = rows.map((row) => descriptor.fromRow(row)).toList();
    return entities;
  }
}

final EntityDescriptor<Post, PostPartial> $PostEntityDescriptor = () {
  $initPostJsonCodec();
  return EntityDescriptor(
    entityType: Post,
    tableName: 'posts',
    columns: [
      ColumnDescriptor(
        name: 'id',
        propertyName: 'id',
        type: ColumnType.uuid,
        nullable: false,
        unique: false,
        isPrimaryKey: true,
        autoIncrement: false,
        uuid: true,
        isDeletedAt: false,
      ),
      ColumnDescriptor(
        name: 'title',
        propertyName: 'title',
        type: ColumnType.text,
        nullable: false,
        unique: false,
        isPrimaryKey: false,
        autoIncrement: false,
        uuid: false,
        isDeletedAt: false,
      ),
      ColumnDescriptor(
        name: 'content',
        propertyName: 'content',
        type: ColumnType.text,
        nullable: false,
        unique: false,
        isPrimaryKey: false,
        autoIncrement: false,
        uuid: false,
        isDeletedAt: false,
      ),
      ColumnDescriptor(
        name: 'likes',
        propertyName: 'likes',
        type: ColumnType.integer,
        nullable: false,
        unique: false,
        isPrimaryKey: false,
        autoIncrement: false,
        uuid: false,
        isDeletedAt: false,
        defaultValue: 0,
      ),
      ColumnDescriptor(
        name: 'created_at',
        propertyName: 'createdAt',
        type: ColumnType.dateTime,
        nullable: true,
        unique: false,
        isPrimaryKey: false,
        autoIncrement: false,
        uuid: false,
        isDeletedAt: false,
      ),
      ColumnDescriptor(
        name: 'last_updated_at',
        propertyName: 'lastUpdatedAt',
        type: ColumnType.dateTime,
        nullable: true,
        unique: false,
        isPrimaryKey: false,
        autoIncrement: false,
        uuid: false,
        isDeletedAt: false,
      ),
      ColumnDescriptor(
        name: 'deleted_at',
        propertyName: 'deletedAt',
        type: ColumnType.dateTime,
        nullable: true,
        unique: false,
        isPrimaryKey: false,
        autoIncrement: false,
        uuid: false,
        isDeletedAt: true,
      ),
    ],
    relations: const [
      RelationDescriptor(
        fieldName: 'user',
        type: RelationType.manyToOne,
        target: User,
        isOwningSide: true,
        fetch: RelationFetchStrategy.lazy,
        cascade: const [],
        cascadePersist: false,
        cascadeMerge: false,
        cascadeRemove: false,
        joinColumn: JoinColumnDescriptor(
          name: 'user_id',
          referencedColumnName: 'id',
          nullable: true,
          unique: false,
        ),
      ),
      RelationDescriptor(
        fieldName: 'tags',
        type: RelationType.manyToMany,
        target: Tag,
        isOwningSide: true,
        fetch: RelationFetchStrategy.lazy,
        cascade: const [RelationCascade.persist, RelationCascade.remove],
        cascadePersist: true,
        cascadeMerge: false,
        cascadeRemove: true,
        joinTable: JoinTableDescriptor(
          name: 'post_tags',
          joinColumns: [
            JoinColumnDescriptor(
              name: 'post_id',
              referencedColumnName: 'id',
              nullable: true,
              unique: false,
            ),
          ],
          inverseJoinColumns: [
            JoinColumnDescriptor(
              name: 'tag_id',
              referencedColumnName: 'id',
              nullable: true,
              unique: false,
            ),
          ],
        ),
      ),
    ],
    fromRow: (row) => Post(
      id: (row['id'] as String),
      title: (row['title'] as String),
      content: (row['content'] as String),
      likes: (row['likes'] as int),
      createdAt: row['created_at'] == null
          ? null
          : row['created_at'] is String
          ? DateTime.parse(row['created_at'].toString())
          : row['created_at'] as DateTime,
      lastUpdatedAt: row['last_updated_at'] == null
          ? null
          : (row['last_updated_at'] is String
                    ? DateTime.parse(row['last_updated_at'].toString())
                    : row['last_updated_at'] as DateTime)
                .millisecondsSinceEpoch,
      deletedAt: row['deleted_at'] == null
          ? null
          : row['deleted_at'] is String
          ? DateTime.parse(row['deleted_at'].toString())
          : row['deleted_at'] as DateTime,
      user: null,
      tags: const <Tag>[],
    ),
    toRow: (e) => {
      'id': e.id,
      'title': e.title,
      'content': e.content,
      'likes': e.likes,
      'created_at': e.createdAt?.toIso8601String(),
      'last_updated_at': e.lastUpdatedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              e.lastUpdatedAt as int,
            ).toIso8601String(),
      'deleted_at': e.deletedAt?.toIso8601String(),
      'user_id': e.user?.id,
    },
    fieldsContext: const PostFieldsContext(),
    repositoryFactory: (EngineAdapter engine) => PostRepository(engine),
    hooks: EntityHooks<Post>(
      preRemove: (e) {
        e.beforeDelete();
      },
      prePersist: (e) {
        e.createdAt = DateTime.now();
        e.lastUpdatedAt = DateTime.now().millisecondsSinceEpoch;
      },
      preUpdate: (e) {
        e.lastUpdatedAt = DateTime.now().millisecondsSinceEpoch;
      },
    ),
    defaultSelect: () => PostSelect(),
  );
}();

class PostFieldsContext extends QueryFieldsContext<Post> {
  const PostFieldsContext([super.runtimeContext, super.alias]);

  @override
  PostFieldsContext bind(QueryRuntimeContext runtimeContext, String alias) =>
      PostFieldsContext(runtimeContext, alias);

  QueryField<String> get id => field<String>('id');

  QueryField<String> get title => field<String>('title');

  QueryField<String> get content => field<String>('content');

  QueryField<int> get likes => field<int>('likes');

  QueryField<DateTime?> get createdAt => field<DateTime?>('created_at');

  QueryField<int?> get lastUpdatedAt => field<int?>('last_updated_at');

  QueryField<DateTime?> get deletedAt => field<DateTime?>('deleted_at');

  QueryField<int?> get userId => field<int?>('user_id');

  UserFieldsContext get user {
    final alias = ensureRelationJoin(
      relationName: 'user',
      targetTableName: $UserEntityDescriptor.qualifiedTableName,
      localColumn: 'user_id',
      foreignColumn: 'id',
      joinType: JoinType.left,
    );
    return UserFieldsContext(runtimeOrThrow, alias);
  }

  /// Join through the post_tags join table
  TagFieldsContext get tags {
    final joinTableAlias = ensureRelationJoin(
      relationName: 'tags_jt',
      targetTableName: 'post_tags',
      localColumn: 'id',
      foreignColumn: 'post_id',
      joinType: JoinType.left,
    );
    final alias = ensureRelationJoinFrom(
      fromAlias: joinTableAlias,
      relationName: 'tags',
      targetTableName: $TagEntityDescriptor.qualifiedTableName,
      localColumn: 'tag_id',
      foreignColumn: 'id',
      joinType: JoinType.left,
    );
    return TagFieldsContext(runtimeOrThrow, alias);
  }
}

class PostQuery extends QueryBuilder<Post> {
  const PostQuery(this._builder);

  final WhereExpression Function(PostFieldsContext) _builder;

  @override
  WhereExpression build(QueryFieldsContext<Post> context) {
    if (context is! PostFieldsContext) {
      throw ArgumentError('Expected PostFieldsContext for PostQuery');
    }
    return _builder(context);
  }
}

class PostSelect extends SelectOptions<Post, PostPartial> {
  const PostSelect({
    this.id = true,
    this.title = true,
    this.content = true,
    this.likes = true,
    this.createdAt = true,
    this.lastUpdatedAt = true,
    this.deletedAt = true,
    this.userId = true,
    this.relations,
  });

  final bool id;

  final bool title;

  final bool content;

  final bool likes;

  final bool createdAt;

  final bool lastUpdatedAt;

  final bool deletedAt;

  final bool userId;

  final PostRelations? relations;

  @override
  bool get hasSelections =>
      id ||
      title ||
      content ||
      likes ||
      createdAt ||
      lastUpdatedAt ||
      deletedAt ||
      userId ||
      (relations?.hasSelections ?? false);

  @override
  SelectOptions<Post, PostPartial> withRelations(
    RelationsOptions<Post, PostPartial>? relations,
  ) {
    return PostSelect(
      id: id,
      title: title,
      content: content,
      likes: likes,
      createdAt: createdAt,
      lastUpdatedAt: lastUpdatedAt,
      deletedAt: deletedAt,
      userId: userId,
      relations: relations as PostRelations?,
    );
  }

  @override
  void collect(
    QueryFieldsContext<Post> context,
    List<SelectField> out, {
    String? path,
  }) {
    if (context is! PostFieldsContext) {
      throw ArgumentError('Expected PostFieldsContext for PostSelect');
    }
    final PostFieldsContext scoped = context;
    String? aliasFor(String column) {
      final current = path;
      if (current == null || current.isEmpty) return null;
      return '${current}_$column';
    }

    final tableAlias = scoped.currentAlias;
    if (id) {
      out.add(SelectField('id', tableAlias: tableAlias, alias: aliasFor('id')));
    }
    if (title) {
      out.add(
        SelectField('title', tableAlias: tableAlias, alias: aliasFor('title')),
      );
    }
    if (content) {
      out.add(
        SelectField(
          'content',
          tableAlias: tableAlias,
          alias: aliasFor('content'),
        ),
      );
    }
    if (likes) {
      out.add(
        SelectField('likes', tableAlias: tableAlias, alias: aliasFor('likes')),
      );
    }
    if (createdAt) {
      out.add(
        SelectField(
          'created_at',
          tableAlias: tableAlias,
          alias: aliasFor('created_at'),
        ),
      );
    }
    if (lastUpdatedAt) {
      out.add(
        SelectField(
          'last_updated_at',
          tableAlias: tableAlias,
          alias: aliasFor('last_updated_at'),
        ),
      );
    }
    if (deletedAt) {
      out.add(
        SelectField(
          'deleted_at',
          tableAlias: tableAlias,
          alias: aliasFor('deleted_at'),
        ),
      );
    }
    if (userId) {
      out.add(
        SelectField(
          'user_id',
          tableAlias: tableAlias,
          alias: aliasFor('user_id'),
        ),
      );
    }
    final rels = relations;
    if (rels != null && rels.hasSelections) {
      rels.collect(scoped, out, path: path);
    }
  }

  @override
  PostPartial hydrate(Map<String, dynamic> row, {String? path}) {
    UserPartial? userPartial;
    final userSelect = relations?.user;
    if (userSelect != null && userSelect.hasSelections) {
      userPartial = userSelect.hydrate(row, path: extendPath(path, 'user'));
    }
    return PostPartial(
      id: id ? readValue(row, 'id', path: path) as String : null,
      title: title ? readValue(row, 'title', path: path) as String : null,
      content: content ? readValue(row, 'content', path: path) as String : null,
      likes: likes ? readValue(row, 'likes', path: path) as int : null,
      createdAt: createdAt
          ? readValue(row, 'created_at', path: path) == null
                ? null
                : (readValue(row, 'created_at', path: path) is String
                      ? DateTime.parse(
                          readValue(row, 'created_at', path: path) as String,
                        )
                      : readValue(row, 'created_at', path: path) as DateTime)
          : null,
      lastUpdatedAt: lastUpdatedAt
          ? readValue(row, 'last_updated_at', path: path) == null
                ? null
                : (readValue(row, 'last_updated_at', path: path) is String
                          ? DateTime.parse(
                              readValue(row, 'last_updated_at', path: path)
                                  as String,
                            )
                          : readValue(row, 'last_updated_at', path: path)
                                as DateTime)
                      .millisecondsSinceEpoch
          : null,
      deletedAt: deletedAt
          ? readValue(row, 'deleted_at', path: path) == null
                ? null
                : (readValue(row, 'deleted_at', path: path) is String
                      ? DateTime.parse(
                          readValue(row, 'deleted_at', path: path) as String,
                        )
                      : readValue(row, 'deleted_at', path: path) as DateTime)
          : null,
      userId: userId ? readValue(row, 'user_id', path: path) as int? : null,
      user: userPartial,
    );
  }

  @override
  bool get hasCollectionRelations => false;

  @override
  String? get primaryKeyColumn => 'id';
}

class PostRelations extends RelationsOptions<Post, PostPartial> {
  const PostRelations({this.user, this.tags});

  final UserSelect? user;

  final TagSelect? tags;

  @override
  bool get hasSelections =>
      (user?.hasSelections ?? false) || (tags?.hasSelections ?? false);

  @override
  void collect(
    QueryFieldsContext<Post> context,
    List<SelectField> out, {
    String? path,
  }) {
    if (context is! PostFieldsContext) {
      throw ArgumentError('Expected PostFieldsContext for PostRelations');
    }
    final PostFieldsContext scoped = context;

    final userSelect = user;
    if (userSelect != null && userSelect.hasSelections) {
      final relationPath = path == null || path.isEmpty
          ? 'user'
          : '${path}_user';
      final relationContext = scoped.user;
      userSelect.collect(relationContext, out, path: relationPath);
    }
    final tagsSelect = tags;
    if (tagsSelect != null && tagsSelect.hasSelections) {
      final relationPath = path == null || path.isEmpty
          ? 'tags'
          : '${path}_tags';
      final relationContext = scoped.tags;
      tagsSelect.collect(relationContext, out, path: relationPath);
    }
  }
}

class PostPartial extends PartialEntity<Post> {
  const PostPartial({
    this.id,
    this.title,
    this.content,
    this.likes,
    this.createdAt,
    this.lastUpdatedAt,
    this.deletedAt,
    this.userId,
    this.user,
    this.tags,
  });

  final String? id;

  final String? title;

  final String? content;

  final int? likes;

  final DateTime? createdAt;

  final int? lastUpdatedAt;

  final DateTime? deletedAt;

  final int? userId;

  final UserPartial? user;

  final List<TagPartial>? tags;

  @override
  Object? get primaryKeyValue {
    return id;
  }

  @override
  PostInsertDto toInsertDto() {
    final missing = <String>[];
    if (title == null) missing.add('title');
    if (content == null) missing.add('content');
    if (missing.isNotEmpty) {
      throw StateError(
        'Cannot convert PostPartial to PostInsertDto: missing required fields: ${missing.join(', ')}',
      );
    }
    return PostInsertDto(
      title: title!,
      content: content!,
      likes: likes ?? 0,
      createdAt: createdAt,
      lastUpdatedAt: lastUpdatedAt,
      deletedAt: deletedAt,
      userId: userId,
      tags: tags?.map((p) => p.toInsertDto()).toList(),
    );
  }

  @override
  PostUpdateDto toUpdateDto() {
    return PostUpdateDto(
      title: title,
      content: content,
      likes: likes,
      createdAt: createdAt,
      lastUpdatedAt: lastUpdatedAt,
      deletedAt: deletedAt,
      userId: userId,
    );
  }

  @override
  Post toEntity() {
    final missing = <String>[];
    if (id == null) missing.add('id');
    if (title == null) missing.add('title');
    if (content == null) missing.add('content');
    if (likes == null) missing.add('likes');
    if (missing.isNotEmpty) {
      throw StateError(
        'Cannot convert PostPartial to Post: missing required fields: ${missing.join(', ')}',
      );
    }
    return Post(
      id: id!,
      title: title!,
      content: content!,
      likes: likes!,
      createdAt: createdAt,
      lastUpdatedAt: lastUpdatedAt,
      deletedAt: deletedAt,
      user: user?.toEntity(),
      tags: tags?.map((p) => p.toEntity()).toList() ?? const <Tag>[],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (likes != null) 'likes': likes,
      if (createdAt != null) 'createdAt': createdAt?.toIso8601String(),
      if (lastUpdatedAt != null) 'lastUpdatedAt': lastUpdatedAt,
      if (deletedAt != null) 'deletedAt': deletedAt?.toIso8601String(),
      if (user != null) 'user': user?.toJson(),
      if (tags != null) 'tags': tags?.map((e) => e.toJson()).toList(),
      if (userId != null) 'userId': userId,
    };
  }
}

class PostInsertDto implements InsertDto<Post> {
  const PostInsertDto({
    required this.title,
    required this.content,
    this.likes = 0,
    this.createdAt,
    this.lastUpdatedAt,
    this.deletedAt,
    this.userId,
    this.tags,
  });

  final String title;

  final String content;

  final int likes;

  final DateTime? createdAt;

  final int? lastUpdatedAt;

  final DateTime? deletedAt;

  final int? userId;

  final List<TagInsertDto>? tags;

  @override
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'likes': likes,
      'created_at': DateTime.now().toIso8601String(),
      'last_updated_at': DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
      ).toIso8601String(),
      'deleted_at': deletedAt is DateTime
          ? (deletedAt as DateTime).toIso8601String()
          : deletedAt?.toString(),
      if (userId != null) 'user_id': userId,
    };
  }

  Map<String, dynamic> get cascades {
    return {if (tags != null) 'tags': tags};
  }

  PostInsertDto copyWith({
    String? title,
    String? content,
    int? likes,
    DateTime? createdAt,
    int? lastUpdatedAt,
    DateTime? deletedAt,
    int? userId,
    List<TagInsertDto>? tags,
  }) {
    return PostInsertDto(
      title: title ?? this.title,
      content: content ?? this.content,
      likes: likes ?? this.likes,
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      userId: userId ?? this.userId,
      tags: tags ?? this.tags,
    );
  }
}

class PostUpdateDto implements UpdateDto<Post> {
  const PostUpdateDto({
    this.title,
    this.content,
    this.likes,
    this.createdAt,
    this.lastUpdatedAt,
    this.deletedAt,
    this.userId,
  });

  final String? title;

  final String? content;

  final int? likes;

  final DateTime? createdAt;

  final int? lastUpdatedAt;

  final DateTime? deletedAt;

  final int? userId;

  @override
  Map<String, dynamic> toMap() {
    return {
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (likes != null) 'likes': likes,
      if (createdAt != null)
        'created_at': createdAt is DateTime
            ? (createdAt as DateTime).toIso8601String()
            : createdAt?.toString(),
      'last_updated_at': DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
      ).toIso8601String(),
      if (deletedAt != null)
        'deleted_at': deletedAt is DateTime
            ? (deletedAt as DateTime).toIso8601String()
            : deletedAt?.toString(),
      if (userId != null) 'user_id': userId,
    };
  }

  Map<String, dynamic> get cascades {
    return const {};
  }
}

class PostRepository extends EntityRepository<Post, PostPartial> {
  PostRepository(EngineAdapter engine)
    : super($PostEntityDescriptor, engine, $PostEntityDescriptor.fieldsContext);
}

extension PostJson on Post {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'likes': likes,
      if (createdAt != null) 'createdAt': createdAt?.toIso8601String(),
      if (lastUpdatedAt != null) 'lastUpdatedAt': lastUpdatedAt,
      if (deletedAt != null) 'deletedAt': deletedAt?.toIso8601String(),
      if (user != null) 'user': user?.toJson(),
      if (tags != null) 'tags': tags?.map((e) => e.toJson()).toList(),
    };
  }
}

extension PostCodec on Post {
  Object? toEncodable() {
    return toJson();
  }

  String toJsonString() {
    return encodeJsonColumn(toJson()) as String;
  }
}

extension PostPartialCodec on PostPartial {
  Object? toEncodable() {
    return toJson();
  }

  String toJsonString() {
    return encodeJsonColumn(toJson()) as String;
  }
}

var $isPostJsonCodecInitialized = false;
void $initPostJsonCodec() {
  if ($isPostJsonCodecInitialized) return;
  EntityJsonRegistry.register<Post>((value) => PostJson(value).toJson());
  $isPostJsonCodecInitialized = true;
}

extension PostRepositoryExtensions
    on EntityRepository<Post, PartialEntity<Post>> {}

final EntityDescriptor<Tag, TagPartial> $TagEntityDescriptor = () {
  $initTagJsonCodec();
  return EntityDescriptor(
    entityType: Tag,
    tableName: 'tag',
    columns: [
      ColumnDescriptor(
        name: 'id',
        propertyName: 'id',
        type: ColumnType.integer,
        nullable: false,
        unique: false,
        isPrimaryKey: true,
        autoIncrement: true,
        uuid: false,
        isDeletedAt: false,
      ),
      ColumnDescriptor(
        name: 'name',
        propertyName: 'name',
        type: ColumnType.text,
        nullable: false,
        unique: false,
        isPrimaryKey: false,
        autoIncrement: false,
        uuid: false,
        isDeletedAt: false,
      ),
    ],
    relations: const [
      RelationDescriptor(
        fieldName: 'posts',
        type: RelationType.manyToMany,
        target: Post,
        isOwningSide: false,
        mappedBy: 'tags',
        fetch: RelationFetchStrategy.lazy,
        cascade: const [],
        cascadePersist: false,
        cascadeMerge: false,
        cascadeRemove: false,
      ),
    ],
    fromRow: (row) => Tag(
      id: (row['id'] as int),
      name: (row['name'] as String),
      posts: const <Post>[],
    ),
    toRow: (e) => {'id': e.id, 'name': e.name},
    fieldsContext: const TagFieldsContext(),
    repositoryFactory: (EngineAdapter engine) => TagRepository(engine),
    defaultSelect: () => TagSelect(),
  );
}();

class TagFieldsContext extends QueryFieldsContext<Tag> {
  const TagFieldsContext([super.runtimeContext, super.alias]);

  @override
  TagFieldsContext bind(QueryRuntimeContext runtimeContext, String alias) =>
      TagFieldsContext(runtimeContext, alias);

  QueryField<int> get id => field<int>('id');

  QueryField<String> get name => field<String>('name');

  /// Find the owning relation on the target entity to get join column info
  PostFieldsContext get posts {
    final targetRelation = $PostEntityDescriptor.relations.firstWhere(
      (r) => r.fieldName == 'tags',
    );
    final joinColumn = targetRelation.joinColumn!;
    final alias = ensureRelationJoin(
      relationName: 'posts',
      targetTableName: $PostEntityDescriptor.qualifiedTableName,
      localColumn: joinColumn.referencedColumnName,
      foreignColumn: joinColumn.name,
      joinType: JoinType.left,
    );
    return PostFieldsContext(runtimeOrThrow, alias);
  }
}

class TagQuery extends QueryBuilder<Tag> {
  const TagQuery(this._builder);

  final WhereExpression Function(TagFieldsContext) _builder;

  @override
  WhereExpression build(QueryFieldsContext<Tag> context) {
    if (context is! TagFieldsContext) {
      throw ArgumentError('Expected TagFieldsContext for TagQuery');
    }
    return _builder(context);
  }
}

class TagSelect extends SelectOptions<Tag, TagPartial> {
  const TagSelect({this.id = true, this.name = true, this.relations});

  final bool id;

  final bool name;

  final TagRelations? relations;

  @override
  bool get hasSelections => id || name || (relations?.hasSelections ?? false);

  @override
  SelectOptions<Tag, TagPartial> withRelations(
    RelationsOptions<Tag, TagPartial>? relations,
  ) {
    return TagSelect(id: id, name: name, relations: relations as TagRelations?);
  }

  @override
  void collect(
    QueryFieldsContext<Tag> context,
    List<SelectField> out, {
    String? path,
  }) {
    if (context is! TagFieldsContext) {
      throw ArgumentError('Expected TagFieldsContext for TagSelect');
    }
    final TagFieldsContext scoped = context;
    String? aliasFor(String column) {
      final current = path;
      if (current == null || current.isEmpty) return null;
      return '${current}_$column';
    }

    final tableAlias = scoped.currentAlias;
    if (id) {
      out.add(SelectField('id', tableAlias: tableAlias, alias: aliasFor('id')));
    }
    if (name) {
      out.add(
        SelectField('name', tableAlias: tableAlias, alias: aliasFor('name')),
      );
    }
    final rels = relations;
    if (rels != null && rels.hasSelections) {
      rels.collect(scoped, out, path: path);
    }
  }

  @override
  TagPartial hydrate(Map<String, dynamic> row, {String? path}) {
    // Collection relation posts requires row aggregation
    return TagPartial(
      id: id ? readValue(row, 'id', path: path) as int : null,
      name: name ? readValue(row, 'name', path: path) as String : null,
      posts: null,
    );
  }

  @override
  bool get hasCollectionRelations => true;

  @override
  String? get primaryKeyColumn => 'id';

  @override
  List<TagPartial> aggregateRows(
    List<Map<String, dynamic>> rows, {
    String? path,
  }) {
    if (rows.isEmpty) return [];
    final grouped = <Object?, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final key = readValue(row, 'id', path: path);
      (grouped[key] ??= []).add(row);
    }
    return grouped.entries.map((entry) {
      final groupRows = entry.value;
      final firstRow = groupRows.first;
      final base = hydrate(firstRow, path: path);
      // Aggregate posts collection
      final postsSelect = relations?.posts;
      List<PostPartial>? postsList;
      if (postsSelect != null && postsSelect.hasSelections) {
        final relationPath = extendPath(path, 'posts');
        postsList = <PostPartial>[];
        final seenKeys = <Object?>{};
        for (final row in groupRows) {
          final itemKey = postsSelect.readValue(
            row,
            postsSelect.primaryKeyColumn ?? 'id',
            path: relationPath,
          );
          if (itemKey != null && seenKeys.add(itemKey)) {
            postsList.add(postsSelect.hydrate(row, path: relationPath));
          }
        }
      }
      return TagPartial(id: base.id, name: base.name, posts: postsList);
    }).toList();
  }
}

class TagRelations extends RelationsOptions<Tag, TagPartial> {
  const TagRelations({this.posts});

  final PostSelect? posts;

  @override
  bool get hasSelections => (posts?.hasSelections ?? false);

  @override
  void collect(
    QueryFieldsContext<Tag> context,
    List<SelectField> out, {
    String? path,
  }) {
    if (context is! TagFieldsContext) {
      throw ArgumentError('Expected TagFieldsContext for TagRelations');
    }
    final TagFieldsContext scoped = context;

    final postsSelect = posts;
    if (postsSelect != null && postsSelect.hasSelections) {
      final relationPath = path == null || path.isEmpty
          ? 'posts'
          : '${path}_posts';
      final relationContext = scoped.posts;
      postsSelect.collect(relationContext, out, path: relationPath);
    }
  }
}

class TagPartial extends PartialEntity<Tag> {
  const TagPartial({this.id, this.name, this.posts});

  final int? id;

  final String? name;

  final List<PostPartial>? posts;

  @override
  Object? get primaryKeyValue {
    return id;
  }

  @override
  TagInsertDto toInsertDto() {
    final missing = <String>[];
    if (name == null) missing.add('name');
    if (missing.isNotEmpty) {
      throw StateError(
        'Cannot convert TagPartial to TagInsertDto: missing required fields: ${missing.join(', ')}',
      );
    }
    return TagInsertDto(name: name!);
  }

  @override
  TagUpdateDto toUpdateDto() {
    return TagUpdateDto(name: name);
  }

  @override
  Tag toEntity() {
    final missing = <String>[];
    if (id == null) missing.add('id');
    if (name == null) missing.add('name');
    if (missing.isNotEmpty) {
      throw StateError(
        'Cannot convert TagPartial to Tag: missing required fields: ${missing.join(', ')}',
      );
    }
    return Tag(
      id: id!,
      name: name!,
      posts: posts?.map((p) => p.toEntity()).toList() ?? const <Post>[],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (posts != null) 'posts': posts?.map((e) => e.toJson()).toList(),
    };
  }
}

class TagInsertDto implements InsertDto<Tag> {
  const TagInsertDto({required this.name});

  final String name;

  @override
  Map<String, dynamic> toMap() {
    return {'name': name};
  }

  Map<String, dynamic> get cascades {
    return const {};
  }

  TagInsertDto copyWith({String? name}) {
    return TagInsertDto(name: name ?? this.name);
  }
}

class TagUpdateDto implements UpdateDto<Tag> {
  const TagUpdateDto({this.name});

  final String? name;

  @override
  Map<String, dynamic> toMap() {
    return {if (name != null) 'name': name};
  }

  Map<String, dynamic> get cascades {
    return const {};
  }
}

class TagRepository extends EntityRepository<Tag, TagPartial> {
  TagRepository(EngineAdapter engine)
    : super($TagEntityDescriptor, engine, $TagEntityDescriptor.fieldsContext);
}

extension TagJson on Tag {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (posts != null) 'posts': posts?.map((e) => e.toJson()).toList(),
    };
  }
}

extension TagCodec on Tag {
  Object? toEncodable() {
    return toJson();
  }

  String toJsonString() {
    return encodeJsonColumn(toJson()) as String;
  }
}

extension TagPartialCodec on TagPartial {
  Object? toEncodable() {
    return toJson();
  }

  String toJsonString() {
    return encodeJsonColumn(toJson()) as String;
  }
}

var $isTagJsonCodecInitialized = false;
void $initTagJsonCodec() {
  if ($isTagJsonCodecInitialized) return;
  EntityJsonRegistry.register<Tag>((value) => TagJson(value).toJson());
  $isTagJsonCodecInitialized = true;
}

extension TagRepositoryExtensions
    on EntityRepository<Tag, PartialEntity<Tag>> {}

final EntityDescriptor<Subscription, SubscriptionPartial>
$SubscriptionEntityDescriptor = () {
  $initSubscriptionJsonCodec();
  return EntityDescriptor(
    entityType: Subscription,
    tableName: 'subscriptions',
    columns: [
      ColumnDescriptor(
        name: 'id',
        propertyName: 'id',
        type: ColumnType.uuid,
        nullable: false,
        unique: false,
        isPrimaryKey: true,
        autoIncrement: false,
        uuid: true,
        isDeletedAt: false,
      ),
      ColumnDescriptor(
        name: 'plan',
        propertyName: 'plan',
        type: ColumnType.text,
        nullable: false,
        unique: false,
        isPrimaryKey: false,
        autoIncrement: false,
        uuid: false,
        isDeletedAt: false,
      ),
      ColumnDescriptor(
        name: 'status',
        propertyName: 'status',
        type: ColumnType.text,
        nullable: false,
        unique: false,
        isPrimaryKey: false,
        autoIncrement: false,
        uuid: false,
        isDeletedAt: false,
      ),
      ColumnDescriptor(
        name: 'current_period_end',
        propertyName: 'currentPeriodEnd',
        type: ColumnType.dateTime,
        nullable: false,
        unique: false,
        isPrimaryKey: false,
        autoIncrement: false,
        uuid: false,
        isDeletedAt: false,
      ),
      ColumnDescriptor(
        name: 'created_at',
        propertyName: 'createdAt',
        type: ColumnType.dateTime,
        nullable: true,
        unique: false,
        isPrimaryKey: false,
        autoIncrement: false,
        uuid: false,
        isDeletedAt: false,
      ),
      ColumnDescriptor(
        name: 'updated_at',
        propertyName: 'updatedAt',
        type: ColumnType.dateTime,
        nullable: true,
        unique: false,
        isPrimaryKey: false,
        autoIncrement: false,
        uuid: false,
        isDeletedAt: false,
      ),
    ],
    relations: const [],
    fromRow: (row) => Subscription(
      id: (row['id'] as String),
      plan: Plan.values.byName(row['plan'] as String),
      status: SubscriptionStatus.values.byName(row['status'] as String),
      currentPeriodEnd: row['current_period_end'] is String
          ? DateTime.parse(row['current_period_end'].toString())
          : row['current_period_end'] as DateTime,
      createdAt: row['created_at'] == null
          ? null
          : row['created_at'] is String
          ? DateTime.parse(row['created_at'].toString())
          : row['created_at'] as DateTime,
      updatedAt: row['updated_at'] == null
          ? null
          : row['updated_at'] is String
          ? DateTime.parse(row['updated_at'].toString())
          : row['updated_at'] as DateTime,
    ),
    toRow: (e) => {
      'id': e.id,
      'plan': e.plan.name,
      'status': e.status.name,
      'current_period_end': e.currentPeriodEnd.toIso8601String(),
      'created_at': e.createdAt?.toIso8601String(),
      'updated_at': e.updatedAt?.toIso8601String(),
    },
    fieldsContext: const SubscriptionFieldsContext(),
    repositoryFactory: (EngineAdapter engine) => SubscriptionRepository(engine),
    hooks: EntityHooks<Subscription>(
      prePersist: (e) {
        e.createdAt = DateTime.now();
        e.updatedAt = DateTime.now();
      },
      preUpdate: (e) {
        e.updatedAt = DateTime.now();
      },
    ),
    defaultSelect: () => SubscriptionSelect(),
  );
}();

class SubscriptionFieldsContext extends QueryFieldsContext<Subscription> {
  const SubscriptionFieldsContext([super.runtimeContext, super.alias]);

  @override
  SubscriptionFieldsContext bind(
    QueryRuntimeContext runtimeContext,
    String alias,
  ) => SubscriptionFieldsContext(runtimeContext, alias);

  QueryField<String> get id => field<String>('id');

  QueryField<Plan> get plan => field<Plan>('plan');

  QueryField<SubscriptionStatus> get status =>
      field<SubscriptionStatus>('status');

  QueryField<DateTime> get currentPeriodEnd =>
      field<DateTime>('current_period_end');

  QueryField<DateTime?> get createdAt => field<DateTime?>('created_at');

  QueryField<DateTime?> get updatedAt => field<DateTime?>('updated_at');
}

class SubscriptionQuery extends QueryBuilder<Subscription> {
  const SubscriptionQuery(this._builder);

  final WhereExpression Function(SubscriptionFieldsContext) _builder;

  @override
  WhereExpression build(QueryFieldsContext<Subscription> context) {
    if (context is! SubscriptionFieldsContext) {
      throw ArgumentError(
        'Expected SubscriptionFieldsContext for SubscriptionQuery',
      );
    }
    return _builder(context);
  }
}

class SubscriptionSelect
    extends SelectOptions<Subscription, SubscriptionPartial> {
  const SubscriptionSelect({
    this.id = true,
    this.plan = true,
    this.status = true,
    this.currentPeriodEnd = true,
    this.createdAt = true,
    this.updatedAt = true,
    this.relations,
  });

  final bool id;

  final bool plan;

  final bool status;

  final bool currentPeriodEnd;

  final bool createdAt;

  final bool updatedAt;

  final SubscriptionRelations? relations;

  @override
  bool get hasSelections =>
      id ||
      plan ||
      status ||
      currentPeriodEnd ||
      createdAt ||
      updatedAt ||
      (relations?.hasSelections ?? false);

  @override
  SelectOptions<Subscription, SubscriptionPartial> withRelations(
    RelationsOptions<Subscription, SubscriptionPartial>? relations,
  ) {
    return SubscriptionSelect(
      id: id,
      plan: plan,
      status: status,
      currentPeriodEnd: currentPeriodEnd,
      createdAt: createdAt,
      updatedAt: updatedAt,
      relations: relations as SubscriptionRelations?,
    );
  }

  @override
  void collect(
    QueryFieldsContext<Subscription> context,
    List<SelectField> out, {
    String? path,
  }) {
    if (context is! SubscriptionFieldsContext) {
      throw ArgumentError(
        'Expected SubscriptionFieldsContext for SubscriptionSelect',
      );
    }
    final SubscriptionFieldsContext scoped = context;
    String? aliasFor(String column) {
      final current = path;
      if (current == null || current.isEmpty) return null;
      return '${current}_$column';
    }

    final tableAlias = scoped.currentAlias;
    if (id) {
      out.add(SelectField('id', tableAlias: tableAlias, alias: aliasFor('id')));
    }
    if (plan) {
      out.add(
        SelectField('plan', tableAlias: tableAlias, alias: aliasFor('plan')),
      );
    }
    if (status) {
      out.add(
        SelectField(
          'status',
          tableAlias: tableAlias,
          alias: aliasFor('status'),
        ),
      );
    }
    if (currentPeriodEnd) {
      out.add(
        SelectField(
          'current_period_end',
          tableAlias: tableAlias,
          alias: aliasFor('current_period_end'),
        ),
      );
    }
    if (createdAt) {
      out.add(
        SelectField(
          'created_at',
          tableAlias: tableAlias,
          alias: aliasFor('created_at'),
        ),
      );
    }
    if (updatedAt) {
      out.add(
        SelectField(
          'updated_at',
          tableAlias: tableAlias,
          alias: aliasFor('updated_at'),
        ),
      );
    }
    final rels = relations;
    if (rels != null && rels.hasSelections) {
      rels.collect(scoped, out, path: path);
    }
  }

  @override
  SubscriptionPartial hydrate(Map<String, dynamic> row, {String? path}) {
    return SubscriptionPartial(
      id: id ? readValue(row, 'id', path: path) as String : null,
      plan: plan
          ? Plan.values.byName(readValue(row, 'plan', path: path) as String)
          : null,
      status: status
          ? SubscriptionStatus.values.byName(
              readValue(row, 'status', path: path) as String,
            )
          : null,
      currentPeriodEnd: currentPeriodEnd
          ? (readValue(row, 'current_period_end', path: path) is String
                ? DateTime.parse(
                    readValue(row, 'current_period_end', path: path) as String,
                  )
                : readValue(row, 'current_period_end', path: path) as DateTime)
          : null,
      createdAt: createdAt
          ? readValue(row, 'created_at', path: path) == null
                ? null
                : (readValue(row, 'created_at', path: path) is String
                      ? DateTime.parse(
                          readValue(row, 'created_at', path: path) as String,
                        )
                      : readValue(row, 'created_at', path: path) as DateTime)
          : null,
      updatedAt: updatedAt
          ? readValue(row, 'updated_at', path: path) == null
                ? null
                : (readValue(row, 'updated_at', path: path) is String
                      ? DateTime.parse(
                          readValue(row, 'updated_at', path: path) as String,
                        )
                      : readValue(row, 'updated_at', path: path) as DateTime)
          : null,
    );
  }

  @override
  bool get hasCollectionRelations => false;

  @override
  String? get primaryKeyColumn => 'id';
}

class SubscriptionRelations
    extends RelationsOptions<Subscription, SubscriptionPartial> {
  const SubscriptionRelations();

  @override
  bool get hasSelections => false;

  @override
  void collect(
    QueryFieldsContext<Subscription> context,
    List<SelectField> out, {
    String? path,
  }) {
    if (context is! SubscriptionFieldsContext) {
      throw ArgumentError(
        'Expected SubscriptionFieldsContext for SubscriptionRelations',
      );
    }
  }
}

class SubscriptionPartial extends PartialEntity<Subscription> {
  const SubscriptionPartial({
    this.id,
    this.plan,
    this.status,
    this.currentPeriodEnd,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;

  final Plan? plan;

  final SubscriptionStatus? status;

  final DateTime? currentPeriodEnd;

  final DateTime? createdAt;

  final DateTime? updatedAt;

  @override
  Object? get primaryKeyValue {
    return id;
  }

  @override
  SubscriptionInsertDto toInsertDto() {
    final missing = <String>[];
    if (plan == null) missing.add('plan');
    if (status == null) missing.add('status');
    if (currentPeriodEnd == null) missing.add('currentPeriodEnd');
    if (missing.isNotEmpty) {
      throw StateError(
        'Cannot convert SubscriptionPartial to SubscriptionInsertDto: missing required fields: ${missing.join(', ')}',
      );
    }
    return SubscriptionInsertDto(
      plan: plan!,
      status: status!,
      currentPeriodEnd: currentPeriodEnd!,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  SubscriptionUpdateDto toUpdateDto() {
    return SubscriptionUpdateDto(
      plan: plan,
      status: status,
      currentPeriodEnd: currentPeriodEnd,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  Subscription toEntity() {
    final missing = <String>[];
    if (id == null) missing.add('id');
    if (plan == null) missing.add('plan');
    if (status == null) missing.add('status');
    if (currentPeriodEnd == null) missing.add('currentPeriodEnd');
    if (missing.isNotEmpty) {
      throw StateError(
        'Cannot convert SubscriptionPartial to Subscription: missing required fields: ${missing.join(', ')}',
      );
    }
    return Subscription(
      id: id!,
      plan: plan!,
      status: status!,
      currentPeriodEnd: currentPeriodEnd!,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (plan != null) 'plan': plan?.name,
      if (status != null) 'status': status?.name,
      if (currentPeriodEnd != null)
        'currentPeriodEnd': currentPeriodEnd?.toIso8601String(),
      if (createdAt != null) 'createdAt': createdAt?.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class SubscriptionInsertDto implements InsertDto<Subscription> {
  const SubscriptionInsertDto({
    required this.plan,
    required this.status,
    required this.currentPeriodEnd,
    this.createdAt,
    this.updatedAt,
  });

  final Plan plan;

  final SubscriptionStatus status;

  final DateTime currentPeriodEnd;

  final DateTime? createdAt;

  final DateTime? updatedAt;

  @override
  Map<String, dynamic> toMap() {
    return {
      'plan': plan.name,
      'status': status.name,
      'current_period_end': currentPeriodEnd.toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> get cascades {
    return const {};
  }

  SubscriptionInsertDto copyWith({
    Plan? plan,
    SubscriptionStatus? status,
    DateTime? currentPeriodEnd,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SubscriptionInsertDto(
      plan: plan ?? this.plan,
      status: status ?? this.status,
      currentPeriodEnd: currentPeriodEnd ?? this.currentPeriodEnd,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SubscriptionUpdateDto implements UpdateDto<Subscription> {
  const SubscriptionUpdateDto({
    this.plan,
    this.status,
    this.currentPeriodEnd,
    this.createdAt,
    this.updatedAt,
  });

  final Plan? plan;

  final SubscriptionStatus? status;

  final DateTime? currentPeriodEnd;

  final DateTime? createdAt;

  final DateTime? updatedAt;

  @override
  Map<String, dynamic> toMap() {
    return {
      if (plan != null) 'plan': plan?.name,
      if (status != null) 'status': status?.name,
      if (currentPeriodEnd != null)
        'current_period_end': currentPeriodEnd?.toIso8601String(),
      if (createdAt != null)
        'created_at': createdAt is DateTime
            ? (createdAt as DateTime).toIso8601String()
            : createdAt?.toString(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> get cascades {
    return const {};
  }
}

class SubscriptionRepository
    extends EntityRepository<Subscription, SubscriptionPartial> {
  SubscriptionRepository(EngineAdapter engine)
    : super(
        $SubscriptionEntityDescriptor,
        engine,
        $SubscriptionEntityDescriptor.fieldsContext,
      );
}

extension SubscriptionJson on Subscription {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plan': plan.name,
      'status': status.name,
      'currentPeriodEnd': currentPeriodEnd.toIso8601String(),
      if (createdAt != null) 'createdAt': createdAt?.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

extension SubscriptionCodec on Subscription {
  Object? toEncodable() {
    return toJson();
  }

  String toJsonString() {
    return encodeJsonColumn(toJson()) as String;
  }
}

extension SubscriptionPartialCodec on SubscriptionPartial {
  Object? toEncodable() {
    return toJson();
  }

  String toJsonString() {
    return encodeJsonColumn(toJson()) as String;
  }
}

var $isSubscriptionJsonCodecInitialized = false;
void $initSubscriptionJsonCodec() {
  if ($isSubscriptionJsonCodecInitialized) return;
  EntityJsonRegistry.register<Subscription>(
    (value) => SubscriptionJson(value).toJson(),
  );
  $isSubscriptionJsonCodecInitialized = true;
}

extension SubscriptionRepositoryExtensions
    on EntityRepository<Subscription, PartialEntity<Subscription>> {}

final EntityDescriptor<Movie, MoviePartial> $MovieEntityDescriptor = () {
  $initMovieJsonCodec();
  return EntityDescriptor(
    entityType: Movie,
    tableName: 'movies',
    columns: [
      ColumnDescriptor(
        name: 'id',
        propertyName: 'id',
        type: ColumnType.uuid,
        nullable: false,
        unique: false,
        isPrimaryKey: true,
        autoIncrement: false,
        uuid: true,
        isDeletedAt: false,
      ),
      ColumnDescriptor(
        name: 'title',
        propertyName: 'title',
        type: ColumnType.text,
        nullable: false,
        unique: false,
        isPrimaryKey: false,
        autoIncrement: false,
        uuid: false,
        isDeletedAt: false,
      ),
      ColumnDescriptor(
        name: 'overview',
        propertyName: 'overview',
        type: ColumnType.text,
        nullable: true,
        unique: false,
        isPrimaryKey: false,
        autoIncrement: false,
        uuid: false,
        isDeletedAt: false,
      ),
      ColumnDescriptor(
        name: 'release_year',
        propertyName: 'releaseYear',
        type: ColumnType.integer,
        nullable: false,
        unique: false,
        isPrimaryKey: false,
        autoIncrement: false,
        uuid: false,
        isDeletedAt: false,
      ),
      ColumnDescriptor(
        name: 'genres',
        propertyName: 'genres',
        type: ColumnType.json,
        nullable: false,
        unique: false,
        isPrimaryKey: false,
        autoIncrement: false,
        uuid: false,
        isDeletedAt: false,
      ),
      ColumnDescriptor(
        name: 'runtime',
        propertyName: 'runtime',
        type: ColumnType.integer,
        nullable: true,
        unique: false,
        isPrimaryKey: false,
        autoIncrement: false,
        uuid: false,
        isDeletedAt: false,
      ),
      ColumnDescriptor(
        name: 'poster_url',
        propertyName: 'posterUrl',
        type: ColumnType.text,
        nullable: true,
        unique: false,
        isPrimaryKey: false,
        autoIncrement: false,
        uuid: false,
        isDeletedAt: false,
      ),
      ColumnDescriptor(
        name: 'created_at',
        propertyName: 'createdAt',
        type: ColumnType.dateTime,
        nullable: true,
        unique: false,
        isPrimaryKey: false,
        autoIncrement: false,
        uuid: false,
        isDeletedAt: false,
      ),
      ColumnDescriptor(
        name: 'updated_at',
        propertyName: 'updatedAt',
        type: ColumnType.dateTime,
        nullable: true,
        unique: false,
        isPrimaryKey: false,
        autoIncrement: false,
        uuid: false,
        isDeletedAt: false,
      ),
    ],
    relations: const [],
    fromRow: (row) => Movie(
      id: (row['id'] as String),
      title: (row['title'] as String),
      overview: (row['overview'] as String?),
      releaseYear: (row['release_year'] as int),
      genres: (decodeJsonColumn(row['genres']) as List).cast<String>(),
      runtime: (row['runtime'] as int?),
      posterUrl: (row['poster_url'] as String?),
      createdAt: row['created_at'] == null
          ? null
          : row['created_at'] is String
          ? DateTime.parse(row['created_at'].toString())
          : row['created_at'] as DateTime,
      updatedAt: row['updated_at'] == null
          ? null
          : row['updated_at'] is String
          ? DateTime.parse(row['updated_at'].toString())
          : row['updated_at'] as DateTime,
    ),
    toRow: (e) => {
      'id': e.id,
      'title': e.title,
      'overview': e.overview,
      'release_year': e.releaseYear,
      'genres': encodeJsonColumn(e.genres),
      'runtime': e.runtime,
      'poster_url': e.posterUrl,
      'created_at': e.createdAt?.toIso8601String(),
      'updated_at': e.updatedAt?.toIso8601String(),
    },
    fieldsContext: const MovieFieldsContext(),
    repositoryFactory: (EngineAdapter engine) => MovieRepository(engine),
    hooks: EntityHooks<Movie>(
      prePersist: (e) {
        e.createdAt = DateTime.now();
        e.updatedAt = DateTime.now();
      },
      preUpdate: (e) {
        e.updatedAt = DateTime.now();
      },
    ),
    defaultSelect: () => MovieSelect(),
  );
}();

class MovieFieldsContext extends QueryFieldsContext<Movie> {
  const MovieFieldsContext([super.runtimeContext, super.alias]);

  @override
  MovieFieldsContext bind(QueryRuntimeContext runtimeContext, String alias) =>
      MovieFieldsContext(runtimeContext, alias);

  QueryField<String> get id => field<String>('id');

  QueryField<String> get title => field<String>('title');

  QueryField<String?> get overview => field<String?>('overview');

  QueryField<int> get releaseYear => field<int>('release_year');

  QueryField<List<String>> get genres => field<List<String>>('genres');

  QueryField<int?> get runtime => field<int?>('runtime');

  QueryField<String?> get posterUrl => field<String?>('poster_url');

  QueryField<DateTime?> get createdAt => field<DateTime?>('created_at');

  QueryField<DateTime?> get updatedAt => field<DateTime?>('updated_at');
}

class MovieQuery extends QueryBuilder<Movie> {
  const MovieQuery(this._builder);

  final WhereExpression Function(MovieFieldsContext) _builder;

  @override
  WhereExpression build(QueryFieldsContext<Movie> context) {
    if (context is! MovieFieldsContext) {
      throw ArgumentError('Expected MovieFieldsContext for MovieQuery');
    }
    return _builder(context);
  }
}

class MovieSelect extends SelectOptions<Movie, MoviePartial> {
  const MovieSelect({
    this.id = true,
    this.title = true,
    this.overview = true,
    this.releaseYear = true,
    this.genres = true,
    this.runtime = true,
    this.posterUrl = true,
    this.createdAt = true,
    this.updatedAt = true,
    this.relations,
  });

  final bool id;

  final bool title;

  final bool overview;

  final bool releaseYear;

  final bool genres;

  final bool runtime;

  final bool posterUrl;

  final bool createdAt;

  final bool updatedAt;

  final MovieRelations? relations;

  @override
  bool get hasSelections =>
      id ||
      title ||
      overview ||
      releaseYear ||
      genres ||
      runtime ||
      posterUrl ||
      createdAt ||
      updatedAt ||
      (relations?.hasSelections ?? false);

  @override
  SelectOptions<Movie, MoviePartial> withRelations(
    RelationsOptions<Movie, MoviePartial>? relations,
  ) {
    return MovieSelect(
      id: id,
      title: title,
      overview: overview,
      releaseYear: releaseYear,
      genres: genres,
      runtime: runtime,
      posterUrl: posterUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
      relations: relations as MovieRelations?,
    );
  }

  @override
  void collect(
    QueryFieldsContext<Movie> context,
    List<SelectField> out, {
    String? path,
  }) {
    if (context is! MovieFieldsContext) {
      throw ArgumentError('Expected MovieFieldsContext for MovieSelect');
    }
    final MovieFieldsContext scoped = context;
    String? aliasFor(String column) {
      final current = path;
      if (current == null || current.isEmpty) return null;
      return '${current}_$column';
    }

    final tableAlias = scoped.currentAlias;
    if (id) {
      out.add(SelectField('id', tableAlias: tableAlias, alias: aliasFor('id')));
    }
    if (title) {
      out.add(
        SelectField('title', tableAlias: tableAlias, alias: aliasFor('title')),
      );
    }
    if (overview) {
      out.add(
        SelectField(
          'overview',
          tableAlias: tableAlias,
          alias: aliasFor('overview'),
        ),
      );
    }
    if (releaseYear) {
      out.add(
        SelectField(
          'release_year',
          tableAlias: tableAlias,
          alias: aliasFor('release_year'),
        ),
      );
    }
    if (genres) {
      out.add(
        SelectField(
          'genres',
          tableAlias: tableAlias,
          alias: aliasFor('genres'),
        ),
      );
    }
    if (runtime) {
      out.add(
        SelectField(
          'runtime',
          tableAlias: tableAlias,
          alias: aliasFor('runtime'),
        ),
      );
    }
    if (posterUrl) {
      out.add(
        SelectField(
          'poster_url',
          tableAlias: tableAlias,
          alias: aliasFor('poster_url'),
        ),
      );
    }
    if (createdAt) {
      out.add(
        SelectField(
          'created_at',
          tableAlias: tableAlias,
          alias: aliasFor('created_at'),
        ),
      );
    }
    if (updatedAt) {
      out.add(
        SelectField(
          'updated_at',
          tableAlias: tableAlias,
          alias: aliasFor('updated_at'),
        ),
      );
    }
    final rels = relations;
    if (rels != null && rels.hasSelections) {
      rels.collect(scoped, out, path: path);
    }
  }

  @override
  MoviePartial hydrate(Map<String, dynamic> row, {String? path}) {
    return MoviePartial(
      id: id ? readValue(row, 'id', path: path) as String : null,
      title: title ? readValue(row, 'title', path: path) as String : null,
      overview: overview
          ? readValue(row, 'overview', path: path) as String?
          : null,
      releaseYear: releaseYear
          ? readValue(row, 'release_year', path: path) as int
          : null,
      genres: genres
          ? (decodeJsonColumn(readValue(row, 'genres', path: path)) as List)
                .cast<String>()
          : null,
      runtime: runtime ? readValue(row, 'runtime', path: path) as int? : null,
      posterUrl: posterUrl
          ? readValue(row, 'poster_url', path: path) as String?
          : null,
      createdAt: createdAt
          ? readValue(row, 'created_at', path: path) == null
                ? null
                : (readValue(row, 'created_at', path: path) is String
                      ? DateTime.parse(
                          readValue(row, 'created_at', path: path) as String,
                        )
                      : readValue(row, 'created_at', path: path) as DateTime)
          : null,
      updatedAt: updatedAt
          ? readValue(row, 'updated_at', path: path) == null
                ? null
                : (readValue(row, 'updated_at', path: path) is String
                      ? DateTime.parse(
                          readValue(row, 'updated_at', path: path) as String,
                        )
                      : readValue(row, 'updated_at', path: path) as DateTime)
          : null,
    );
  }

  @override
  bool get hasCollectionRelations => false;

  @override
  String? get primaryKeyColumn => 'id';
}

class MovieRelations extends RelationsOptions<Movie, MoviePartial> {
  const MovieRelations();

  @override
  bool get hasSelections => false;

  @override
  void collect(
    QueryFieldsContext<Movie> context,
    List<SelectField> out, {
    String? path,
  }) {
    if (context is! MovieFieldsContext) {
      throw ArgumentError('Expected MovieFieldsContext for MovieRelations');
    }
  }
}

class MoviePartial extends PartialEntity<Movie> {
  const MoviePartial({
    this.id,
    this.title,
    this.overview,
    this.releaseYear,
    this.genres,
    this.runtime,
    this.posterUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;

  final String? title;

  final String? overview;

  final int? releaseYear;

  final List<String>? genres;

  final int? runtime;

  final String? posterUrl;

  final DateTime? createdAt;

  final DateTime? updatedAt;

  @override
  Object? get primaryKeyValue {
    return id;
  }

  @override
  MovieInsertDto toInsertDto() {
    final missing = <String>[];
    if (title == null) missing.add('title');
    if (releaseYear == null) missing.add('releaseYear');
    if (genres == null) missing.add('genres');
    if (missing.isNotEmpty) {
      throw StateError(
        'Cannot convert MoviePartial to MovieInsertDto: missing required fields: ${missing.join(', ')}',
      );
    }
    return MovieInsertDto(
      title: title!,
      overview: overview,
      releaseYear: releaseYear!,
      genres: genres!,
      runtime: runtime,
      posterUrl: posterUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  MovieUpdateDto toUpdateDto() {
    return MovieUpdateDto(
      title: title,
      overview: overview,
      releaseYear: releaseYear,
      genres: genres,
      runtime: runtime,
      posterUrl: posterUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  Movie toEntity() {
    final missing = <String>[];
    if (id == null) missing.add('id');
    if (title == null) missing.add('title');
    if (releaseYear == null) missing.add('releaseYear');
    if (genres == null) missing.add('genres');
    if (missing.isNotEmpty) {
      throw StateError(
        'Cannot convert MoviePartial to Movie: missing required fields: ${missing.join(', ')}',
      );
    }
    return Movie(
      id: id!,
      title: title!,
      overview: overview,
      releaseYear: releaseYear!,
      genres: genres!,
      runtime: runtime,
      posterUrl: posterUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (overview != null) 'overview': overview,
      if (releaseYear != null) 'releaseYear': releaseYear,
      if (genres != null) 'genres': genres,
      if (runtime != null) 'runtime': runtime,
      if (posterUrl != null) 'posterUrl': posterUrl,
      if (createdAt != null) 'createdAt': createdAt?.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class MovieInsertDto implements InsertDto<Movie> {
  const MovieInsertDto({
    required this.title,
    this.overview,
    required this.releaseYear,
    required this.genres,
    this.runtime,
    this.posterUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String title;

  final String? overview;

  final int releaseYear;

  final List<String> genres;

  final int? runtime;

  final String? posterUrl;

  final DateTime? createdAt;

  final DateTime? updatedAt;

  @override
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'overview': overview,
      'release_year': releaseYear,
      'genres': genres,
      'runtime': runtime,
      'poster_url': posterUrl,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> get cascades {
    return const {};
  }

  MovieInsertDto copyWith({
    String? title,
    String? overview,
    int? releaseYear,
    List<String>? genres,
    int? runtime,
    String? posterUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MovieInsertDto(
      title: title ?? this.title,
      overview: overview ?? this.overview,
      releaseYear: releaseYear ?? this.releaseYear,
      genres: genres ?? this.genres,
      runtime: runtime ?? this.runtime,
      posterUrl: posterUrl ?? this.posterUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class MovieUpdateDto implements UpdateDto<Movie> {
  const MovieUpdateDto({
    this.title,
    this.overview,
    this.releaseYear,
    this.genres,
    this.runtime,
    this.posterUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String? title;

  final String? overview;

  final int? releaseYear;

  final List<String>? genres;

  final int? runtime;

  final String? posterUrl;

  final DateTime? createdAt;

  final DateTime? updatedAt;

  @override
  Map<String, dynamic> toMap() {
    return {
      if (title != null) 'title': title,
      if (overview != null) 'overview': overview,
      if (releaseYear != null) 'release_year': releaseYear,
      if (genres != null) 'genres': genres,
      if (runtime != null) 'runtime': runtime,
      if (posterUrl != null) 'poster_url': posterUrl,
      if (createdAt != null)
        'created_at': createdAt is DateTime
            ? (createdAt as DateTime).toIso8601String()
            : createdAt?.toString(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> get cascades {
    return const {};
  }
}

class MovieRepository extends EntityRepository<Movie, MoviePartial> {
  MovieRepository(EngineAdapter engine)
    : super(
        $MovieEntityDescriptor,
        engine,
        $MovieEntityDescriptor.fieldsContext,
      );
}

extension MovieJson on Movie {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (overview != null) 'overview': overview,
      'releaseYear': releaseYear,
      'genres': genres,
      if (runtime != null) 'runtime': runtime,
      if (posterUrl != null) 'posterUrl': posterUrl,
      if (createdAt != null) 'createdAt': createdAt?.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

extension MovieCodec on Movie {
  Object? toEncodable() {
    return toJson();
  }

  String toJsonString() {
    return encodeJsonColumn(toJson()) as String;
  }
}

extension MoviePartialCodec on MoviePartial {
  Object? toEncodable() {
    return toJson();
  }

  String toJsonString() {
    return encodeJsonColumn(toJson()) as String;
  }
}

var $isMovieJsonCodecInitialized = false;
void $initMovieJsonCodec() {
  if ($isMovieJsonCodecInitialized) return;
  EntityJsonRegistry.register<Movie>((value) => MovieJson(value).toJson());
  $isMovieJsonCodecInitialized = true;
}

extension MovieRepositoryExtensions
    on EntityRepository<Movie, PartialEntity<Movie>> {}

final EntityDescriptor<WatchlistItem, WatchlistItemPartial>
$WatchlistItemEntityDescriptor = () {
  $initWatchlistItemJsonCodec();
  return EntityDescriptor(
    entityType: WatchlistItem,
    tableName: 'watchlist_items',
    columns: [
      ColumnDescriptor(
        name: 'id',
        propertyName: 'id',
        type: ColumnType.integer,
        nullable: false,
        unique: false,
        isPrimaryKey: true,
        autoIncrement: true,
        uuid: false,
        isDeletedAt: false,
      ),
      ColumnDescriptor(
        name: 'notes',
        propertyName: 'notes',
        type: ColumnType.text,
        nullable: true,
        unique: false,
        isPrimaryKey: false,
        autoIncrement: false,
        uuid: false,
        isDeletedAt: false,
      ),
      ColumnDescriptor(
        name: 'created_at',
        propertyName: 'createdAt',
        type: ColumnType.dateTime,
        nullable: true,
        unique: false,
        isPrimaryKey: false,
        autoIncrement: false,
        uuid: false,
        isDeletedAt: false,
      ),
    ],
    relations: const [
      RelationDescriptor(
        fieldName: 'user',
        type: RelationType.manyToOne,
        target: User,
        isOwningSide: true,
        fetch: RelationFetchStrategy.lazy,
        cascade: const [],
        cascadePersist: false,
        cascadeMerge: false,
        cascadeRemove: false,
        joinColumn: JoinColumnDescriptor(
          name: 'user_id',
          referencedColumnName: 'id',
          nullable: true,
          unique: false,
        ),
      ),
      RelationDescriptor(
        fieldName: 'movie',
        type: RelationType.manyToOne,
        target: Movie,
        isOwningSide: true,
        fetch: RelationFetchStrategy.lazy,
        cascade: const [],
        cascadePersist: false,
        cascadeMerge: false,
        cascadeRemove: false,
        joinColumn: JoinColumnDescriptor(
          name: 'movie_id',
          referencedColumnName: 'id',
          nullable: true,
          unique: false,
        ),
      ),
    ],
    uniqueConstraints: const [
      UniqueConstraintDescriptor(columns: ['user_id', 'movie_id']),
    ],
    fromRow: (row) => WatchlistItem(
      id: (row['id'] as int),
      notes: (row['notes'] as String?),
      createdAt: row['created_at'] == null
          ? null
          : row['created_at'] is String
          ? DateTime.parse(row['created_at'].toString())
          : row['created_at'] as DateTime,
      user: null,
      movie: null,
    ),
    toRow: (e) => {
      'id': e.id,
      'notes': e.notes,
      'created_at': e.createdAt?.toIso8601String(),
      'user_id': e.user?.id,
      'movie_id': e.movie?.id,
    },
    fieldsContext: const WatchlistItemFieldsContext(),
    repositoryFactory: (EngineAdapter engine) =>
        WatchlistItemRepository(engine),
    hooks: EntityHooks<WatchlistItem>(
      prePersist: (e) {
        e.createdAt = DateTime.now();
      },
    ),
    defaultSelect: () => WatchlistItemSelect(),
  );
}();

class WatchlistItemFieldsContext extends QueryFieldsContext<WatchlistItem> {
  const WatchlistItemFieldsContext([super.runtimeContext, super.alias]);

  @override
  WatchlistItemFieldsContext bind(
    QueryRuntimeContext runtimeContext,
    String alias,
  ) => WatchlistItemFieldsContext(runtimeContext, alias);

  QueryField<int> get id => field<int>('id');

  QueryField<String?> get notes => field<String?>('notes');

  QueryField<DateTime?> get createdAt => field<DateTime?>('created_at');

  QueryField<int?> get userId => field<int?>('user_id');

  QueryField<String?> get movieId => field<String?>('movie_id');

  UserFieldsContext get user {
    final alias = ensureRelationJoin(
      relationName: 'user',
      targetTableName: $UserEntityDescriptor.qualifiedTableName,
      localColumn: 'user_id',
      foreignColumn: 'id',
      joinType: JoinType.left,
    );
    return UserFieldsContext(runtimeOrThrow, alias);
  }

  MovieFieldsContext get movie {
    final alias = ensureRelationJoin(
      relationName: 'movie',
      targetTableName: $MovieEntityDescriptor.qualifiedTableName,
      localColumn: 'movie_id',
      foreignColumn: 'id',
      joinType: JoinType.left,
    );
    return MovieFieldsContext(runtimeOrThrow, alias);
  }
}

class WatchlistItemQuery extends QueryBuilder<WatchlistItem> {
  const WatchlistItemQuery(this._builder);

  final WhereExpression Function(WatchlistItemFieldsContext) _builder;

  @override
  WhereExpression build(QueryFieldsContext<WatchlistItem> context) {
    if (context is! WatchlistItemFieldsContext) {
      throw ArgumentError(
        'Expected WatchlistItemFieldsContext for WatchlistItemQuery',
      );
    }
    return _builder(context);
  }
}

class WatchlistItemSelect
    extends SelectOptions<WatchlistItem, WatchlistItemPartial> {
  const WatchlistItemSelect({
    this.id = true,
    this.notes = true,
    this.createdAt = true,
    this.userId = true,
    this.movieId = true,
    this.relations,
  });

  final bool id;

  final bool notes;

  final bool createdAt;

  final bool userId;

  final bool movieId;

  final WatchlistItemRelations? relations;

  @override
  bool get hasSelections =>
      id ||
      notes ||
      createdAt ||
      userId ||
      movieId ||
      (relations?.hasSelections ?? false);

  @override
  SelectOptions<WatchlistItem, WatchlistItemPartial> withRelations(
    RelationsOptions<WatchlistItem, WatchlistItemPartial>? relations,
  ) {
    return WatchlistItemSelect(
      id: id,
      notes: notes,
      createdAt: createdAt,
      userId: userId,
      movieId: movieId,
      relations: relations as WatchlistItemRelations?,
    );
  }

  @override
  void collect(
    QueryFieldsContext<WatchlistItem> context,
    List<SelectField> out, {
    String? path,
  }) {
    if (context is! WatchlistItemFieldsContext) {
      throw ArgumentError(
        'Expected WatchlistItemFieldsContext for WatchlistItemSelect',
      );
    }
    final WatchlistItemFieldsContext scoped = context;
    String? aliasFor(String column) {
      final current = path;
      if (current == null || current.isEmpty) return null;
      return '${current}_$column';
    }

    final tableAlias = scoped.currentAlias;
    if (id) {
      out.add(SelectField('id', tableAlias: tableAlias, alias: aliasFor('id')));
    }
    if (notes) {
      out.add(
        SelectField('notes', tableAlias: tableAlias, alias: aliasFor('notes')),
      );
    }
    if (createdAt) {
      out.add(
        SelectField(
          'created_at',
          tableAlias: tableAlias,
          alias: aliasFor('created_at'),
        ),
      );
    }
    if (userId) {
      out.add(
        SelectField(
          'user_id',
          tableAlias: tableAlias,
          alias: aliasFor('user_id'),
        ),
      );
    }
    if (movieId) {
      out.add(
        SelectField(
          'movie_id',
          tableAlias: tableAlias,
          alias: aliasFor('movie_id'),
        ),
      );
    }
    final rels = relations;
    if (rels != null && rels.hasSelections) {
      rels.collect(scoped, out, path: path);
    }
  }

  @override
  WatchlistItemPartial hydrate(Map<String, dynamic> row, {String? path}) {
    UserPartial? userPartial;
    final userSelect = relations?.user;
    if (userSelect != null && userSelect.hasSelections) {
      userPartial = userSelect.hydrate(row, path: extendPath(path, 'user'));
    }
    MoviePartial? moviePartial;
    final movieSelect = relations?.movie;
    if (movieSelect != null && movieSelect.hasSelections) {
      moviePartial = movieSelect.hydrate(row, path: extendPath(path, 'movie'));
    }
    return WatchlistItemPartial(
      id: id ? readValue(row, 'id', path: path) as int : null,
      notes: notes ? readValue(row, 'notes', path: path) as String? : null,
      createdAt: createdAt
          ? readValue(row, 'created_at', path: path) == null
                ? null
                : (readValue(row, 'created_at', path: path) is String
                      ? DateTime.parse(
                          readValue(row, 'created_at', path: path) as String,
                        )
                      : readValue(row, 'created_at', path: path) as DateTime)
          : null,
      userId: userId ? readValue(row, 'user_id', path: path) as int? : null,
      user: userPartial,
      movieId: movieId
          ? readValue(row, 'movie_id', path: path) as String?
          : null,
      movie: moviePartial,
    );
  }

  @override
  bool get hasCollectionRelations => false;

  @override
  String? get primaryKeyColumn => 'id';
}

class WatchlistItemRelations
    extends RelationsOptions<WatchlistItem, WatchlistItemPartial> {
  const WatchlistItemRelations({this.user, this.movie});

  final UserSelect? user;

  final MovieSelect? movie;

  @override
  bool get hasSelections =>
      (user?.hasSelections ?? false) || (movie?.hasSelections ?? false);

  @override
  void collect(
    QueryFieldsContext<WatchlistItem> context,
    List<SelectField> out, {
    String? path,
  }) {
    if (context is! WatchlistItemFieldsContext) {
      throw ArgumentError(
        'Expected WatchlistItemFieldsContext for WatchlistItemRelations',
      );
    }
    final WatchlistItemFieldsContext scoped = context;

    final userSelect = user;
    if (userSelect != null && userSelect.hasSelections) {
      final relationPath = path == null || path.isEmpty
          ? 'user'
          : '${path}_user';
      final relationContext = scoped.user;
      userSelect.collect(relationContext, out, path: relationPath);
    }
    final movieSelect = movie;
    if (movieSelect != null && movieSelect.hasSelections) {
      final relationPath = path == null || path.isEmpty
          ? 'movie'
          : '${path}_movie';
      final relationContext = scoped.movie;
      movieSelect.collect(relationContext, out, path: relationPath);
    }
  }
}

class WatchlistItemPartial extends PartialEntity<WatchlistItem> {
  const WatchlistItemPartial({
    this.id,
    this.notes,
    this.createdAt,
    this.userId,
    this.user,
    this.movieId,
    this.movie,
  });

  final int? id;

  final String? notes;

  final DateTime? createdAt;

  final int? userId;

  final String? movieId;

  final UserPartial? user;

  final MoviePartial? movie;

  @override
  Object? get primaryKeyValue {
    return id;
  }

  @override
  WatchlistItemInsertDto toInsertDto() {
    final missing = <String>[];
    if (missing.isNotEmpty) {
      throw StateError(
        'Cannot convert WatchlistItemPartial to WatchlistItemInsertDto: missing required fields: ${missing.join(', ')}',
      );
    }
    return WatchlistItemInsertDto(
      notes: notes,
      createdAt: createdAt,
      userId: userId,
      movieId: movieId,
    );
  }

  @override
  WatchlistItemUpdateDto toUpdateDto() {
    return WatchlistItemUpdateDto(
      notes: notes,
      createdAt: createdAt,
      userId: userId,
      movieId: movieId,
    );
  }

  @override
  WatchlistItem toEntity() {
    final missing = <String>[];
    if (id == null) missing.add('id');
    if (missing.isNotEmpty) {
      throw StateError(
        'Cannot convert WatchlistItemPartial to WatchlistItem: missing required fields: ${missing.join(', ')}',
      );
    }
    return WatchlistItem(
      id: id!,
      notes: notes,
      createdAt: createdAt,
      user: user?.toEntity(),
      movie: movie?.toEntity(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'createdAt': createdAt?.toIso8601String(),
      if (user != null) 'user': user?.toJson(),
      if (movie != null) 'movie': movie?.toJson(),
      if (userId != null) 'userId': userId,
      if (movieId != null) 'movieId': movieId,
    };
  }
}

class WatchlistItemInsertDto implements InsertDto<WatchlistItem> {
  const WatchlistItemInsertDto({
    this.notes,
    this.createdAt,
    this.userId,
    this.movieId,
  });

  final String? notes;

  final DateTime? createdAt;

  final int? userId;

  final String? movieId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'notes': notes,
      'created_at': DateTime.now().toIso8601String(),
      if (userId != null) 'user_id': userId,
      if (movieId != null) 'movie_id': movieId,
    };
  }

  Map<String, dynamic> get cascades {
    return const {};
  }

  WatchlistItemInsertDto copyWith({
    String? notes,
    DateTime? createdAt,
    int? userId,
    String? movieId,
  }) {
    return WatchlistItemInsertDto(
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      movieId: movieId ?? this.movieId,
    );
  }
}

class WatchlistItemUpdateDto implements UpdateDto<WatchlistItem> {
  const WatchlistItemUpdateDto({
    this.notes,
    this.createdAt,
    this.userId,
    this.movieId,
  });

  final String? notes;

  final DateTime? createdAt;

  final int? userId;

  final String? movieId;

  @override
  Map<String, dynamic> toMap() {
    return {
      if (notes != null) 'notes': notes,
      if (createdAt != null)
        'created_at': createdAt is DateTime
            ? (createdAt as DateTime).toIso8601String()
            : createdAt?.toString(),
      if (userId != null) 'user_id': userId,
      if (movieId != null) 'movie_id': movieId,
    };
  }

  Map<String, dynamic> get cascades {
    return const {};
  }
}

class WatchlistItemRepository
    extends EntityRepository<WatchlistItem, WatchlistItemPartial> {
  WatchlistItemRepository(EngineAdapter engine)
    : super(
        $WatchlistItemEntityDescriptor,
        engine,
        $WatchlistItemEntityDescriptor.fieldsContext,
      );
}

extension WatchlistItemJson on WatchlistItem {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'createdAt': createdAt?.toIso8601String(),
      if (user != null) 'user': user?.toJson(),
      if (movie != null) 'movie': movie?.toJson(),
    };
  }
}

extension WatchlistItemCodec on WatchlistItem {
  Object? toEncodable() {
    return toJson();
  }

  String toJsonString() {
    return encodeJsonColumn(toJson()) as String;
  }
}

extension WatchlistItemPartialCodec on WatchlistItemPartial {
  Object? toEncodable() {
    return toJson();
  }

  String toJsonString() {
    return encodeJsonColumn(toJson()) as String;
  }
}

var $isWatchlistItemJsonCodecInitialized = false;
void $initWatchlistItemJsonCodec() {
  if ($isWatchlistItemJsonCodecInitialized) return;
  EntityJsonRegistry.register<WatchlistItem>(
    (value) => WatchlistItemJson(value).toJson(),
  );
  $isWatchlistItemJsonCodecInitialized = true;
}

extension WatchlistItemRepositoryExtensions
    on EntityRepository<WatchlistItem, PartialEntity<WatchlistItem>> {}
