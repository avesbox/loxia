import 'package:loxia/loxia.dart';

part 'loxia_codegen_example.g.dart';

@EntityMeta(table: 'users')
class User extends Entity {
  @PrimaryKey(autoIncrement: true)
  final int id;

  @Column()
  final String email;

  @OneToMany(on: Post, mappedBy: 'user')
  final List<Post> posts;

  User({required this.id, required this.email, this.posts = const []});

  static EntityDescriptor<User, UserPartial> get entity => $UserEntityDescriptor;
}

@EntityMeta(table: 'posts')
class Post extends Entity {
  @PrimaryKey(autoIncrement: true)
  final int id;

  @Column()
  final String title;

  @Column()
  final String content;

  @ManyToOne(on: User)
  final User? user;

  Post({required this.id, required this.title, required this.content, this.user});

  static EntityDescriptor<Post, PostPartial> get entity => $PostEntityDescriptor;
}

Future<void> main() async {
  final ds = DataSource(
    DataSourceOptions(
      engine: SqliteEngine.inMemory(),
      entities: [User.entity, Post.entity],
    ),
  );
  await ds.init();
  final users = ds.getRepository<User, UserPartial>();
  await users.insert(UserInsertDto(email: 'text@example.com'));
  final rows = await users.find(
    select: UserSelect(id: true, email: true),
    where: UserQuery(
      (q) => q.email.equals('text@example.com'),
    ),
  );
  final posts = ds.getRepository<Post, PostPartial>();
  await posts.insert(PostInsertDto(
    title: 'First Post',
    content: 'This is the content of the first post.',
    userId: rows.first.id!,
  ));
  for (final u in rows) {
    print('User -> id=${u.id} - email=${u.email}');
  }
  final postRows = await posts.find(
    select: PostSelect(
      title: true,
      content: true,
      id: true,
      userId: true,
      relations: PostRelations(
        user: UserSelect(id: true),
      ),
    ),
    where: PostQuery(
      (q) => q.user.id.equals(rows.first.id!),
    ),
  );
  for (final p in postRows) {
    print('Post -> id=${p.id} - title=${p.title} - userId=${p.userId} - user.id=${p.user?.id}');
  }
  final partialUsers = await users.find(
    select: UserSelect(
      id: true, 
      email: true, 
      relations: UserRelations(
        posts: PostSelect(
          id: true, 
          title: true,
          relations: PostRelations(
            user: UserSelect(
              id: true,
            )
          )
        ),
      )
    ),
  );
  for (final u in partialUsers) {
    print('Partial User -> id=${u.id} - email=${u.email} - ${u.posts?.first.user?.id}');
  }

  await ds.dispose();
}
