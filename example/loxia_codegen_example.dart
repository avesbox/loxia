import 'package:loxia/loxia.dart';

part 'loxia_codegen_example.g.dart';

@EntityMeta(table: 'users')
class User extends Entity {
  @PrimaryKey(autoIncrement: true)
  final int id;

  @Column()
  final String email;

  @OneToMany(on: Post, mappedBy: 'user', cascade: [RelationCascade.persist])
  final List<Post> posts;

  User({required this.id, required this.email, this.posts = const []});

  static EntityDescriptor<User, UserPartial> get entity =>
      $UserEntityDescriptor;
}

@EntityMeta(table: 'posts')
class Post extends Entity {
  @PrimaryKey(autoIncrement: true)
  final int id;

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

Future<void> main() async {
  final ds = DataSource(
    SqliteDataSourceOptions(
      path: 'example.db',
      entities: [User.entity, Post.entity, Tag.entity],
    ),
  );
  await ds.init();
  final users = ds.getRepository<User>();
  await users.save(UserPartial(email: 'example@example.com'));
  await users.update(
    UserUpdateDto(email: 'new@example.com'),
    where: UserQuery((q) => q.id.equals(1)),
  );
  await ds.dispose();
}
