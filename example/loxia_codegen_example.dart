import 'dart:convert';

import 'package:loxia/loxia.dart';
import 'package:postgres/postgres.dart';

part 'loxia_codegen_example.g.dart';

enum Role { admin, user, guest }

/// Represents a merchant account in the system.
@EntityMeta(table: 'merchants')
class Merchant extends Entity {
  /// Creates a merchant record.
  Merchant({
    required this.id,
    required this.name,
    required this.businessName,
    required this.mobileNumber,
    required this.email,
    required this.passwordHash,
    this.createdAt,
    this.updatedAt,
  });

  /// Unique identifier for the merchant.
  @PrimaryKey(uuid: true)
  final String id;

  /// Merchant owner's full name.
  @Column()
  final String name;

  /// Registered business name.
  @Column()
  final String businessName;

  /// Merchant mobile number.
  @Column(unique: true)
  final String mobileNumber;

  /// Merchant email address.
  @Column(unique: true)
  final String email;

  /// Hashed password used for authentication.
  @Column()
  final String passwordHash;

  /// Timestamp when the merchant was created.
  @CreatedAt()
  DateTime? createdAt;

  /// Timestamp when the merchant was last updated.
  @UpdatedAt()
  DateTime? updatedAt;

  /// Entity descriptor used by Loxia for metadata and query operations.
  static EntityDescriptor<Merchant, MerchantPartial> get entity =>
      $MerchantEntityDescriptor;
}

@EntityMeta(
  table: 'users',
  queries: [
    // Full entity return (SELECT *) with LIMIT 1 -> single User
    Query(
      name: 'findByEmail',
      sql: 'SELECT * FROM users WHERE email = @email LIMIT 1',
    ),
    // DTO with aggregate (no GROUP BY) -> single CountUsersResult
    Query(name: 'countUsers', sql: 'SELECT COUNT(*) as total FROM users'),
    // Partial entity - specific columns subset -> List<PartialEntity>
    Query(name: 'getUserEmailsAndRoles', sql: 'SELECT email, role FROM users'),
    // Full entity return without LIMIT -> List<User>
    Query(name: 'findAllUsers', sql: 'SELECT * FROM users'),
  ],
)
class User extends Entity {
  @PrimaryKey(autoIncrement: true)
  final int id;

  @Column()
  final String email;

  @OneToMany(on: Post, mappedBy: 'user', cascade: [RelationCascade.persist])
  final List<Post> posts;

  @Column(type: ColumnType.text)
  final Role role;

  @Column(defaultValue: <String>[])
  final List<String> tags;

  User({
    required this.id,
    required this.email,
    this.posts = const [],
    this.role = Role.user,
    this.tags = const [],
  });

  static EntityDescriptor<User, UserPartial> get entity =>
      $UserEntityDescriptor;
}

@EntityMeta(table: 'posts')
class Post extends Entity {
  @PrimaryKey(uuid: true)
  final String id;

  @Column()
  final String title;

  @Column()
  final String content;

  @Column(defaultValue: 0)
  final int likes;

  @CreatedAt()
  DateTime? createdAt;

  @UpdatedAt()
  int? lastUpdatedAt;

  @DeletedAt()
  DateTime? deletedAt;

  @ManyToOne(on: User)
  final User? user;

  @ManyToMany(
    on: Tag,
    cascade: [RelationCascade.persist, RelationCascade.remove],
  )
  @JoinTable(
    name: 'post_tags',
    joinColumns: [JoinColumn(name: 'post_id', referencedColumnName: 'id')],
    inverseJoinColumns: [
      JoinColumn(name: 'tag_id', referencedColumnName: 'id'),
    ],
  )
  final List<Tag> tags;

  Post({
    required this.id,
    required this.title,
    this.createdAt,
    this.lastUpdatedAt,
    this.deletedAt,
    required this.content,
    required this.likes,
    this.user,
    this.tags = const [],
  });

  static EntityDescriptor<Post, PostPartial> get entity =>
      $PostEntityDescriptor;

  @PreRemove()
  void beforeDelete() {
    print('About to delete Post with id=$id');
  }
}

@EntityMeta()
class Tag extends Entity {
  @PrimaryKey(autoIncrement: true)
  final int id;

  @Column()
  final String name;

  @ManyToMany(on: Post, mappedBy: 'tags')
  final List<Post> posts;

  Tag({required this.id, required this.name, this.posts = const []});

  static EntityDescriptor<Tag, TagPartial> get entity => $TagEntityDescriptor;
}

@EntityMeta(table: 'subscriptions')
class Subscription extends Entity {
  Subscription({
    required this.id,
    required this.plan,
    required this.status,
    required this.currentPeriodEnd,
    this.createdAt,
    this.updatedAt,
  });

  @PrimaryKey(uuid: true)
  final String id;

  @Column(type: ColumnType.text)
  final Plan plan;

  @Column(type: ColumnType.text)
  final SubscriptionStatus status;

  @Column()
  final DateTime currentPeriodEnd;

  @CreatedAt()
  DateTime? createdAt;

