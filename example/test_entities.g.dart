// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'test_entities.dart';

// **************************************************************************
// LoxiaEntityGenerator
// **************************************************************************

final EntityDescriptor<
  TodoWithNonNullableOwner,
  TodoWithNonNullableOwnerPartial
>
$TodoWithNonNullableOwnerEntityDescriptor = () {
  $initTodoWithNonNullableOwnerJsonCodec();
  return EntityDescriptor(
    entityType: TodoWithNonNullableOwner,
    tableName: 'todos',
    columns: [
      ColumnDescriptor(
        name: 'id',
        propertyName: 'id',
        type: ColumnType.integer,
        nullable: true,
        unique: false,
        isPrimaryKey: true,
        autoIncrement: true,
        uuid: false,
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
    ],
    relations: const [
      RelationDescriptor(
        fieldName: 'owner',
        type: RelationType.manyToOne,
        target: User,
        isOwningSide: true,
        fetch: RelationFetchStrategy.lazy,
        cascade: const [],
        cascadePersist: false,
        cascadeMerge: false,
        cascadeRemove: false,
        joinColumn: JoinColumnDescriptor(
          name: 'owner_id',
          referencedColumnName: 'id',
          nullable: false,
          unique: false,
        ),
      ),
    ],
    fromRow: (row) => TodoWithNonNullableOwner(
      id: (row['id'] as int?),
      title: (row['title'] as String),
      owner: null,
    ),
    toRow: (e) => {'id': e.id, 'title': e.title, 'owner_id': e.owner?.id},
    fieldsContext: const TodoWithNonNullableOwnerFieldsContext(),
    repositoryFactory: (EngineAdapter engine) =>
        TodoWithNonNullableOwnerRepository(engine),
    defaultSelect: () => TodoWithNonNullableOwnerSelect(),
  );
}();

class TodoWithNonNullableOwnerFieldsContext
    extends QueryFieldsContext<TodoWithNonNullableOwner> {
  const TodoWithNonNullableOwnerFieldsContext([
    super.runtimeContext,
    super.alias,
  ]);

  @override
  TodoWithNonNullableOwnerFieldsContext bind(
    QueryRuntimeContext runtimeContext,
    String alias,
  ) => TodoWithNonNullableOwnerFieldsContext(runtimeContext, alias);

  QueryField<int?> get id => field<int?>('id');

  QueryField<String> get title => field<String>('title');

  QueryField<int> get ownerId => field<int>('owner_id');

  UserFieldsContext get owner {
    final alias = ensureRelationJoin(
      relationName: 'owner',
      targetTableName: $UserEntityDescriptor.qualifiedTableName,
      localColumn: 'owner_id',
      foreignColumn: 'id',
      joinType: JoinType.left,
    );
    return UserFieldsContext(runtimeOrThrow, alias);
  }
}

class TodoWithNonNullableOwnerQuery
    extends QueryBuilder<TodoWithNonNullableOwner> {
  const TodoWithNonNullableOwnerQuery(this._builder);

  final WhereExpression Function(TodoWithNonNullableOwnerFieldsContext)
  _builder;

  @override
  WhereExpression build(QueryFieldsContext<TodoWithNonNullableOwner> context) {
    if (context is! TodoWithNonNullableOwnerFieldsContext) {
      throw ArgumentError(
        'Expected TodoWithNonNullableOwnerFieldsContext for TodoWithNonNullableOwnerQuery',
      );
    }
    return _builder(context);
  }
}

class TodoWithNonNullableOwnerSelect
    extends
        SelectOptions<
          TodoWithNonNullableOwner,
          TodoWithNonNullableOwnerPartial
        > {
  const TodoWithNonNullableOwnerSelect({
    this.id = true,
    this.title = true,
    this.ownerId = true,
    this.relations,
  });

  final bool id;

  final bool title;

  final bool ownerId;

  final TodoWithNonNullableOwnerRelations? relations;

  @override
  bool get hasSelections =>
      id || title || ownerId || (relations?.hasSelections ?? false);

  @override
  SelectOptions<TodoWithNonNullableOwner, TodoWithNonNullableOwnerPartial>
  withRelations(
    RelationsOptions<TodoWithNonNullableOwner, TodoWithNonNullableOwnerPartial>?
    relations,
  ) {
    return TodoWithNonNullableOwnerSelect(
      id: id,
      title: title,
      ownerId: ownerId,
      relations: relations as TodoWithNonNullableOwnerRelations?,
    );
  }

  @override
  void collect(
    QueryFieldsContext<TodoWithNonNullableOwner> context,
    List<SelectField> out, {
    String? path,
  }) {
    if (context is! TodoWithNonNullableOwnerFieldsContext) {
      throw ArgumentError(
        'Expected TodoWithNonNullableOwnerFieldsContext for TodoWithNonNullableOwnerSelect',
      );
    }
    final TodoWithNonNullableOwnerFieldsContext scoped = context;
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
    if (ownerId) {
      out.add(
        SelectField(
          'owner_id',
          tableAlias: tableAlias,
          alias: aliasFor('owner_id'),
        ),
      );
    }
    final rels = relations;
    if (rels != null && rels.hasSelections) {
      rels.collect(scoped, out, path: path);
    }
  }

  @override
  TodoWithNonNullableOwnerPartial hydrate(
    Map<String, dynamic> row, {
    String? path,
  }) {
    UserPartial? ownerPartial;
    final ownerSelect = relations?.owner;
    if (ownerSelect != null && ownerSelect.hasSelections) {
      ownerPartial = ownerSelect.hydrate(row, path: extendPath(path, 'owner'));
    }
    return TodoWithNonNullableOwnerPartial(
      id: id ? readValue(row, 'id', path: path) as int? : null,
      title: title ? readValue(row, 'title', path: path) as String : null,
      ownerId: ownerId ? readValue(row, 'owner_id', path: path) as int? : null,
      owner: ownerPartial,
    );
  }

  @override
  bool get hasCollectionRelations => false;

  @override
  String? get primaryKeyColumn => 'id';
}

class TodoWithNonNullableOwnerRelations
    extends
        RelationsOptions<
          TodoWithNonNullableOwner,
          TodoWithNonNullableOwnerPartial
        > {
  const TodoWithNonNullableOwnerRelations({this.owner});

  final UserSelect? owner;

  @override
  bool get hasSelections => (owner?.hasSelections ?? false);

  @override
  void collect(
    QueryFieldsContext<TodoWithNonNullableOwner> context,
    List<SelectField> out, {
    String? path,
  }) {
    if (context is! TodoWithNonNullableOwnerFieldsContext) {
      throw ArgumentError(
        'Expected TodoWithNonNullableOwnerFieldsContext for TodoWithNonNullableOwnerRelations',
      );
    }
    final TodoWithNonNullableOwnerFieldsContext scoped = context;

    final ownerSelect = owner;
    if (ownerSelect != null && ownerSelect.hasSelections) {
      final relationPath = path == null || path.isEmpty
          ? 'owner'
          : '${path}_owner';
      final relationContext = scoped.owner;
      ownerSelect.collect(relationContext, out, path: relationPath);
    }
  }
}

class TodoWithNonNullableOwnerPartial
    extends PartialEntity<TodoWithNonNullableOwner> {
  const TodoWithNonNullableOwnerPartial({
    this.id,
    this.title,
    this.ownerId,
    this.owner,
  });

  final int? id;

  final String? title;

  final int? ownerId;

  final UserPartial? owner;

  @override
  Object? get primaryKeyValue {
    return id;
  }

  @override
  TodoWithNonNullableOwnerInsertDto toInsertDto() {
    final missing = <String>[];
    if (title == null) missing.add('title');
    if (ownerId == null) missing.add('ownerId');
    if (missing.isNotEmpty) {
      throw StateError(
        'Cannot convert TodoWithNonNullableOwnerPartial to TodoWithNonNullableOwnerInsertDto: missing required fields: ${missing.join(', ')}',
      );
    }
    return TodoWithNonNullableOwnerInsertDto(title: title!, ownerId: ownerId!);
  }

  @override
  TodoWithNonNullableOwnerUpdateDto toUpdateDto() {
    return TodoWithNonNullableOwnerUpdateDto(title: title, ownerId: ownerId);
  }

  @override
  TodoWithNonNullableOwner toEntity() {
    final missing = <String>[];
    if (title == null) missing.add('title');
    if (missing.isNotEmpty) {
      throw StateError(
        'Cannot convert TodoWithNonNullableOwnerPartial to TodoWithNonNullableOwner: missing required fields: ${missing.join(', ')}',
      );
    }
    return TodoWithNonNullableOwner(
      id: id,
      title: title!,
      owner: owner?.toEntity(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (owner != null) 'owner': owner?.toJson(),
      if (ownerId != null) 'ownerId': ownerId,
    };
  }
}

class TodoWithNonNullableOwnerInsertDto
    implements InsertDto<TodoWithNonNullableOwner> {
  const TodoWithNonNullableOwnerInsertDto({
    required this.title,
    required this.ownerId,
  });

  final String title;

  final int ownerId;

  @override
  Map<String, dynamic> toMap() {
    return {'title': title, 'owner_id': ownerId};
  }

  Map<String, dynamic> get cascades {
    return const {};
  }

  TodoWithNonNullableOwnerInsertDto copyWith({String? title, int? ownerId}) {
    return TodoWithNonNullableOwnerInsertDto(
      title: title ?? this.title,
      ownerId: ownerId ?? this.ownerId,
    );
  }
}

class TodoWithNonNullableOwnerUpdateDto
    implements UpdateDto<TodoWithNonNullableOwner> {
  const TodoWithNonNullableOwnerUpdateDto({this.title, this.ownerId});

  final String? title;

  final int? ownerId;

  @override
  Map<String, dynamic> toMap() {
    return {
      if (title != null) 'title': title,
      if (ownerId != null) 'owner_id': ownerId,
    };
  }

  Map<String, dynamic> get cascades {
    return const {};
  }
}

class TodoWithNonNullableOwnerRepository
    extends
        EntityRepository<
          TodoWithNonNullableOwner,
          TodoWithNonNullableOwnerPartial
        > {
  TodoWithNonNullableOwnerRepository(EngineAdapter engine)
    : super(
        $TodoWithNonNullableOwnerEntityDescriptor,
        engine,
        $TodoWithNonNullableOwnerEntityDescriptor.fieldsContext,
      );
}

extension TodoWithNonNullableOwnerJson on TodoWithNonNullableOwner {
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      if (owner != null) 'owner': owner?.toJson(),
    };
  }
}

