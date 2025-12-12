# PostgreSQL Integration

The Loxia ORM now includes full support for PostgreSQL databases through the `postgres` package.

## Setup

The `postgres` package is already included in the dependencies. Make sure to run:

```bash
dart pub get
```

## Usage

### Creating a PostgreSQL Engine

```dart
import 'package:loxia/loxia.dart';

final postgresEngine = PostgresEngine.create(
  host: 'localhost',
  port: 5432,
  database: 'your_database',
  username: 'postgres',
  password: 'your_password',
  useSSL: false, // Set to true for production environments
);
```

### Using with DataSource

```dart
final ds = DataSource(
  DataSourceOptions(
    engine: postgresEngine,
    entities: [User.entity, Post.entity],
    runMigrations: true,
  ),
);

await ds.init();

// Use repositories as usual
final users = ds.getRepository<User>();
// ... perform operations

await ds.dispose();
```

## Features

The PostgreSQL engine supports all the standard `EngineAdapter` features:

- **Connection Management**: Async connection pooling
- **Query Execution**: Parameterized queries with indexed parameters (`$1`, `$2`, etc.)
- **Batch Operations**: Execute multiple statements in sequence
- **Schema Introspection**: Reads schema from PostgreSQL's `information_schema`
- **Type Mapping**: Comprehensive mapping between Dart and PostgreSQL types

## Type Mappings

| PostgreSQL Type | Loxia ColumnType |
|----------------|------------------|
| INT, SERIAL, BIGSERIAL, SMALLSERIAL | integer |
| CHAR, VARCHAR, TEXT | text |
| BYTEA | binary |
| REAL, FLOAT, DOUBLE, NUMERIC, DECIMAL | doublePrecision |
| JSON, JSONB | json |
| BOOLEAN, BOOL | boolean |
| TIMESTAMP, DATE, TIME | dateTime |

## Example

See `example/postgres_example.dart` for a complete working example.

```dart
import 'package:loxia/loxia.dart';

Future<void> main() async {
  final postgresEngine = PostgresEngine.create(
    host: 'localhost',
    port: 5432,
    database: 'loxia_db',
    username: 'postgres',
    password: 'password',
  );

  final ds = DataSource(
    DataSourceOptions(
      engine: postgresEngine,
      entities: [User.entity],
      runMigrations: true,
    ),
  );

  await ds.init();

  final users = ds.getRepository<User>();
  
  // Insert
  await users.insert(UserInsertDto(
    email: 'user@example.com',
    name: 'John Doe',
  ));

  // Query
  final found = await users.find(
    where: queryWhere<User>(
      (q) => q.field<String>('email').equals('user@example.com'),
    ),
  );

  for (final u in found) {
    print('Found: ${u.name} (${u.email})');
  }

  await ds.dispose();
}
```

## Connection Parameters

### Required Parameters

- `host`: The PostgreSQL server hostname (e.g., `'localhost'`)
- `port`: The PostgreSQL server port (typically `5432`)
- `database`: The name of the database to connect to
- `username`: The database user
- `password`: The database password

### Optional Parameters

- `useSSL`: Whether to use SSL/TLS for the connection (default: `false`)
  - In production, set this to `true` for secure connections

## Schema Introspection

The PostgreSQL engine reads schema information from PostgreSQL's `information_schema`, including:

- Table names from `information_schema.tables`
- Column definitions from `information_schema.columns`
- Primary key constraints from `information_schema.table_constraints`
- Data types and nullable constraints

This allows Loxia to:
- Generate migration plans based on entity definitions
- Validate existing schemas
- Automatically create or update tables as needed

## Differences from SQLite

While the API remains consistent across both SQLite and PostgreSQL engines, there are some differences:

1. **Connection**: PostgreSQL requires network connection parameters, SQLite uses file paths
2. **Type System**: PostgreSQL has a richer type system (e.g., JSONB, BYTEA)
3. **Schema Queries**: Different introspection methods (information_schema vs PRAGMA)
4. **Auto-increment**: PostgreSQL uses SERIAL types, SQLite uses AUTOINCREMENT
5. **Parameter Syntax**: PostgreSQL uses `$1, $2` indexed parameters

## Error Handling

The engine throws `StateError` if operations are attempted before calling `open()`:

```dart
final engine = PostgresEngine.create(/* ... */);

try {
  await engine.open();
  // ... use engine
} catch (e) {
  print('Connection failed: $e');
} finally {
  await engine.close();
}
```

## Best Practices

1. **Connection Pooling**: The `postgres` package handles connection pooling automatically
2. **SSL in Production**: Always use `useSSL: true` in production environments
3. **Resource Cleanup**: Always call `dispose()` on DataSource when done
4. **Error Handling**: Wrap database operations in try-catch blocks
5. **Migrations**: Enable `runMigrations: true` during development, handle migrations manually in production

## Troubleshooting

### Connection Issues

If you encounter connection issues:

1. Verify PostgreSQL is running: `pg_isready -h localhost -p 5432`
2. Check credentials and database existence
3. Ensure network connectivity and firewall rules
4. Verify PostgreSQL is configured to accept connections from your host

### Type Errors

If you encounter type mismatch errors:

1. Check that your entity column types match the PostgreSQL schema
2. Verify the type mappings in the table above
3. Consider using explicit type casting in your queries

### Migration Issues

If migrations fail:

1. Check that your database user has CREATE/ALTER permissions
2. Review the schema differences manually
3. Consider running migrations in a transaction
