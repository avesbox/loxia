# Changelog

## 0.0.2

- Fixed a bug in the generated code where `createdAt` and `updatedAt` fields won't assign the value returned by the database, causing them to always be set to null,
- Fixed a bug in the `postgres` driver that caused the primary key of a table to not be properly generated.
- Added the `synchronize` option to all the drivers, allowing to automatically synchronize the database schema with the entities on startup. This is enabled by default to prevent accidental data loss, but can be disabled for development or testing purposes.

## 0.0.1

- Initial release of Loxia, a lightweight ORM for Dart supporting SQLite and PostgreSQL databases.