  @UpdatedAt()
  DateTime? updatedAt;

  static EntityDescriptor<Subscription, SubscriptionPartial> get entity =>
      $SubscriptionEntityDescriptor;
}

enum Plan { basic, pro }

enum SubscriptionStatus { active, expired, canceled, trial }

@EntityMeta(table: 'movies')
class Movie extends Entity {
  Movie({
    required this.id,
    required this.title,
    required this.releaseYear,
    required this.genres,
    this.overview,
    this.runtime,
    this.posterUrl,
    this.createdAt,
    this.updatedAt,
  });

  @PrimaryKey(uuid: true)
  final String id;

  @Column()
  final String title;

  @Column()
  String? overview;

  @Column()
  final int releaseYear;

  @Column(defaultValue: <String>[])
  final List<String> genres;

  @Column()
  int? runtime;

  @Column()
  String? posterUrl;

  @CreatedAt()
  DateTime? createdAt;

  @UpdatedAt()
  DateTime? updatedAt;

  static EntityDescriptor<Movie, MoviePartial> get entity =>
      $MovieEntityDescriptor;
}

/// Example of using composite unique constraints.
///
/// This entity demonstrates the Prisma-like `@@unique([userId, movieId])`
/// pattern in Loxia using the `uniqueConstraints` parameter.
@EntityMeta(
  table: 'watchlist_items',
  uniqueConstraints: [
    // Enforces that a user can only have one entry per movie in their watchlist
    UniqueConstraint(columns: ['user_id', 'movie_id']),
  ],
)
class WatchlistItem extends Entity {
  @PrimaryKey(autoIncrement: true)
  final int id;

  @ManyToOne(on: User)
  final User? user;

  @ManyToOne(on: Movie)
  final Movie? movie;

  @Column()
  final String? notes;

  @CreatedAt()
  DateTime? createdAt;

  WatchlistItem({
    required this.id,
    this.user,
    this.movie,
    this.notes,
    this.createdAt,
  });

  static EntityDescriptor<WatchlistItem, WatchlistItemPartial> get entity =>
      $WatchlistItemEntityDescriptor;
}

class UniqueConstraintMigration extends Migration {
  UniqueConstraintMigration(super.version);

  @override
  Future<void> up(EngineAdapter engine) async {
    await engine.execute('''
      ALTER TABLE users
      ADD CONSTRAINT unique_email UNIQUE (email);
    ''');
  }

  @override
  Future<void> down(EngineAdapter engine) async {
    await engine.execute('''
      ALTER TABLE users
      DROP CONSTRAINT unique_email;
    ''');
  }
}

Future<void> main() async {
  final ds = DataSource(
    // InMemoryDataSourceOptions(
    //   entities: [User.entity, Post.entity, Tag.entity],
    //   migrations: [],
    // ),
    PostgresDataSourceOptions.connect(
      host: 'localhost',
      port: 5432,
      database: 'loxia',
      username: 'loxia',
      password: 'test1234',
      entities: [User.entity, Post.entity, Tag.entity],
      settings: ConnectionSettings(sslMode: SslMode.disable),
    ),
  );
  await ds.init();
  final users = ds.getRepository<User>();
  final Stopwatch stopwatch = Stopwatch()..start();
  await users.save(
    UserPartial(
      email: 'example@example.com',
      role: Role.guest,
      tags: ['new', 'test'],
      posts: [
        PostPartial(
          title: 'My First Post',
          content: 'This is the content of my first post',
          likes: 0,
        ),
      ],
    ),
  );
  print('User created in ${stopwatch.elapsedMilliseconds} ms');
  stopwatch.stop();
  await users.update(
    UserUpdateDto(email: 'new@example.com'),
    where: UserQuery((q) => q.id.equals(1)),
  );
  await users.findByEmail('new@example.com');
  final user = await users.findOne(
    where: UserQuery((q) => q.email.equals('new@example.com')),
    select: UserSelect(relations: UserRelations(posts: PostSelect())),
  );
  final partial = user as UserPartial?;
  print('User: id=${jsonEncode(user?.toJson())}');
  final posts = ds.getRepository<Post>();
  final newPost = await posts.save(
    PostPartial(
      title: 'Hello World',
      content: 'This is my first post',
      likes: 0,
      userId: partial?.id,
    ),
  );
  await posts.softDeleteEntity(newPost);
  final post = await posts.findOne(
    where: PostQuery(
      (q) => q.id.equals(newPost.id).and(q.userId.equals(partial?.id ?? 0)),
    ),
    select: PostSelect(relations: PostRelations(user: UserSelect())),
    includeDeleted: true,
  );
  final partialPost = post as PostPartial?;
  print(
    'Post: id=${partialPost?.id}, title=${partialPost?.title}, content=${partialPost?.content}, likes=${partialPost?.likes}, userId=${partialPost?.user?.id} - ${partialPost?.createdAt} - ${partialPost?.lastUpdatedAt} - ${partialPost?.user?.toJsonString()}',
  );
  await ds.dispose();
}
