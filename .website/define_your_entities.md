# Define your Entities

In Loxia, entities are defined as Dart classes that represent the structure of your database tables. Each entity class should extend the `Entity` class provided by Loxia and use annotations to define the mapping between the class properties and the database columns.

Here's an example of how to define a simple `User` entity:

```dart
import 'package:loxia/loxia.dart';
part 'user.g.dart';

@EntityMeta(table: 'users')
class User extends Entity {
  @PrimaryKey(autoIncrement: true)
  final int id;

  @Column()
  final String email;

  @OneToMany(on: Post, mappedBy: 'user', cascade: [RelationCascade.persist])
  final List<Post> posts;

  User({required this.id, required this.email, this.posts = const []});

  static EntityDescriptor<User, UserPartial> get entity => $UserEntityDescriptor;
}
```

In this example, we define a `User` entity with three properties: `id`, `email`, and `posts`. The `@EntityMeta` annotation specifies the database table name, while the `@PrimaryKey` and `@Column` annotations define the primary key and regular columns, respectively. The `@OneToMany` annotation establishes a one-to-many relationship with the `Post` entity.

Loxia uses code generation to create the necessary boilerplate code for your entities. To generate the code, run the following command:

```bash
dart run build_runner build
```

This will generate the `user.g.dart` file containing the entity descriptor and other necessary code for the `User` entity.

You can define additional entities in a similar manner, using the appropriate annotations to specify relationships and constraints as needed.

Once you have defined your entities, you can use them in your repositories to perform database operations.

## Column

The `@Column` annotation is used to define a regular column in your entity. You can specify various options such as the column name, whether it is nullable, default values, and more.
The values you pass to the `@Column` annotation are optional and they change the behavior of the Dto field mapping. Here are some of the most commonly used options:

- `name`: Specifies the name of the column in the database. If not provided, the property name will be used.
- `nullable`: Indicates whether the column can be null. Defaults to `false`.
- `defaultValue`: Specifies a default value for the column if none is provided.
- `unique`: Indicates whether the column should have a unique constraint. Defaults to `false`.
- `type`: Specifies the data type of the column. If not provided, Loxia will infer the type based on the Dart property type.

### Enum Columns

Loxia also supports mapping Dart enums to database columns. To define an enum column, you can use the `@Column` annotation with the `type` option set to `ColumnType.text` or `ColumnType.integer`, depending on how you want to store the enum values. For example:

```dart
enum UserRole { admin, user, guest }

class User extends Entity {
  @PrimaryKey(autoIncrement: true)
  final int id;

  @Column()
  final String email;

  @Column(type: ColumnType.text)
  final UserRole role;

  User({required this.id, required this.email, required this.role});
}
```

In this example, the `role` property is an enum of type `UserRole`. By specifying `type: ColumnType.text`, Loxia will store the enum values as their string representations in the database. Alternatively, you could use `ColumnType.integer` to store the enum values as their index.

## Primary Key

The `@PrimaryKey` annotation is used to define the primary key of your entity. You can specify options such as whether the primary key is auto-incremented.

- `autoIncrement`: Indicates whether the primary key should be auto-incremented. Defaults to `false`.
- `uuid`: Indicates whether the primary key should be a UUID. Defaults to `false`. If set to `true`, the primary key will be generated as a UUID string.

::: warning
Autoincrement can only be used with integer primary keys, while uuid can only be used with string primary keys. Make sure to choose the appropriate option based on your primary key type.
:::

## Relationships

Loxia supports various types of relationships between entities, including one-to-one, one-to-many, many-to-one, and many-to-many. You can use the appropriate annotations to define these relationships in your entity classes.

- `@OneToOne`: Defines a one-to-one relationship between two entities.
- `@OneToMany`: Defines a one-to-many relationship between two entities.
- `@ManyToOne`: Defines a many-to-one relationship between two entities.
- `@ManyToMany`: Defines a many-to-many relationship between two entities.

Each relationship annotation allows you to specify options such as the target entity, the mappedBy property, and cascade behaviors.
For more details on defining relationships, refer to the [Relationships](relationships.md) section of the documentation.

