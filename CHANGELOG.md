# Changelog

## 0.0.14

- Add seamless integration with JSON Codec for Entities, allowing for a more smooth experience when converting them to JSON format.

## 0.0.13

- Fix a bug on foreign key migration in SQLite where the migration planner would generate `ALTER TABLE ... ADD CONSTRAINT ...` statements for adding foreign key constraints, which is not supported by SQLite and would cause the migration to fail. This fix updates the migration planner to check if the engine supports adding foreign key constraints via `ALTER TABLE` and, if not, it will instead generate the necessary SQL statements to create a new table with the correct foreign key constraints and copy the data from the old table to the new one, allowing for successful schema synchronization even in SQLite databases.

## 0.0.12

- Fix a bug on bidirectional relationships where foreign key columns were generated before the table they referenced, causing a failure during schema synchronization. This fix ensures that the migration planner correctly orders the creation of tables and their foreign key constraints, allowing for successful schema synchronization even in cases of circular references between entities.
- Fix a bug on DateTime fields in Partial Entities where the generated code didn't account for the fact that all fields in a Partial Entity are nullable, causing a runtime error when trying to serialize a DateTime field that was null. This fix updates the generated code to properly handle nullable DateTime fields in Partial Entities by using the null-aware operator when calling `toIso8601String()`, ensuring that it won't throw an error when the field is null and will instead return null in that case.

## 0.0.11

- Fix a bug in PostgresEngine that won't connect after hot reload, causing the application to lose database connectivity after a hot reload. This fix ensures that the PostgresEngine properly re-establishes the connection to the database after a hot reload, allowing your application to continue functioning without interruption.

## 0.0.10

- Added support for custom Queries. Allowing user to define custom sql queries in their repositories.
- Added support for Unique Constraints. Allowing user to define multiple unique constraints on their entities.

## 0.0.9

- Remove debug print statements from the codebase to clean up the output.

## 0.0.8

- Make json serialization and deserialization of fields in entities more robust.

## 0.0.7

- Fix generation for fromRow method to handle DateTime fields correctly.

## 0.0.6

- Fix JSON serialization of fields in entities, mainly List and Map fields
- Fix Enum encoding and decoding from database, ensuring that enum values are correctly stored and retrieved as their string representation in the database. This change improves the handling of enum fields in your entities, allowing for more intuitive and consistent storage of enum values without needing to manually convert them to and from their string representation.
- Fix DataTime encoding and decoding from database, ensuring that DateTime fields are correctly stored and retrieved in ISO 8601 format. This change enhances the handling of DateTime fields in your entities, allowing for accurate storage and retrieval of date and time information without needing to manually convert them to and from their string representation.

## 0.0.5

- Fix nullable option also in column descriptors, ensuring that the generated code correctly reflects the nullability of columns as defined in the entity classes. This change ensures that the database schema and the generated code are consistent with the intended design of your entities, preventing potential issues with null values in your application.

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
