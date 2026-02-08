import 'package:loxia/loxia.dart';

// Define a simple entity
class User extends Entity {
  User({this.id, required this.email});

  int? id;
  String email;

  static EntityDescriptor<User> get entity => EntityDescriptor<User>(
        entityType: User,
        tableName: 'users',
        columns: [
          ColumnDescriptor(
            name: 'id',
            propertyName: 'id',
            type: ColumnType.integer,
            nullable: true,
            isPrimaryKey: true,
            autoIncrement: true,
          ),
          ColumnDescriptor(
            name: 'email',
            propertyName: 'email',
            type: ColumnType.text,
            nullable: false,
            unique: true,
          ),
        ],
        relations: const [],
        fromRow: (row) => User(
          id: row['id'] as int?,
          email: row['email'] as String,
        ),
        toRow: (u) => {
          'id': u.id,
          'email': u.email,
        },
        fieldsContext: const UserFieldsContext(),
      );
}

class UserFieldsContext extends QueryFieldsContext<User> {
  const UserFieldsContext([super.runtime, super.alias]);

  QueryField<int?> get id => field('id');
  QueryField<String> get email => field('email');
  
  @override
  QueryFieldsContext<User> bind(QueryRuntimeContext runtime, String alias) {
    return UserFieldsContext(runtime, alias);
  }
}

class UserInsertDto extends InsertDto<User> {
  UserInsertDto({required this.email});

  final String email;

  @override
  Map<String, dynamic> toMap() {
    return {
      'email': email,
    };
  }
}

Future<void> main() async {
  final ds = DataSource(
    DataSourceOptions(
      engine: SqliteEngine.inMemory(),
      entities: [User.entity],
      runMigrations: true,
    ),
  );
  await ds.init();

  final users = ds.getRepository<User>();

  // Insert a user
  final newUser = User(email: 'john.doe@example.com');
  await users.insert(UserInsertDto(email: newUser.email));

  // Query it back
  final found = await users.find(
    where: queryWhere<User>((q) => q.field<String>('email').equals('john.doe@example.com')),
  );

  for (final u in found) {
    print('User: id=${u.id}, email=${u.email}');
  }

  await ds.dispose();
}