## Timestamps

Loxia provides a convenient way to manage timestamps for your entities. You can use the `@CreatedAt` and `@UpdatedAt` annotations to automatically handle the creation and update timestamps for your entities.

- `@CreatedAt`: Automatically sets the timestamp when a new entity is created.
- `@UpdatedAt`: Automatically updates the timestamp whenever an existing entity is modified.
- `@DeletedAt`: Automatically sets the timestamp when an entity is soft-deleted.

::: info
When you use the `@DeletedAt` annotation, Loxia will treat the entity as soft-deleted when the `deletedAt` field is set. This allows you to mark entities as deleted without actually removing them from the database, enabling features like data recovery and audit trails. Also all the repository methods that retrieve entities will have an `includeDeleted` option that allows you to include or exclude soft-deleted entities from the results.
:::

## Custom Queries

Loxia allows you to define custom SQL queries in your repositories for more complex operations that may not be covered by the standard CRUD methods. To achieve this you can add a `Query` instance to the `queries` list in your `@EntityMeta` annotation, providing a name and the SQL query string. For example:

```dart
@EntityMeta(
  table: 'users',
  queries: [
    Query(name: 'findByEmail', query: 'SELECT * FROM users WHERE email = @email')
  ]
)
class User extends Entity {
  // ...
}
```

In this example, we define a custom query named `findByEmail` that retrieves a user by their email address. You can then call this query from your repository like this:

```dart
final user = await userRepository.findByEmail('new@example.com');
```

In the example the `findByEmail` query will return a list of full `User` entities matching the provided email address. You can define as many custom queries as needed, allowing you to perform complex database operations while still benefiting from the convenience of Loxia's entity management.

| Parameter | Description |
|-----------|-------------|
| `name`    | The name of the custom query, which will be used to call the query from your repository. |
| `query`   | The SQL query string that defines the custom query. You can use parameter placeholders (e.g., `@email`) to pass parameters when calling the query. |
| `lifecycleHooks` | A list of lifecycle hooks that will be executed before or after the query is executed. This allows you to perform additional operations such as logging, validation, or modifying the query results. |

## Unique Constraints

Loxia allows you to define multiple unique constraints on your entities using the UniqueConstraint class. This is useful for ensuring data integrity and enforcing uniqueness across multiple columns in your database. To define unique constraints, you can add a list of UniqueConstraint instances to the `uniqueConstraints` parameter in your `@EntityMeta` annotation. For example:

```dart
@EntityMeta(
  table: 'user_movies',
  uniqueConstraints: [
    UniqueConstraint(columns: ['user_id', 'movie_id']),
  ]
)
class UserMovie extends Entity {
  @PrimaryKey(autoIncrement: true)
  final int id;

  @Column()
  final int userId;

  @Column()
  final int movieId;

  UserMovie({required this.id, required this.userId, required this.movieId});
}
```

In this example, we define a unique constraint on the combination of `user_id` and `movie_id` columns in the `user_movies` table. This ensures that each user can only have one entry for each movie, preventing duplicate records in the database. You can define multiple unique constraints on the same entity if needed, allowing you to enforce complex uniqueness rules across your database tables.

## Omit Null JSON Fields

Loxia provides an option to omit null fields when serializing entities and partial entities to JSON. This can help produce cleaner and more concise JSON output by excluding fields that have null values. This feauture is enabled by default, but you can disable it by setting the `omitNullJsonFields` option to `false` in your `@EntityMeta` annotation. For example:

```dart
@EntityMeta(
  table: 'users',
  omitNullJsonFields: true, // Set to false to include null fields in JSON output
)
class User extends Entity {
  // ...
}
```

When `omitNullJsonFields` is set to `true`, any fields in your entities or partial entities that have null values will be excluded from the generated JSON output when calling the `toJson()` method. This can help reduce the size of the JSON payload and make it easier to work with in client applications. If you prefer to include null fields in the JSON output, simply set `omitNullJsonFields` to `false`.