# Repositories

Loxia uses repositories to manage data access and manipulation for your entities. A repository is a class that provides methods to perform CRUD (Create, Read, Update, Delete) operations on a specific entity type. Repositories act as an abstraction layer between your application and the database, allowing you to interact with your data models without directly dealing with SQL queries.

You won't need to manually create repository classes for your entities. Loxia automatically generates repository classes based on your entity definitions. Each entity will have a corresponding repository class that you can use to perform database operations.

Here's an example of how to use a repository to perform CRUD operations on a `User` entity:

```dart
import 'package:loxia/loxia.dart';

void main() async {
  final ds = DataSource(
    InMemoryDataSourceOptions(
      entities: [
        User.entity,
      ]
    )
  );
  // Initialize the data source
  final userRepository = ds.getRepository<User>();
  await userRepository.insert(UserInsertDto(email: 'example@example.com'));
}
```

The `getRepository` method retrieves the repository for the specified entity type. You can then use the repository's methods to perform various operations such as inserting new records, querying existing records, updating records, and deleting records.

## Insert Operations

### insert

The `insert` method is used to add a new record to the database. It accepts an insert DTO (Data Transfer Object) that contains the data for the new record. The insert DTO is generated based on your entity definition and includes only the fields that are required for insertion.

```dart
await userRepository.insert(UserInsertDto(email: 'alice@acme.com'));
```

### insertEntity

The `insertEntity` method is similar to `insert`, but it accepts an instance of the entity class instead of an insert DTO. This allows you to create a new entity instance and pass it directly to the repository for insertion.

```dart
final user = User(email: 'alice@acme.com');
await users.insertEntity(user);
```

## Save Operations

### save

The `save` method is a convenient way to either insert a new record or update an existing record based on the presence of a primary key value. If the primary key value is not set, it will perform an insert operation. If the primary key value is set, it will perform an update operation.

```dart
await userRepository.save(UserPartial(email: 'example@example.com'));
```

## Update Operations

### update

The `update` method is used to modify existing records in the database. It accepts an update DTO that contains the fields to be updated and their new values. The update DTO is generated based on your entity definition and includes only the fields that are allowed to be updated.

```dart
await users.update(
  UserUpdateDto(email: 'new@example.com'), 
  where: UserQuery((q) => q.id.equals(1))
);
```

### updateEntity

The `updateEntity` method is similar to `update`, but it accepts an instance of the entity class with the updated values. You can specify the conditions for which records to update using a query builder.

```dart
final user = User(id: 1, email: 'new@example.com');
await users.updateEntity(
  user, 
);
```

## Delete Operations

### delete

The `delete` method is used to remove records from the database. You can specify the conditions for which records to delete using a query builder.

```dart
await users.delete(
  where: UserQuery((q) => q.id.equals(1))
);
```

### deleteEntity

The `deleteEntity` method is similar to `delete`, but it accepts an instance of the entity class that you want to delete. The record corresponding to the provided entity instance will be removed from the database.

```dart
await users.deleteEntity(user);
```

## Querying Records

### find

The `find` method is used to retrieve records from the database. You can specify various options such as filtering conditions, sorting, pagination, and more.

This method does not return the full entity instances, but rather a `PartialEntity` that contains only the fields that were selected in the query. This allows for more efficient querying and reduces the amount of data transferred from the database.

```dart
final users = await userRepository.find(
  where: UserQuery((q) => q.email.contains('example.com')),
  orderBy: UserOrderBy((q) => q.id.desc()),
  limit: 10,
);
```

### findBy

The `findBy` method is a convenient way to retrieve a list of entities based on specific conditions. It is similar to the `find` method, but it returns the full entity instances instead of partial entities. This method is useful when you want to retrieve complete records without having to specify the selected fields.


```dart
final user = await userRepository.findBy(
  where: UserQuery((q) => q.id.equals(1))
);
```

### findOne

The `findOne` method is used to retrieve a single record that matches the specified conditions. It returns the partial entity instance if a matching record is found, or `null` if no record matches the conditions.

```dart
final user = await userRepository.findOne(
  where: UserQuery((q) => q.email.equals('example@example.com'))
);
```

### findOneBy

The `findOneBy` method is similar to `findOne`, but it returns the full entity instance instead of a partial entity. It is useful when you want to retrieve a complete record based on specific conditions.

```dart
final user = await userRepository.findOneBy(
  where: UserQuery((q) => q.id.equals(1))
);
```

### count

The `count` method is used to count the number of records that match the specified conditions. It returns the total count as an integer.

```dart
final count = await userRepository.count(
  where: UserQuery((q) => q.email.contains('example.com'))
);
```

### paginate

The `paginate` method is used to retrieve a paginated list of records based on the specified conditions. It returns a `PaginatedResult` that contains the list of records for the current page, as well as metadata such as the total count and total pages.

```dart
final paginatedResult = await userRepository.paginate(
  where: UserQuery((q) => q.email.contains('example.com')),
  orderBy: UserOrderBy((q) => q.id.desc()),
  page: 1,
  pageSize: 10,
);
```

## Transactions

Loxia supports transactions, allowing you to execute multiple database operations as a single unit of work. You can use the `transaction` method on the repository to perform operations within a transaction.

```dart
await userRepository.transaction(() async {
  await userRepository.insert(UserInsertDto(email: 'example@example.com'));
  await userRepository.update(
    UserUpdateDto(email: 'new@example.com'), 
    where: UserQuery((q) => q.id.equals(1))
  );
});
```

This ensures that either all operations within the transaction succeed, or if any operation fails, all changes are rolled back to maintain data integrity.

