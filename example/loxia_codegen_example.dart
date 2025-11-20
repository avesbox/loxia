import 'package:loxia/loxia.dart';

part 'loxia_codegen_example.g.dart';

@EntityMeta(table: 'users')
class User extends Entity {
  @PrimaryKey(autoIncrement: true)
  final int id;

  @Column()
  final String email;

  User({required this.id, required this.email});

  static EntityDescriptor<User> get entity => $UserEntityDescriptor;
}

Future<void> main() async {
  final ds = DataSource(
    DataSourceOptions(
      engine: SqliteEngine.inMemory(),
      entities: [User.entity],
    ),
  );
  await ds.init();

  final users = ds.getRepository<User>();
  await users.insert(UserInsertDto(email: 'text@example.com'));
  final rows = await users.find(
    where: UserQuery(
      (q) => q.email.equals('text@example.com'),
    ),
  );
  for (final u in rows) {
    print('User -> id=${u.id} - email=${u.email}');
  }

  await ds.dispose();
}
