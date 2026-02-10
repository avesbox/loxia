import '../annotations/column.dart';
import '../migrations/schema.dart';

class EntityWriter {
  final SchemaState schema;

  EntityWriter(this.schema);

  Map<String, String> generate() {
    final files = <String, String>{};

    for (final table in schema.tables.values) {
      if (table.name.startsWith('_loxia_') ||
          table.name.startsWith('sqlite_') ||
          table.name.startsWith('pg_')) {
        continue;
      }

      final className = _toPascalCase(table.name);
      final fileName = _toSnakeCase(className);
      files['$fileName.dart'] = _generateFileContent(
        table,
        className,
        fileName,
      );
    }

    return files;
  }

  String _generateFileContent(
    SchemaTable table,
    String className,
    String fileName,
  ) {
    final buffer = StringBuffer();

    buffer.writeln("import 'package:loxia/loxia.dart';");
    buffer.writeln();
    // Assuming all entities are in the same directory, we might need imports for relations
    // For now, if we use just PascalCase types, they need to be imported or part of same lib.
    // The prompt says "generate Dart entity classes", usually implies separate files.
    // If they are in the same folder, relative imports or just library structure matters.
    // I will add imports for related tables if they are different files.
    final imports = <String>{};
    for (final fk in table.foreignKeys) {
      final targetClass = _toPascalCase(fk.targetTable);
      if (targetClass != className) {
        final targetFile = _toSnakeCase(targetClass);
        imports.add("import '$targetFile.dart';");
      }
    }

    for (final import in imports) {
      buffer.writeln(import);
    }
    if (imports.isNotEmpty) buffer.writeln();

    buffer.writeln("part '$fileName.g.dart';");
    buffer.writeln();

    buffer.writeln("@EntityMeta(table: '${table.name}')");
    buffer.writeln('class $className extends Entity {');

    // Constructor fields
    final constructorParams = <String>[];

    // Columns
    for (final col in table.columns.values) {
      // Skip foreign keys source columns (managed by relations)?
      // Usually ORMS map both or just relation.
      // The prompt says: "Generate a field for the relation... Type: PascalCase of target... @JoinColumn...".
      // It implies replacing the raw column with the relation field.

      // Let's check if this column is a FK source.
      final fk = table.foreignKeys
          .where((f) => f.sourceColumn == col.name)
          .firstOrNull;

      if (fk != null) {
        // Generate relation instead
        final targetClass = _toPascalCase(fk.targetTable);
        // Or maybe strictly based on column name if multiple FKs to same table?
        // e.g. author_id -> author.
        // If column is 'user_id', field 'user'.
        String relFieldName = _relationFieldName(col.name);

        // If multiple relations to same table, name conflict?
        // Simple logic for now as requested.

        final nullable = col.nullable ? '?' : '';
        final requiredMod = col.nullable ? '' : 'required ';

        buffer.writeln();
        buffer.writeln("  @ManyToOne(on: $targetClass)");
        buffer.writeln("  @JoinColumn(name: '${col.name}')");
        buffer.writeln("  final $targetClass$nullable $relFieldName;");

        constructorParams.add('${requiredMod}this.$relFieldName');
      } else {
        // Normal column
        String type;
        if (col.isPrimaryKey) {
          buffer.writeln();
          buffer.writeln('  @PrimaryKey()');
          type = _dartType(col.type);
        } else {
          buffer.writeln();
          buffer.writeln("  @Column(name: '${col.name}')");
          type = _dartType(col.type);
        }

        final nullable = col.nullable ? '?' : '';
        final requiredMod = col.nullable ? '' : 'required ';
        final fieldName = _toCamelCase(col.name);

        buffer.writeln('  final $type$nullable $fieldName;');
        constructorParams.add('${requiredMod}this.$fieldName');
      }
    }

    buffer.writeln();
    buffer.writeln('  $className({');
    for (final param in constructorParams) {
      buffer.writeln('    $param,');
    }
    buffer.writeln('  });');

    buffer.writeln('}');

    return buffer.toString();
  }

  String _relationFieldName(String colName) {
    if (colName.toLowerCase().endsWith('_id')) {
      return _toCamelCase(colName.substring(0, colName.length - 3));
    }
    return _toCamelCase(colName);
  }

  String _dartType(ColumnType type) {
    switch (type) {
      case ColumnType.integer:
        return 'int';
      case ColumnType.doublePrecision:
        return 'double';
      case ColumnType.boolean:
        return 'bool';
      case ColumnType.text:
      case ColumnType.character:
      case ColumnType.varChar:
        return 'String';
      case ColumnType.dateTime:
      case ColumnType.timestamp:
        return 'DateTime';
      case ColumnType.binary:
      case ColumnType.blob:
        return 'List<int>'; // Assuming bytes
      case ColumnType.json:
        return 'Map<String, dynamic>'; // Or specific list?
      case ColumnType.uuid:
        return 'String';
    }
  }

  String _toPascalCase(String input) {
    return input
        .split('_')
        .map(
          (e) => e.isEmpty
              ? ''
              : '${e[0].toUpperCase()}${e.substring(1).toLowerCase()}',
        )
        .join();
  }

  String _toCamelCase(String input) {
    final pas = _toPascalCase(input);
    if (pas.isEmpty) return '';
    return '${pas[0].toLowerCase()}${pas.substring(1)}';
  }

  String _toSnakeCase(String input) {
    // Crude snake_case for file names from PascalCase
    return input
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => '_${match.group(0)!.toLowerCase()}',
        )
        .replaceAll(RegExp(r'^_'), '');
  }
}
