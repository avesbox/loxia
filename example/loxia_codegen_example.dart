import 'package:loxia/loxia.dart';
import 'package:postgres/postgres.dart';

part 'loxia_codegen_example.g.dart';

enum Role { admin, user, guest }

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
    InMemoryDataSourceOptions(
      entities: [User.entity, Post.entity, Tag.entity],
      migrations: [UniqueConstraintMigration(1)],
    ),
    // PostgresDataSourceOptions.connect(
    //   host: 'localhost',
    //   port: 5432,
    //   database: 'loxia',
    //   username: 'loxia',
    //   password: 'test1234',
    //   entities: [User.entity, Post.entity, Tag.entity],
    //   settings: ConnectionSettings(sslMode: SslMode.disable),
    // ),
  );
  await ds.init();
  final users = ds.getRepository<User>();
  await users.save(
    UserPartial(
      email: 'example@example.com',
      role: Role.guest,
      tags: ['new', 'test'],
    ),
  );
  await users.update(
    UserUpdateDto(email: 'new@example.com'),
    where: UserQuery((q) => q.id.equals(1)),
  );
  await users.findByEmail('new@example.com');
  final user = await users.findOneBy(
    where: UserQuery((q) => q.email.equals('new@example.com')),
  );
  print('User: id=${user?.toJson()}');
  final posts = ds.getRepository<Post>();
  await posts.save(
    PostPartial(
      title: 'Hello World',
      content: 'This is my first post',
      likes: 0,
      userId: user?.id,
    ),
  );
  final post = await posts.findOne(
    where: PostQuery((q) => q.title.equals('Hello World')),
  );
  final partialPost = post as PostPartial?;
  print(
    'Post: id=${partialPost?.id}, title=${partialPost?.title}, content=${partialPost?.content}, likes=${partialPost?.likes}, userId=${partialPost?.user?.id} - ${partialPost?.createdAt} - ${partialPost?.lastUpdatedAt}',
  );
  await ds.dispose();
}
