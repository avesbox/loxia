import 'package:loxia/loxia.dart';
import 'package:postgres/postgres.dart';

// Define a simple entity
class User extends Entity {
  User({this.id, required this.email, required this.name});

  int? id;
  String email;
  String name;

  static EntityDescriptor<User, UserPartial> get entity =>
      EntityDescriptor<User, UserPartial>(
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
          ColumnDescriptor(
            name: 'name',
            propertyName: 'name',
            type: ColumnType.text,
            nullable: false,
          ),
        ],
        relations: const [],
        fromRow: (row) => User(
          id: row['id'] as int?,
          email: row['email'] as String,
          name: row['name'] as String,
        ),
        toRow: (u) => {'id': u.id, 'email': u.email, 'name': u.name},
        fieldsContext: const UserFieldsContext(), 
        repositoryFactory: (EngineAdapter engine) => EntityRepository<User, UserPartial>(
          User.entity,
          engine,
          User.entity.fieldsContext
        )
      );
}

class UserPartial extends PartialEntity<User> {
  const UserPartial({this.id, this.email, this.name});

  final int? id;
  final String? email;
  final String? name;

  @override
  Object? get primaryKeyValue => id;

  @override
  User toEntity() {
    final missing = <String>[];
    if (id == null) missing.add('id');
    if (email == null) missing.add('email');
    if (name == null) missing.add('name');
    if (missing.isNotEmpty) {
      throw StateError(
        'Cannot convert UserPartial to User: missing required fields: ${missing.join(', ')}',
      );
    }
    return User(
      id: id!,
      email: email!,
      name: name!,
    );
  }

  @override
  InsertDto<User> toInsertDto() {
    final missing = <String>[];
    if (email == null) missing.add('email');
    if (name == null) missing.add('name');
    if (missing.isNotEmpty) {
      throw StateError(
        'Cannot convert UserPartial to UserInsertDto: missing required fields: ${missing.join(', ')}',
      );
    }
    return UserInsertDto(email: email!, name: name!);
  }

  @override
  UpdateDto<User> toUpdateDto() {
    return UserUpdateDto(email: email, name: name);
  }
}

class UserFieldsContext extends QueryFieldsContext<User> {
  const UserFieldsContext([super.runtime, super.alias]);

  QueryField<int?> get id => field('id');
  QueryField<String> get email => field('email');
  QueryField<String> get name => field('name');

  @override
  QueryFieldsContext<User> bind(QueryRuntimeContext runtime, String alias) {
    return UserFieldsContext(runtime, alias);
  }
}

class UserInsertDto extends InsertDto<User> {
  UserInsertDto({required this.email, required this.name});

  final String email;
  final String name;

  @override
  Map<String, dynamic> toMap() {
    return {'email': email, 'name': name};
  }
}

class UserUpdateDto extends UpdateDto<User> {
  UserUpdateDto({this.email, this.name});

  final String? email;
  final String? name;

  @override
  Map<String, dynamic> toMap() {
    return {
      if (email != null) 'email': email,
      if (name != null) 'name': name,
    };
  }
}

Future<void> main() async {
  // Create PostgreSQL engine with connection parameters
  final postgresEngine = PostgresEngine.connect(
    Endpoint(
      host: 'localhost',
      port: 5432,
      database: 'loxia',
      username: 'loxia',
      password: 'loxia',
    ),
    settings: ConnectionSettings(
      timeZone: 'UTC',
    ),
  );

  final ds = DataSource(
    DataSourceOptions(
      engine: postgresEngine,
      entities: [User.entity],
      migrations: []
    ),
  );

  await ds.init();

  final users = ds.getRepository<User, UserPartial>();

  // Insert a user
  await users.insert(
    UserInsertDto(email: 'john.doe@example.com', name: 'John Doe'),
  );

  // Query it back
  final found = await users.findBy(
    where: queryWhere<User>(
      (q) => q.field<String>('email').equals('john.doe@example.com'),
    ),
  );

  for (final u in found) {
    print('User: id=${u.id}, email=${u.email}, name=${u.name}');
  }

  await ds.dispose();
}
