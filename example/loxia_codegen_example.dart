import 'package:loxia/loxia.dart';
import 'package:postgres/postgres.dart';

part 'loxia_codegen_example.g.dart';

enum Role { admin, user, guest }

@EntityMeta(table: 'users')
class User extends Entity {
  @PrimaryKey(autoIncrement: true)
  final int id;

  @Column()
  final String email;

  @OneToMany(on: Post, mappedBy: 'user', cascade: [RelationCascade.persist])
  final List<Post> posts;

  @Column(type: ColumnType.text)
  final Role role;

  User({
    required this.id,
    required this.email,
    this.posts = const [],
    this.role = Role.user,
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
}

Future<void> main() async {
  final ds = DataSource(
    InMemoryDataSourceOptions(entities: [User.entity, Post.entity, Tag.entity]),
  );
  await ds.init();
  final users = ds.getRepository<User>();
  await users.save(UserPartial(email: 'example@example.com', role: Role.guest));
  await users.update(
    UserUpdateDto(email: 'new@example.com'),
    where: UserQuery((q) => q.id.equals(1)),
  );
  final user = await users.findOneBy(
    where: UserQuery((q) => q.email.equals('new@example.com')),
  );
  print('User: id=${user?.id}, email=${user?.email} - ${user?.role}');
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
