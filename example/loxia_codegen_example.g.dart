// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'loxia_codegen_example.dart';

// **************************************************************************
// LoxiaEntityGenerator
// **************************************************************************

final EntityDescriptor<User> $UserEntityDescriptor = EntityDescriptor<User>(
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
  relations: const [],
  fromRow: (row) => User(id: row['id'] as int, email: row['email'] as String),
  toRow: (e) => {'id': e.id, 'email': e.email},
  fieldsContext: const UserFieldsContext(),
);

class UserFieldsContext extends QueryFieldsContext<User> {
  const UserFieldsContext();
  QueryField<int> get id => const QueryField<int>('id');
  QueryField<String> get email => const QueryField<String>('email');
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
