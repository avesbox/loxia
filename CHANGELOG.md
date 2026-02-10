# Changelog

## 0.0.4

- Added support for Enum fields in entities, allowing you to define enum properties that will be automatically converted to and from their string representation in the database. You can specify the column type for enum fields using the `type` option in the `@Column` annotation, choosing between `ColumnType.text` for string representation or `ColumnType.integer` for index-based representation.
- Set the `nullable` option to `false` by default for all columns to enforce non-nullable fields unless explicitly specified otherwise. This change encourages better data integrity and reduces the likelihood of null-related errors in your application. You can still set `nullable: true` for columns that should allow null values as needed.

## 0.0.3

- Added support for UUID primary keys in both SQLite and PostgreSQL drivers. You can now define a primary key as a UUID string by using the `@PrimaryKey(uuid: true)` annotation on your entity fields.
- Added support for `toJson` method in entities and partial entities, allowing you to easily convert your entities to JSON format for serialization or API responses.
- Improve Postgres schema synchronization.
- Added default select allowing for less verbose queries when you want to select all columns of an entity without needing to specify them explicitly.

## 0.0.2

- Fixed a bug in the generated code where `createdAt` and `updatedAt` fields won't assign the value returned by the database, causing them to always be set to null,
- Fixed a bug in the `postgres` driver that caused the primary key of a table to not be properly generated.
- Added the `synchronize` option to all the drivers, allowing to automatically synchronize the database schema with the entities on startup. This is enabled by default to prevent accidental data loss, but can be disabled for development or testing purposes.

## 0.0.1

- Initial release of Loxia, a lightweight ORM for Dart supporting SQLite and PostgreSQL databases.