extension TodoWithNonNullableOwnerCodec on TodoWithNonNullableOwner {
  Object? toEncodable() {
    return toJson();
  }

  String toJsonString() {
    return encodeJsonColumn(toJson()) as String;
  }
}

extension TodoWithNonNullableOwnerPartialCodec
    on TodoWithNonNullableOwnerPartial {
  Object? toEncodable() {
    return toJson();
  }

  String toJsonString() {
    return encodeJsonColumn(toJson()) as String;
  }
}

var $isTodoWithNonNullableOwnerJsonCodecInitialized = false;
void $initTodoWithNonNullableOwnerJsonCodec() {
  if ($isTodoWithNonNullableOwnerJsonCodecInitialized) return;
  EntityJsonRegistry.register<TodoWithNonNullableOwner>(
    (value) => TodoWithNonNullableOwnerJson(value).toJson(),
  );
  $isTodoWithNonNullableOwnerJsonCodecInitialized = true;
}

extension TodoWithNonNullableOwnerRepositoryExtensions
    on
        EntityRepository<
          TodoWithNonNullableOwner,
          PartialEntity<TodoWithNonNullableOwner>
        > {}

final EntityDescriptor<CommentWithNullablePost, CommentWithNullablePostPartial>
$CommentWithNullablePostEntityDescriptor = () {
  $initCommentWithNullablePostJsonCodec();
  return EntityDescriptor(
    entityType: CommentWithNullablePost,
    tableName: 'comments',
    columns: [
      ColumnDescriptor(
        name: 'id',
        propertyName: 'id',
        type: ColumnType.integer,
        nullable: true,
        unique: false,
        isPrimaryKey: true,
        autoIncrement: true,
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
    ],
    relations: const [
      RelationDescriptor(
        fieldName: 'post',
        type: RelationType.manyToOne,
        target: Post,
        isOwningSide: true,
        fetch: RelationFetchStrategy.lazy,
        cascade: const [],
        cascadePersist: false,
        cascadeMerge: false,
        cascadeRemove: false,
        joinColumn: JoinColumnDescriptor(
          name: 'post_id',
          referencedColumnName: 'id',
          nullable: true,
          unique: false,
        ),
      ),
    ],
    fromRow: (row) => CommentWithNullablePost(
      id: (row['id'] as int?),
      content: (row['content'] as String),
      post: null,
    ),
    toRow: (e) => {'id': e.id, 'content': e.content, 'post_id': e.post?.id},
    fieldsContext: const CommentWithNullablePostFieldsContext(),
    repositoryFactory: (EngineAdapter engine) =>
        CommentWithNullablePostRepository(engine),
    defaultSelect: () => CommentWithNullablePostSelect(),
  );
}();

class CommentWithNullablePostFieldsContext
    extends QueryFieldsContext<CommentWithNullablePost> {
  const CommentWithNullablePostFieldsContext([
    super.runtimeContext,
    super.alias,
  ]);

  @override
  CommentWithNullablePostFieldsContext bind(
    QueryRuntimeContext runtimeContext,
    String alias,
  ) => CommentWithNullablePostFieldsContext(runtimeContext, alias);

  QueryField<int?> get id => field<int?>('id');

  QueryField<String> get content => field<String>('content');

  QueryField<int?> get postId => field<int?>('post_id');

  PostFieldsContext get post {
    final alias = ensureRelationJoin(
      relationName: 'post',
      targetTableName: $PostEntityDescriptor.qualifiedTableName,
      localColumn: 'post_id',
      foreignColumn: 'id',
      joinType: JoinType.left,
    );
    return PostFieldsContext(runtimeOrThrow, alias);
  }
}

class CommentWithNullablePostQuery
    extends QueryBuilder<CommentWithNullablePost> {
  const CommentWithNullablePostQuery(this._builder);

  final WhereExpression Function(CommentWithNullablePostFieldsContext) _builder;

  @override
  WhereExpression build(QueryFieldsContext<CommentWithNullablePost> context) {
    if (context is! CommentWithNullablePostFieldsContext) {
      throw ArgumentError(
        'Expected CommentWithNullablePostFieldsContext for CommentWithNullablePostQuery',
      );
    }
    return _builder(context);
  }
}

class CommentWithNullablePostSelect
    extends
        SelectOptions<CommentWithNullablePost, CommentWithNullablePostPartial> {
  const CommentWithNullablePostSelect({
    this.id = true,
    this.content = true,
    this.postId = true,
    this.relations,
  });

  final bool id;

  final bool content;

  final bool postId;

  final CommentWithNullablePostRelations? relations;

  @override
  bool get hasSelections =>
      id || content || postId || (relations?.hasSelections ?? false);

  @override
  SelectOptions<CommentWithNullablePost, CommentWithNullablePostPartial>
  withRelations(
    RelationsOptions<CommentWithNullablePost, CommentWithNullablePostPartial>?
    relations,
  ) {
    return CommentWithNullablePostSelect(
      id: id,
      content: content,
      postId: postId,
      relations: relations as CommentWithNullablePostRelations?,
    );
  }

  @override
  void collect(
    QueryFieldsContext<CommentWithNullablePost> context,
    List<SelectField> out, {
    String? path,
  }) {
    if (context is! CommentWithNullablePostFieldsContext) {
      throw ArgumentError(
        'Expected CommentWithNullablePostFieldsContext for CommentWithNullablePostSelect',
      );
    }
    final CommentWithNullablePostFieldsContext scoped = context;
    String? aliasFor(String column) {
      final current = path;
      if (current == null || current.isEmpty) return null;
      return '${current}_$column';
    }

    final tableAlias = scoped.currentAlias;
    if (id) {
      out.add(SelectField('id', tableAlias: tableAlias, alias: aliasFor('id')));
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
    if (postId) {
      out.add(
        SelectField(
          'post_id',
          tableAlias: tableAlias,
          alias: aliasFor('post_id'),
        ),
      );
    }
    final rels = relations;
    if (rels != null && rels.hasSelections) {
      rels.collect(scoped, out, path: path);
    }
  }

  @override
  CommentWithNullablePostPartial hydrate(
    Map<String, dynamic> row, {
    String? path,
  }) {
    PostPartial? postPartial;
    final postSelect = relations?.post;
    if (postSelect != null && postSelect.hasSelections) {
      postPartial = postSelect.hydrate(row, path: extendPath(path, 'post'));
    }
    return CommentWithNullablePostPartial(
      id: id ? readValue(row, 'id', path: path) as int? : null,
      content: content ? readValue(row, 'content', path: path) as String : null,
      postId: postId ? readValue(row, 'post_id', path: path) as int? : null,
      post: postPartial,
    );
  }

  @override
  bool get hasCollectionRelations => false;

  @override
  String? get primaryKeyColumn => 'id';
}

class CommentWithNullablePostRelations
    extends
        RelationsOptions<
          CommentWithNullablePost,
          CommentWithNullablePostPartial
        > {
  const CommentWithNullablePostRelations({this.post});

  final PostSelect? post;

  @override
  bool get hasSelections => (post?.hasSelections ?? false);

  @override
  void collect(
    QueryFieldsContext<CommentWithNullablePost> context,
    List<SelectField> out, {
    String? path,
  }) {
    if (context is! CommentWithNullablePostFieldsContext) {
      throw ArgumentError(
        'Expected CommentWithNullablePostFieldsContext for CommentWithNullablePostRelations',
      );
    }
    final CommentWithNullablePostFieldsContext scoped = context;

    final postSelect = post;
    if (postSelect != null && postSelect.hasSelections) {
      final relationPath = path == null || path.isEmpty
          ? 'post'
          : '${path}_post';
      final relationContext = scoped.post;
      postSelect.collect(relationContext, out, path: relationPath);
    }
  }
}

class CommentWithNullablePostPartial
    extends PartialEntity<CommentWithNullablePost> {
  const CommentWithNullablePostPartial({
    this.id,
    this.content,
    this.postId,
    this.post,
  });

  final int? id;

  final String? content;

  final int? postId;

  final PostPartial? post;

  @override
  Object? get primaryKeyValue {
    return id;
  }

  @override
  CommentWithNullablePostInsertDto toInsertDto() {
    final missing = <String>[];
    if (content == null) missing.add('content');
    if (missing.isNotEmpty) {
      throw StateError(
        'Cannot convert CommentWithNullablePostPartial to CommentWithNullablePostInsertDto: missing required fields: ${missing.join(', ')}',
      );
    }
    return CommentWithNullablePostInsertDto(content: content!, postId: postId);
  }

  @override
  CommentWithNullablePostUpdateDto toUpdateDto() {
    return CommentWithNullablePostUpdateDto(content: content, postId: postId);
  }

  @override
  CommentWithNullablePost toEntity() {
    final missing = <String>[];
    if (content == null) missing.add('content');
    if (missing.isNotEmpty) {
      throw StateError(
        'Cannot convert CommentWithNullablePostPartial to CommentWithNullablePost: missing required fields: ${missing.join(', ')}',
      );
    }
    return CommentWithNullablePost(
      id: id,
      content: content!,
      post: post?.toEntity(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (content != null) 'content': content,
      if (post != null) 'post': post?.toJson(),
      if (postId != null) 'postId': postId,
    };
  }
}

class CommentWithNullablePostInsertDto
    implements InsertDto<CommentWithNullablePost> {
  const CommentWithNullablePostInsertDto({required this.content, this.postId});

  final String content;

  final int? postId;

  @override
  Map<String, dynamic> toMap() {
    return {'content': content, if (postId != null) 'post_id': postId};
  }

  Map<String, dynamic> get cascades {
    return const {};
  }

  CommentWithNullablePostInsertDto copyWith({String? content, int? postId}) {
    return CommentWithNullablePostInsertDto(
      content: content ?? this.content,
      postId: postId ?? this.postId,
    );
  }
}

class CommentWithNullablePostUpdateDto
    implements UpdateDto<CommentWithNullablePost> {
  const CommentWithNullablePostUpdateDto({this.content, this.postId});

  final String? content;

  final int? postId;

  @override
  Map<String, dynamic> toMap() {
    return {
      if (content != null) 'content': content,
      if (postId != null) 'post_id': postId,
    };
  }

  Map<String, dynamic> get cascades {
    return const {};
  }
}

class CommentWithNullablePostRepository
    extends
        EntityRepository<
          CommentWithNullablePost,
          CommentWithNullablePostPartial
        > {
  CommentWithNullablePostRepository(EngineAdapter engine)
    : super(
        $CommentWithNullablePostEntityDescriptor,
        engine,
        $CommentWithNullablePostEntityDescriptor.fieldsContext,
      );
}

extension CommentWithNullablePostJson on CommentWithNullablePost {
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'content': content,
      if (post != null) 'post': post?.toJson(),
    };
  }
}

extension CommentWithNullablePostCodec on CommentWithNullablePost {
  Object? toEncodable() {
    return toJson();
  }

  String toJsonString() {
    return encodeJsonColumn(toJson()) as String;
  }
}

extension CommentWithNullablePostPartialCodec
    on CommentWithNullablePostPartial {
  Object? toEncodable() {
    return toJson();
  }

  String toJsonString() {
    return encodeJsonColumn(toJson()) as String;
  }
}

var $isCommentWithNullablePostJsonCodecInitialized = false;
void $initCommentWithNullablePostJsonCodec() {
  if ($isCommentWithNullablePostJsonCodecInitialized) return;
  EntityJsonRegistry.register<CommentWithNullablePost>(
    (value) => CommentWithNullablePostJson(value).toJson(),
  );
  $isCommentWithNullablePostJsonCodecInitialized = true;
}

extension CommentWithNullablePostRepositoryExtensions
    on
        EntityRepository<
          CommentWithNullablePost,
          PartialEntity<CommentWithNullablePost>
        > {}

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
    relations: const [],
    fromRow: (row) =>
        User(id: (row['id'] as int), name: (row['name'] as String)),
    toRow: (e) => {'id': e.id, 'name': e.name},
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

  QueryField<String> get name => field<String>('name');
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
  const UserSelect({this.id = true, this.name = true, this.relations});

  final bool id;

  final bool name;

  final UserRelations? relations;

  @override
  bool get hasSelections => id || name || (relations?.hasSelections ?? false);

  @override
  SelectOptions<User, UserPartial> withRelations(
    RelationsOptions<User, UserPartial>? relations,
  ) {
    return UserSelect(
      id: id,
      name: name,
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
  UserPartial hydrate(Map<String, dynamic> row, {String? path}) {
    return UserPartial(
      id: id ? readValue(row, 'id', path: path) as int : null,
      name: name ? readValue(row, 'name', path: path) as String : null,
    );
  }

  @override
  bool get hasCollectionRelations => false;

  @override
  String? get primaryKeyColumn => 'id';
}

class UserRelations extends RelationsOptions<User, UserPartial> {
  const UserRelations();

  @override
  bool get hasSelections => false;

  @override
  void collect(
    QueryFieldsContext<User> context,
    List<SelectField> out, {
    String? path,
  }) {
    if (context is! UserFieldsContext) {
      throw ArgumentError('Expected UserFieldsContext for UserRelations');
    }
  }
}

class UserPartial extends PartialEntity<User> {
  const UserPartial({this.id, this.name});

  final int? id;

  final String? name;

  @override
  Object? get primaryKeyValue {
    return id;
  }

  @override
  UserInsertDto toInsertDto() {
    final missing = <String>[];
    if (name == null) missing.add('name');
    if (missing.isNotEmpty) {
      throw StateError(
        'Cannot convert UserPartial to UserInsertDto: missing required fields: ${missing.join(', ')}',
      );
    }
    return UserInsertDto(name: name!);
  }

  @override
  UserUpdateDto toUpdateDto() {
    return UserUpdateDto(name: name);
  }

  @override
  User toEntity() {
    final missing = <String>[];
    if (id == null) missing.add('id');
    if (name == null) missing.add('name');
    if (missing.isNotEmpty) {
      throw StateError(
        'Cannot convert UserPartial to User: missing required fields: ${missing.join(', ')}',
      );
    }
    return User(id: id!, name: name!);
  }

  @override
  Map<String, dynamic> toJson() {
    return {if (id != null) 'id': id, if (name != null) 'name': name};
  }
}

class UserInsertDto implements InsertDto<User> {
  const UserInsertDto({required this.name});

  final String name;

  @override
  Map<String, dynamic> toMap() {
    return {'name': name};
  }

  Map<String, dynamic> get cascades {
    return const {};
  }

  UserInsertDto copyWith({String? name}) {
    return UserInsertDto(name: name ?? this.name);
  }
}

class UserUpdateDto implements UpdateDto<User> {
  const UserUpdateDto({this.name});

  final String? name;

  @override
  Map<String, dynamic> toMap() {
    return {if (name != null) 'name': name};
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
    return {'id': id, 'name': name};
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

extension UserRepositoryExtensions
    on EntityRepository<User, PartialEntity<User>> {}

final EntityDescriptor<Post, PostPartial> $PostEntityDescriptor = () {
  $initPostJsonCodec();
  return EntityDescriptor(
    entityType: Post,
    tableName: 'posts',
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
    ],
    relations: const [],
    fromRow: (row) =>
        Post(id: (row['id'] as int), title: (row['title'] as String)),
    toRow: (e) => {'id': e.id, 'title': e.title},
    fieldsContext: const PostFieldsContext(),
    repositoryFactory: (EngineAdapter engine) => PostRepository(engine),
    defaultSelect: () => PostSelect(),
  );
}();

class PostFieldsContext extends QueryFieldsContext<Post> {
  const PostFieldsContext([super.runtimeContext, super.alias]);

  @override
  PostFieldsContext bind(QueryRuntimeContext runtimeContext, String alias) =>
      PostFieldsContext(runtimeContext, alias);

  QueryField<int> get id => field<int>('id');

  QueryField<String> get title => field<String>('title');
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
  const PostSelect({this.id = true, this.title = true, this.relations});

  final bool id;

  final bool title;

  final PostRelations? relations;

  @override
  bool get hasSelections => id || title || (relations?.hasSelections ?? false);

  @override
  SelectOptions<Post, PostPartial> withRelations(
    RelationsOptions<Post, PostPartial>? relations,
  ) {
    return PostSelect(
      id: id,
      title: title,
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
    final rels = relations;
    if (rels != null && rels.hasSelections) {
      rels.collect(scoped, out, path: path);
    }
  }

  @override
  PostPartial hydrate(Map<String, dynamic> row, {String? path}) {
    return PostPartial(
      id: id ? readValue(row, 'id', path: path) as int : null,
      title: title ? readValue(row, 'title', path: path) as String : null,
    );
  }

  @override
  bool get hasCollectionRelations => false;

  @override
  String? get primaryKeyColumn => 'id';
}

class PostRelations extends RelationsOptions<Post, PostPartial> {
  const PostRelations();

  @override
  bool get hasSelections => false;

  @override
  void collect(
    QueryFieldsContext<Post> context,
    List<SelectField> out, {
    String? path,
  }) {
    if (context is! PostFieldsContext) {
      throw ArgumentError('Expected PostFieldsContext for PostRelations');
    }
  }
}

class PostPartial extends PartialEntity<Post> {
  const PostPartial({this.id, this.title});

  final int? id;

  final String? title;

  @override
  Object? get primaryKeyValue {
    return id;
  }

  @override
  PostInsertDto toInsertDto() {
    final missing = <String>[];
    if (title == null) missing.add('title');
    if (missing.isNotEmpty) {
      throw StateError(
        'Cannot convert PostPartial to PostInsertDto: missing required fields: ${missing.join(', ')}',
      );
    }
    return PostInsertDto(title: title!);
  }

  @override
  PostUpdateDto toUpdateDto() {
    return PostUpdateDto(title: title);
  }

  @override
  Post toEntity() {
    final missing = <String>[];
    if (id == null) missing.add('id');
    if (title == null) missing.add('title');
    if (missing.isNotEmpty) {
      throw StateError(
        'Cannot convert PostPartial to Post: missing required fields: ${missing.join(', ')}',
      );
    }
    return Post(id: id!, title: title!);
  }

  @override
  Map<String, dynamic> toJson() {
    return {if (id != null) 'id': id, if (title != null) 'title': title};
  }
}

class PostInsertDto implements InsertDto<Post> {
  const PostInsertDto({required this.title});

  final String title;

  @override
  Map<String, dynamic> toMap() {
    return {'title': title};
  }

  Map<String, dynamic> get cascades {
    return const {};
  }

  PostInsertDto copyWith({String? title}) {
    return PostInsertDto(title: title ?? this.title);
  }
}

class PostUpdateDto implements UpdateDto<Post> {
  const PostUpdateDto({this.title});

  final String? title;

  @override
  Map<String, dynamic> toMap() {
    return {if (title != null) 'title': title};
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
    return {'id': id, 'title': title};
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
