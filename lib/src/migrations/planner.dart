import '../metadata/entity_descriptor.dart';
import '../metadata/column_descriptor.dart';
import '../annotations/column.dart';
import 'schema.dart';

/// Simple diff that generates forward-only DDL actions to sync schema.
class MigrationPlan {
  final List<String> statements;
  const MigrationPlan(this.statements);
  bool get isEmpty => statements.isEmpty;
}

class MigrationPlanner {
  MigrationPlan diff({
    required List<EntityDescriptor> entities,
    required SchemaState current,
  }) {
    final stmts = <String>[];
    for (final entity in entities) {
      final table = current.tables[entity.tableName];
      if (table == null) {
        // Create table
        final cols = <String>[];
        for (final c in entity.columns) {
          cols.add(_columnDDL(c));
        }
        final create = 'CREATE TABLE IF NOT EXISTS ${entity.tableName} (\n  ${cols.join(',\n  ')}\n)';
        stmts.add(create);
        continue;
      }
      // Existing table: add missing columns
      for (final c in entity.columns) {
        if (!table.columns.containsKey(c.name)) {
          stmts.add('ALTER TABLE ${entity.tableName} ADD COLUMN ${_columnDDL(c)}');
        }
      }
    }
    return MigrationPlan(stmts);
  }

  String _columnDDL(ColumnDescriptor c) {
    final type = _typeToSql(c.type);
    final parts = <String>['"${c.name}" $type'];
    if (!c.nullable) parts.add('NOT NULL');
    if (c.isPrimaryKey) parts.add('PRIMARY KEY');
    if (c.autoIncrement) parts.add('AUTOINCREMENT'); // SQLite specific; engine will adapt
    if (c.unique) parts.add('UNIQUE');
    if (c.defaultValue != null) parts.add('DEFAULT ${_defaultLiteral(c.defaultValue)}');
    return parts.join(' ');
  }

  String _typeToSql(ColumnType t) {
    switch (t) {
      case ColumnType.integer:
        return 'INTEGER';
      case ColumnType.text:
        return 'TEXT';
      case ColumnType.boolean:
        return 'BOOLEAN';
      case ColumnType.doublePrecision:
        return 'DOUBLE';
      case ColumnType.dateTime:
        return 'TIMESTAMP';
      case ColumnType.json:
        return 'JSON';
      case ColumnType.binary:
        return 'BLOB';
    }
  }

  String _defaultLiteral(dynamic v) {
    if (v is num) return v.toString();
    if (v is bool) return v ? 'TRUE' : 'FALSE';
    return "'${v.toString().replaceAll("'", "''")}'";
  }
}
