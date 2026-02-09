import '../annotations/column.dart';

/// Snapshot of the database schema as reported by an engine.
class SchemaState {
  SchemaState({Map<String, SchemaTable>? tables})
    : tables = Map.unmodifiable(tables ?? <String, SchemaTable>{});

  final Map<String, SchemaTable> tables;

  static SchemaState empty() => SchemaState();

  SchemaState withTable(SchemaTable table) {
    final clone = Map<String, SchemaTable>.from(tables);
    clone[table.name] = table;
    return SchemaState(tables: clone);
  }
}

/// Describes a table in the schema.
class SchemaTable {
  SchemaTable({
    required this.name,
    Map<String, SchemaColumn>? columns,
    List<SchemaForeignKey>? foreignKeys,
  }) : columns = Map.unmodifiable(columns ?? <String, SchemaColumn>{}),
       foreignKeys = List.unmodifiable(foreignKeys ?? <SchemaForeignKey>[]);

  final String name;
  final Map<String, SchemaColumn> columns;
  final List<SchemaForeignKey> foreignKeys;

  SchemaTable withColumn(SchemaColumn column) {
    final clone = Map<String, SchemaColumn>.from(columns);
    clone[column.name] = column;
    return SchemaTable(name: name, columns: clone, foreignKeys: foreignKeys);
  }

  SchemaTable withForeignKey(SchemaForeignKey fk) {
    return SchemaTable(
      name: name,
      columns: columns,
      foreignKeys: [...foreignKeys, fk],
    );
  }
}

/// Describes a foreign key constraint.
class SchemaForeignKey {
  SchemaForeignKey({
    required this.sourceColumn,
    required this.targetTable,
    required this.targetColumn,
    this.onDeleteCascade = false,
  });

  final String sourceColumn;
  final String targetTable;
  final String targetColumn;
  final bool onDeleteCascade;
}

/// Describes a single column in a table.
class SchemaColumn {
  SchemaColumn({
    required this.name,
    required this.type,
    this.nullable = true,
    this.isPrimaryKey = false,
  });

  final String name;
  final ColumnType type;
  final bool nullable;
  final bool isPrimaryKey;
}
