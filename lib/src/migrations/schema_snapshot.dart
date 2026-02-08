/// JSON-serializable schema snapshot model for migrations.
///
/// This file defines a simple, stable representation of the database schema
/// that can be saved to `.loxia/schema_v1.json` and compared on subsequent runs.
library;

class SchemaSnapshot {
  SchemaSnapshot({required this.version, Map<String, SnapshotTable>? tables})
    : tables = Map.unmodifiable(tables ?? <String, SnapshotTable>{});

  /// Schema snapshot version (e.g. "1.0").
  final String version;

  /// Tables keyed by logical table name.
  final Map<String, SnapshotTable> tables;

  static SchemaSnapshot empty({String version = '1.0'}) =>
      SchemaSnapshot(version: version);

  SchemaSnapshot withTable(SnapshotTable table) {
    final clone = Map<String, SnapshotTable>.from(tables);
    clone[table.name] = table;
    return SchemaSnapshot(version: version, tables: clone);
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'tables': {
      for (final entry in tables.entries) entry.key: entry.value.toJson(),
    },
  };

  factory SchemaSnapshot.fromJson(Map<String, dynamic> json) {
    final version = (json['version'] as String?) ?? '1.0';
    final rawTables = json['tables'];
    final tables = <String, SnapshotTable>{};
    if (rawTables is Map) {
      for (final entry in rawTables.entries) {
        final key = entry.key?.toString();
        final value = entry.value;
        if (key == null || value is! Map) continue;
        tables[key] = SnapshotTable.fromJson(key, Map<String, dynamic>.from(value));
      }
    }
    return SchemaSnapshot(version: version, tables: tables);
  }
}

class SnapshotTable {
  SnapshotTable({required this.name, Map<String, SnapshotColumn>? columns})
    : columns = Map.unmodifiable(columns ?? <String, SnapshotColumn>{});

  final String name;
  final Map<String, SnapshotColumn> columns;

  SnapshotTable withColumn(SnapshotColumn column) {
    final clone = Map<String, SnapshotColumn>.from(columns);
    clone[column.name] = column;
    return SnapshotTable(name: name, columns: clone);
  }

  Map<String, dynamic> toJson() => {
    'columns': {
      for (final entry in columns.entries) entry.key: entry.value.toJson(),
    },
  };

  factory SnapshotTable.fromJson(String name, Map<String, dynamic> json) {
    final rawColumns = json['columns'];
    final columns = <String, SnapshotColumn>{};
    if (rawColumns is Map) {
      for (final entry in rawColumns.entries) {
        final key = entry.key?.toString();
        final value = entry.value;
        if (key == null || value is! Map) continue;
        columns[key] = SnapshotColumn.fromJson(key, Map<String, dynamic>.from(value));
      }
    }
    return SnapshotTable(name: name, columns: columns);
  }
}

class SnapshotColumn {
  SnapshotColumn({
    required this.name,
    required this.type,
    this.nullable = true,
    this.isPrimaryKey = false,
    this.unique = false,
    this.defaultValue,
  });

  /// Column name.
  final String name;

  /// Column type as a stable string (e.g. "int", "varchar", "text", "boolean").
  final String type;

  /// Whether the column is nullable.
  final bool nullable;

  /// Whether the column is part of the primary key.
  final bool isPrimaryKey;

  /// Whether the column is unique.
  final bool unique;

  /// Default value literal, if any.
  final String? defaultValue;

  Map<String, dynamic> toJson() => {
    'type': type,
    'nullable': nullable,
    'isPrimaryKey': isPrimaryKey,
    'unique': unique,
    if (defaultValue != null) 'defaultValue': defaultValue,
  };

  factory SnapshotColumn.fromJson(String name, Map<String, dynamic> json) {
    final type = (json['type'] as String?) ?? 'text';
    final nullable = (json['nullable'] as bool?) ?? true;
    final isPrimaryKey = (json['isPrimaryKey'] as bool?) ?? false;
    final unique = (json['unique'] as bool?) ?? false;
    final defaultValue = json['defaultValue']?.toString();
    return SnapshotColumn(
      name: name,
      type: type,
      nullable: nullable,
      isPrimaryKey: isPrimaryKey,
      unique: unique,
      defaultValue: defaultValue,
    );
  }
}
