# Getting Started

To get started with Loxia, add it to your `pubspec.yaml` file:

```yaml
dependencies:
  loxia: ^0.0.1
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
  loxia: ^0.0.1
  sqlite3: ^3.1.4
```

For PostgreSQL, add the following dependency to your `pubspec.yaml` file:

```yaml
dependencies:
  loxia: ^0.0.1
  postgres: ^3.5.9
```

## Create your Database Connection

To create a database connection, you need to instantiate the appropriate database driver and pass it to the `Loxia` instance. We will use SQLite in this example:

```dart
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

As you can see, we create a `DataSource` instance by passing an instance of `SqliteDataSourceOptions` with the path to the database file and an empty list of entities for now.

You can now use the `ds` instance to interact with the database using Loxia's features.

::: warning
Make sure to call `await ds.init();` before performing any database operations to ensure the connection is properly established.
:::

## Next Steps

Now that you have set up Loxia and created a database connection, you can start defining your entities, repositories, and using Loxia's features to interact with your database.
