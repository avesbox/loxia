# Getting Started

To get started with Loxia, add it to your `pubspec.yaml` file:

```yaml
dependencies:
  loxia: ^0.2.0
```

Then, run `dart pub get` to install the package.
Import Loxia in your Dart code:

```dart
import 'package:loxia/loxia.dart';
```

## Choose your Database Driver

Loxia supports SQLite and PostgreSQL databases. You need to choose and install the appropriate database driver for your project.

For SQLite, add the following dependency to your `pubspec.yaml` file:

```yaml
dependencies:
  loxia: ^0.2.0
  sqlite3: ^3.1.4
```

For PostgreSQL, add the following dependency to your `pubspec.yaml` file:

```yaml
dependencies:
  loxia: ^0.2.0
  postgres: ^3.5.9
```

For MySQL, add the following dependency to your `pubspec.yaml` file:

```yaml
dependencies:
  loxia: ^0.2.0
  mysql_client: ^0.0.27
```

## Create your Database Connection

To create a database connection, you need to instantiate the appropriate database driver and pass it to the `Loxia` instance. You can choose between SQLite, PostgreSQL and MySQL drivers based on your database choice:

::: code-group

```dart [SQLite]
import 'package:loxia/loxia.dart';

void main() async {
  final ds = DataSource(
    SqliteDataSourceOptions(
      path: 'example.db',
      entities: [],
    ),
  );
  await ds.init();
  // Your code here
}
```

```dart [In Memory]
import 'package:loxia/loxia.dart';

void main() async {
  final ds = DataSource(
    InMemoryDataSourceOptions(
      entities: [],
    ),
  );
  await ds.init();
  // Your code here
}
```

```dart [Postgres]
import 'package:loxia/loxia.dart';

void main() async {
  final ds = DataSource(
    PostgresDataSourceOptions.connect(
      host: 'localhost',
      port: 5432,
      database: 'postgres',
      username: 'postgres',
      password: 'test123',
      entities: [],
    ),
  );
  await ds.init();
  // Your code here
}
```

```dart [Postgres Connection URL]
import 'package:loxia/loxia.dart';

void main() async {
  final ds = DataSource(
    PostgresDataSourceOptions.fromUrl(
      url: 'postgresql://postgres:test123@localhost/postgres',
      entities: [],
    ),
  );
  await ds.init();
  // Your code here
}
```

```dart [MySQL]
import 'package:loxia/loxia.dart';

void main() async {
  final ds = DataSource(
    MySqlDataSourceOptions.connect(
      host: 'localhost',
      port: 3306,
      database: 'test',
      username: 'root',
      password: 'test123',
      entities: [],
    ),
  );
  await ds.init();
  // Your code here
}
```

:::

As you can see, we create a `DataSource` instance by passing an instance of `DataSourceOptions` with the appropriate configuration and an empty list of entities for now.

You can now use the `ds` instance to interact with the database using Loxia's features.

::: warning
Make sure to call `await ds.init();` before performing any database operations to ensure the connection is properly established.
:::

## Next Steps

Now that you have set up Loxia and created a database connection, you can start defining your entities, repositories, and using Loxia's features to interact with your database.
