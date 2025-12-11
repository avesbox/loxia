# Loxia ORM

Loxia is an experiment to build a pragmatic, annotation-driven ORM for Dart that borrows ideas from TypeORM and other data mappers. The goal is to let developers describe entities once and then plug them into different SQL engines at runtime without code generation.

## Guiding Principles

- **Entity-centric metadata** – annotations are only applied to entity classes and relation fields. The generated descriptors remain on the entity so instances can be registered with a database at runtime.
- **Multi-engine abstractions** – a `DataSource` receives entity descriptors and delegates to pluggable engine adapters (SQLite, Postgres, MySQL, …). Engines share the same repository API while handling dialect specifics internally.
- **Automatic migrations** – when the datasource boots, it compares the registered entity descriptors with the current database schema and emits create/alter statements as needed. Migrations can run automatically in dev and be previewed/applied in prod.
- **Repository-first API** – higher-level repositories expose `insert`, `find`, `update`, `delete`, `upsert`, and query builders. Underneath, repositories rely on the active engine adapter and entity metadata, so they work consistently across engines.

## High-level Architecture

```text
  ┌────────────┐     ┌────────────────┐     ┌────────────────────┐
  │ Entities   │ --> │ Metadata Graph │ --> │ DataSource/Engines │
  └────────────┘     └────────────────┘     └─────────┬──────────┘
                                                        │
                                                ┌───────▼────────┐
                                                │ Repositories   │
                                                └────────────────┘
```

1. Entities define their shape via annotations like `@EntityMeta`, `@Column`, and relation decorators.
2. Each entity exposes a static `EntityDescriptor` describing columns, indexes, and foreign keys.
3. A `DataSource` is initialized with entities + `DataSourceOptions` (engine, connection info). It selects the proper engine adapter, runs migrations, and retains an entity registry.
4. Repositories (one per entity) abstract CRUD operations and querying while using descriptors to translate calls into SQL for the active engine.

## Planned Modules

| Module | Focus |
| ------ | ----- |
| `annotations/` | Declarative annotations for columns, relations, primary keys, indexes |
| `metadata/` | Runtime descriptors describing tables, columns, constraints |
| `datasource/` | DataSource controller, options, engine adapters, connection pooling |
| `migrations/` | Schema diffing + migration planning/execution |
| `repository/` | Generic `EntityRepository<T>`, query builders, transaction helpers |
| `query/` | `FindOptions`, filters, ordering, pagination, eager loading flags |

## Usage Preview

```dart
// Define entities
@EntityMeta(table: 'users')
class User extends Entity {
  static EntityDescriptor<User> get entity => UserEntityDescriptor();

  @PrimaryKey(autoIncrement: true)
  int? id;

  @Column()
  String email;

  @OneToMany(on: Post)
  List<Post> posts;
}

// Bootstrap datasource
final dataSource = DataSource(
  DataSourceOptions(
    engine: SqliteEngine.inMemory(),
    entities: [User.entity, Post.entity],
    runMigrations: true,
  ),
);
await dataSource.init();

// Use repositories
final repo = dataSource.getRepository<User>();
await repo.insert(User.entity.to(user));
final users = await repo.find(
  where: UserQuery((q) => q.email.equals('foo@bar.com')),
);
```

## Code Generation (Builders)

Loxia ships a `source_gen` builder that reads your entity annotations and generates an `EntityDescriptor<T>` for runtime registration.

1. Add dev dependencies to your app:

```yaml
dev_dependencies:
  build_runner: ^2.4.11
  loxia: any # already as dependency; also provides the builder
```

1. Annotate your entities and add a `part` directive:

```dart
import 'package:loxia/loxia.dart';

part 'user.g.dart';

@EntityMeta(table: 'users')
class User extends Entity {
  @PrimaryKey(autoIncrement: true)
  int? id;

  @Column()
  String email;

  // Wire the generated descriptor
  static EntityDescriptor<User> get entity => $UserEntityDescriptor;
}
```

1. Run the builder:

```pwsh
dart run build_runner build --delete-conflicting-outputs
```

This generates `user.loxia.g.dart` with `$UserEntityDescriptor` plus a strongly typed `UserQueryFieldsContext` and `UserQuery` builder you can feed directly to `EntityRepository.find`.

### Fluent WHERE builders

Generated files now expose two helpful pieces for composing SQL filters without stringly-typed code:

- `UserQuery((q) => ...)` – a typed helper that instantiates the query context and returns the `WhereExpression` built inside the closure.
- `UserQueryFieldsContext` – a lightweight object whose properties (e.g. `q.email`, `q.id`) expose all comparison helpers such as `equals`, column-to-column comparisons, `gt`, `inList`, `isNull`, etc.

Inside the closure you can combine predicates with the new `.and(...)` / `.or(...)` helpers (and wrap any fragment with `.not()` when needed) available on every `WhereExpression`:

```dart
final teenagers = await repo.find(
  where: UserQuery(
    (q) => q.age.gte(13).and(q.age.lte(19)).or(q.nickname.like('%teen%')),
  ),
);
```

These helpers work alongside the existing `UserWhereQuery` data class, so existing call sites keep working while new code can opt into the fluent DSL.

## Near-term Tasks

1. Flesh out annotation/metadata layer.
2. Ship SQLite/Postgres adapters behind a common engine API.
3. Add schema diffing + migration executor.
4. Implement repositories and query builders.
5. Provide example app + tests running across multiple engines.

## Contributing

Right now the project is in heavy flux. Feel free to open issues with design ideas or send PRs for experimental adapters/migration strategies.

