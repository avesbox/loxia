# Migrations

Loxia provides automatic schema migrations to keep your database synchronized with your entity definitions. Migrations are generated at build time and applied when your application starts.

## Overview

The migration system works in two modes:

1. **Automatic migrations** — Loxia compares your entity definitions with the current database schema and generates SQL to sync them
2. **Versioned migrations** — For more control, you can write explicit migration classes that are tracked and applied in order

## How It Works

When you run `dart run build_runner build`, Loxia:

1. Scans your codebase for entity classes
2. Creates a schema snapshot in `.loxia/schema_v1.json`
3. Compares against the previous snapshot
4. Generates migration files if changes are detected

When your application calls `dataSource.init()`:

1. Applies any pending versioned migrations
2. Compares entity definitions with the current database schema
3. Automatically applies any remaining differences

## Automatic Schema Sync

For simple use cases, Loxia can automatically synchronize your database schema without explicit migrations. Just define your entities and call `init()`:

```dart
final dataSource = DataSource(
  AppDataSourceOptions(
    engine: PostgresAdapter(connectionString),
    entities: [
      $UserDescriptor,
      $PostDescriptor,
    ],
  ),
);

await dataSource.init();  // Schema is automatically synchronized
```

Loxia detects:
- New tables (from new entities)
- New columns (from new fields)
- Column type changes
- Removed columns
- Index and constraint changes

> **Note:** Automatic sync is best for development. For production, use versioned migrations for better control and auditability.

## Versioned Migrations

For production deployments, create explicit migration classes that extend `Migration`:

```dart
import 'package:loxia/loxia.dart';

class CreateUsersTable extends Migration {
  CreateUsersTable() : super(1);  // Version number

  @override
  Future<void> up(EngineAdapter engine) async {
    await engine.execute('''
      CREATE TABLE users (
        id SERIAL PRIMARY KEY,
        email VARCHAR(255) NOT NULL UNIQUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  @override
  Future<void> down(EngineAdapter engine) async {
    await engine.execute('DROP TABLE users');
  }
}
```

Register migrations in your data source options:

```dart
final dataSource = DataSource(
  AppDataSourceOptions(
    engine: PostgresAdapter(connectionString),
    entities: [$UserDescriptor, $PostDescriptor],
    migrations: [
      CreateUsersTable(),
      AddUserProfileFields(),
      CreatePostsTable(),
    ],
  ),
);
```

### Migration Versioning

Each migration has a unique version number. Loxia tracks applied migrations in the `_loxia_migrations` table:

```sql
CREATE TABLE _loxia_migrations (
  version INTEGER PRIMARY KEY,
  applied_at TIMESTAMP NOT NULL
);
```

Migrations are applied in order by version number. Once applied, a migration is never re-run.

### Writing Migrations

#### Creating Tables

```dart
class CreatePostsTable extends Migration {
  CreatePostsTable() : super(2);

  @override
  Future<void> up(EngineAdapter engine) async {
    await engine.execute('''
      CREATE TABLE posts (
        id SERIAL PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        content TEXT,
        author_id INTEGER REFERENCES users(id),
        published_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    
    await engine.execute('''
      CREATE INDEX idx_posts_author ON posts(author_id)
    ''');
  }

  @override
  Future<void> down(EngineAdapter engine) async {
    await engine.execute('DROP TABLE posts');
  }
}
```

#### Adding Columns

```dart
class AddUserBio extends Migration {
  AddUserBio() : super(3);

  @override
  Future<void> up(EngineAdapter engine) async {
    await engine.execute('''
      ALTER TABLE users ADD COLUMN bio TEXT
    ''');
  }

  @override
  Future<void> down(EngineAdapter engine) async {
    await engine.execute('''
      ALTER TABLE users DROP COLUMN bio
    ''');
  }
}
```

#### Modifying Columns

```dart
class ChangeEmailLength extends Migration {
  ChangeEmailLength() : super(4);

  @override
  Future<void> up(EngineAdapter engine) async {
    await engine.execute('''
      ALTER TABLE users ALTER COLUMN email TYPE VARCHAR(500)
    ''');
  }

  @override
  Future<void> down(EngineAdapter engine) async {
    await engine.execute('''
      ALTER TABLE users ALTER COLUMN email TYPE VARCHAR(255)
    ''');
  }
}
```

#### Data Migrations

```dart
class NormalizeEmails extends Migration {
  NormalizeEmails() : super(5);

  @override
  Future<void> up(EngineAdapter engine) async {
    await engine.execute('''
      UPDATE users SET email = LOWER(TRIM(email))
    ''');
  }

  @override
  Future<void> down(EngineAdapter engine) async {
    // Data migrations are typically not reversible
  }
}
```

## Build Configuration

Configure migration generation in your `build.yaml`:

```yaml
targets:
  $default:
    builders:
      loxia:
        options:
          emit_migrations: true          # Generate migration files
          migrations_dir: migrations     # Output directory under .loxia
```

| Option | Default | Description |
|--------|---------|-------------|
| `emit_migrations` | `true` | Whether to generate migration files on schema changes |
| `migrations_dir` | `migrations` | Directory for generated migration files |

## Generated Migration Files

When Loxia detects schema changes, it generates migration files in `.loxia/migrations/`:

```
.loxia/
├── schema_v1.json
└── migrations/
    ├── 20240115_120000_up.sql
    ├── 20240115_120000_down.sql
    ├── 20240120_093000_up.sql
    └── 20240120_093000_down.sql
```

Each migration has:
- An `_up.sql` file with SQL to apply the changes
- A `_down.sql` file with SQL to revert the changes
- A timestamp-based identifier

## Migration Safety

### Transaction Wrapping

All migrations run within a transaction. If any part of a migration fails, the entire migration is rolled back:

```dart
await _engine.transaction((txEngine) async {
  await migration.up(txEngine);
  await txEngine.execute(
    'INSERT INTO _loxia_migrations (version, applied_at) VALUES (?, CURRENT_TIMESTAMP)',
    [migration.version],
  );
});
```

### History Validation

On startup, Loxia validates that all migrations in the database history are present in your code:

```dart
final missingInCode = applied.where((v) => !migrationVersions.contains(v)).toList();
if (missingInCode.isNotEmpty) {
  throw StateError(
    'Migration history mismatch. Database contains versions not present in code: $missingInCode',
  );
}
```

This prevents issues when migrations are accidentally removed from the codebase.

## Best Practices

1. **Never modify applied migrations** — Once a migration has been applied in any environment, treat it as immutable

2. **Use sequential version numbers** — Keep versions simple and ordered (1, 2, 3...) for clarity

3. **Write reversible migrations** — Always implement `down()` so you can rollback if needed

4. **Test migrations** — Run migrations against a test database before deploying to production

5. **Keep migrations small** — One logical change per migration makes debugging easier

6. **Use versioned migrations in production** — Rely on automatic sync only during development

7. **Backup before migrating** — Always backup your database before running migrations in production

## Quick Reference

| Concept | Description |
|---------|-------------|
| `Migration` | Base class for versioned migrations |
| `version` | Unique integer identifying the migration |
| `up()` | Apply the migration |
| `down()` | Revert the migration |
| `_loxia_migrations` | Table tracking applied migrations |
| `dataSource.init()` | Applies pending migrations and syncs schema |
