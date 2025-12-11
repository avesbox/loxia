// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'loxia_codegen_example.dart';

// **************************************************************************
// LoxiaEntityGenerator
// **************************************************************************

final EntityDescriptor<User, UserPartial> $UserEntityDescriptor =
    EntityDescriptor<User, UserPartial>(
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
          cascade: const [],
        ),
      ],
      fromRow: (row) => User(
        id: row['id'] as int,
        email: row['email'] as String,
        posts: const <Post>[],
      ),
      toRow: (e) => {'id': e.id, 'email': e.email},
      fieldsContext: const UserFieldsContext(),
    );

class UserFieldsContext extends QueryFieldsContext<User> {
  const UserFieldsContext([QueryRuntimeContext? runtime, String? alias])
    : super(runtime, alias);
  @override
  UserFieldsContext bind(QueryRuntimeContext runtime, String alias) =>
      UserFieldsContext(runtime, alias);
  QueryField<int> get id => field<int>('id');
  QueryField<String> get email => field<String>('email');
  PostFieldsContext get posts {
    // Find the owning relation on the target entity to get join column info
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
  final WhereExpression Function(UserFieldsContext q) _builder;
  @override
  WhereExpression build(QueryFieldsContext<User> context) {
    if (context is! UserFieldsContext) {
      throw ArgumentError('Expected UserFieldsContext for UserQuery');
    }
    return _builder(context);
  }
}

class UserSelect extends SelectOptions<User, UserPartial> {
  const UserSelect({this.id = false, this.email = false, this.relations});
  final bool id;
  final bool email;
  final UserRelations? relations;
  @override
  bool get hasSelections => id || email || (relations?.hasSelections ?? false);
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
    final rels = relations;
    if (rels != null && rels.hasSelections) {
      rels.collect(scoped, out, path: path);
    }
  }

  @override
  UserPartial hydrate(Map<String, dynamic> row, {String? path}) {
    // Collection relation posts requires row aggregation
    return UserPartial(
      id: id ? readValue(row, 'id', path: path) as int? : null,
      email: email ? readValue(row, 'email', path: path) as String? : null,
      posts: null, // Collection requires aggregation
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
      return UserPartial(id: base.id, email: base.email, posts: postsList);
    }).toList();
  }
}

class UserRelations {
  const UserRelations({this.posts});
  final PostSelect? posts;
  bool get hasSelections => (posts?.hasSelections ?? false);
  void collect(
    UserFieldsContext context,
    List<SelectField> out, {
    String? path,
  }) {
    final postsSelect = posts;
    if (postsSelect != null && postsSelect.hasSelections) {
      final relationPath = path == null || path.isEmpty
          ? 'posts'
          : '${path}_posts';
      final relationContext = context.posts;
      postsSelect.collect(relationContext, out, path: relationPath);
    }
  }
}

class UserPartial extends PartialEntity<User> {
  const UserPartial({this.id, this.email, this.posts});

  final int? id;
  final String? email;
  final List<PostPartial>? posts;

  @override
  User toEntity() {
    final missing = <String>[];
    if (id == null) missing.add('id');
    if (email == null) missing.add('email');
    if (missing.isNotEmpty) {
      throw StateError(
        'Cannot convert UserPartial to User: missing required fields: ${missing.join(', ')}',
      );
    }
    return User(
      id: id!,
      email: email!,
      posts: posts?.map((p) => p.toEntity()).toList() ?? const <Post>[],
    );
  }
}

class UserInsertDto implements InsertDto<User> {
  const UserInsertDto({required this.email});
  final String email;

  @override
  Map<String, dynamic> toMap() {
    return {'email': email};
  }
}

class UserUpdateDto implements UpdateDto<User> {
  const UserUpdateDto({this.email});
  final String? email;

  @override
  Map<String, dynamic> toMap() {
    return {if (email != null) 'email': email};
  }
}

final EntityDescriptor<Post, PostPartial> $PostEntityDescriptor =
    EntityDescriptor<Post, PostPartial>(
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
        ),
      ],
      relations: const [
        RelationDescriptor(
          fieldName: 'user',
          type: RelationType.manyToOne,
          target: User,
          isOwningSide: true,
          fetch: RelationFetchStrategy.lazy,
          cascade: [],
          joinColumn: JoinColumnDescriptor(
            name: 'user_id',
            referencedColumnName: 'id',
            nullable: true,
            unique: false,
          ),
        ),
      ],
      fromRow: (row) => Post(
        id: row['id'] as int,
        title: row['title'] as String,
        content: row['content'] as String,
        user: null,
      ),
      toRow: (e) => {
        'id': e.id,
        'title': e.title,
        'content': e.content,
        'user_id': e.user?.id,
      },
      fieldsContext: const PostFieldsContext(),
    );

class PostFieldsContext extends QueryFieldsContext<Post> {
  const PostFieldsContext([super.runtime, super.alias]);
  @override
  PostFieldsContext bind(QueryRuntimeContext runtime, String alias) =>
      PostFieldsContext(runtime, alias);
  QueryField<int> get id => field<int>('id');
  QueryField<String> get title => field<String>('title');
  QueryField<String> get content => field<String>('content');
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
}

class PostQuery extends QueryBuilder<Post> {
  const PostQuery(this._builder);
  final WhereExpression Function(PostFieldsContext q) _builder;
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
    this.id = false,
    this.title = false,
    this.content = false,
    this.userId = false,
    this.relations,
  });
  final bool id;
  final bool title;
  final bool content;
  final bool userId;
  final PostRelations? relations;
  @override
  bool get hasSelections =>
      id || title || content || userId || (relations?.hasSelections ?? false);
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
      id: id ? readValue(row, 'id', path: path) as int? : null,
      title: title ? readValue(row, 'title', path: path) as String? : null,
      content: content
          ? readValue(row, 'content', path: path) as String?
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

class PostRelations {
  const PostRelations({this.user});
  final UserSelect? user;
  bool get hasSelections => (user?.hasSelections ?? false);
  void collect(
    PostFieldsContext context,
    List<SelectField> out, {
    String? path,
  }) {
    final userSelect = user;
    if (userSelect != null && userSelect.hasSelections) {
      final relationPath = path == null || path.isEmpty
          ? 'user'
          : '${path}_user';
      final relationContext = context.user;
      userSelect.collect(relationContext, out, path: relationPath);
    }
  }
}

class PostPartial extends PartialEntity<Post> {
  const PostPartial({
    this.id,
    this.title,
    this.content,
    this.userId,
    this.user,
  });

  final int? id;
  final String? title;
  final String? content;
  final int? userId;
  final UserPartial? user;

  @override
  Post toEntity() {
    final missing = <String>[];
    if (id == null) missing.add('id');
    if (title == null) missing.add('title');
    if (content == null) missing.add('content');
    if (missing.isNotEmpty) {
      throw StateError(
        'Cannot convert PostPartial to Post: missing required fields: ${missing.join(', ')}',
      );
    }
    return Post(
      id: id!,
      title: title!,
      content: content!,
      user: user?.toEntity(),
    );
  }
}

class PostInsertDto implements InsertDto<Post> {
  const PostInsertDto({
    required this.title,
    required this.content,
    this.userId,
  });
  final String title;
  final String content;
  final int? userId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      if (userId != null) 'user_id': userId,
    };
  }
}

class PostUpdateDto implements UpdateDto<Post> {
  const PostUpdateDto({this.title, this.content, this.userId});
  final String? title;
  final String? content;
  final int? userId;

  @override
  Map<String, dynamic> toMap() {
    return {
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (userId != null) 'user_id': userId,
    };
  }
}
