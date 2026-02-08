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

## Primary Key

The `@PrimaryKey` annotation is used to define the primary key of your entity. You can specify options such as whether the primary key is auto-incremented.

- `autoIncrement`: Indicates whether the primary key should be auto-incremented. Defaults to `false`.

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
