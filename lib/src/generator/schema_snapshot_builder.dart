import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:source_gen/source_gen.dart';

import '../annotations/column.dart';
import '../annotations/entity_meta.dart';
import '../migrations/schema_snapshot.dart';

/// Builder responsible for snapshotting schema and creating migration artifacts.
class SchemaSnapshotBuilder implements Builder {
  SchemaSnapshotBuilder({
    this.snapshotVersion = '1.0',
    this.snapshotDirName = '.loxia',
    this.snapshotFileName = 'schema_v1.json',
    this.migrationsDirName = 'migrations',
    this.emitMigrations = true,
    List<String>? includeGlobs,
    List<String>? excludeGlobs,
  }) : includeGlobs = includeGlobs ?? const ['lib/**.dart'],
       excludeGlobs =
           excludeGlobs ?? const ['**/*.g.dart', '**/*.loxia.g.part'];

  /// Snapshot version stored in schema JSON.
  final String snapshotVersion;

  /// Root directory where schema snapshot is stored.
  final String snapshotDirName;

  /// Snapshot file name.
  final String snapshotFileName;

  /// Subdirectory under `.loxia` where migrations are written.
  final String migrationsDirName;

  /// Whether to emit migration files.
  final bool emitMigrations;

  /// Globs of Dart sources to scan for entities.
  final List<String> includeGlobs;

  /// Globs to exclude from scanning.
  final List<String> excludeGlobs;

  @override
  Map<String, List<String>> get buildExtensions => const {
    'pubspec.yaml': ['.loxia/schema_v1.json'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    if (buildStep.inputId.path != 'pubspec.yaml') {
      return;
    }

    final snapshot = await _buildSnapshot(buildStep);
    final snapshotAsset = AssetId(
      buildStep.inputId.package,
      '$snapshotDirName/$snapshotFileName',
    );
    final previous = await _readSnapshot(buildStep, snapshotAsset);
    if (previous == null) {
      await _writeSnapshot(buildStep, snapshotAsset, snapshot);
      return;
    }
    if (_equals(previous, snapshot)) {
      return;
    }

    if (emitMigrations) {
      final diff = _diff(previous, snapshot);
      if (diff.up.isNotEmpty || diff.down.isNotEmpty) {
        final migrationId = _buildMigrationId();
        await _writeMigrations(buildStep, migrationId, diff.up, diff.down);
      }
    }

    await _writeSnapshot(buildStep, snapshotAsset, snapshot);
  }

  Future<SchemaSnapshot> _buildSnapshot(BuildStep buildStep) async {
    final typeChecker = TypeChecker.typeNamed(EntityMeta);
    final tables = <String, SnapshotTable>{};
    final visited = <Uri>{};

    final assets = <AssetId>[];
    for (final pattern in includeGlobs) {
      assets.addAll(await buildStep.findAssets(Glob(pattern)).toList());
    }

    for (final asset in assets) {
      if (!_shouldIncludeAsset(asset)) {
        continue;
      }

      final lib = await buildStep.resolver.libraryFor(
        asset,
        allowSyntaxErrors: true,
      );
      if (!visited.add(lib.uri)) {
        continue;
      }

      final reader = LibraryReader(lib);
      for (final clazz in reader.classes) {
        if (clazz.isAbstract) continue;
        if (!typeChecker.hasAnnotationOfExact(clazz)) continue;

        final annotation = typeChecker.firstAnnotationOfExact(clazz);
        if (annotation == null) continue;

        final reader = ConstantReader(annotation);
        final rawTable =
            reader.peek('table')?.stringValue ?? _toSnake(clazz.displayName);
        final schema = reader.peek('schema')?.stringValue;
        final tableName = (schema == null || schema.trim().isEmpty)
            ? rawTable
            : '$schema.$rawTable';

        final columns = _collectColumns(clazz);
        tables[tableName] = SnapshotTable(name: tableName, columns: columns);
      }
    }

    return SchemaSnapshot(version: snapshotVersion, tables: tables);
  }

  bool _shouldIncludeAsset(AssetId asset) {
    final path = asset.path;
    for (final pattern in excludeGlobs) {
      if (Glob(pattern).matches(path)) {
        return false;
      }
    }
    return true;
  }

  Map<String, SnapshotColumn> _collectColumns(ClassElement clazz) {
    final columns = <String, SnapshotColumn>{};
    final columnChecker = TypeChecker.typeNamed(Column);
    final primaryChecker = TypeChecker.typeNamed(PrimaryKey);

    for (final field in clazz.fields.where((f) => !f.isStatic)) {
      final columnAnn = columnChecker.firstAnnotationOfExact(field);
      final primaryAnn = primaryChecker.firstAnnotationOfExact(field);
      if (columnAnn == null && primaryAnn == null) continue;

      final columnReader = columnAnn == null ? null : ConstantReader(columnAnn);
      final columnName =
          columnReader?.peek('name')?.stringValue ??
          _toSnake(field.displayName);

      final isEnumType =
          field.type is InterfaceType &&
          (field.type as InterfaceType).element is EnumElement;

      final type = _resolveColumnType(
        columnReader,
        field.type,
        isEnum: isEnumType,
        field: field,
      );
      final nullable = _resolveNullable(columnReader, field.type);
      final unique = columnReader?.peek('unique')?.boolValue ?? false;
      final defaultValue = _dartObjToLiteral(
        columnReader?.peek('defaultValue')?.objectValue,
      );

      final snapshotColumn = SnapshotColumn(
        name: columnName,
        type: _columnTypeToString(type),
        nullable: nullable,
        isPrimaryKey: primaryAnn != null,
        unique: unique,
        defaultValue: defaultValue,
      );

      columns[columnName] = snapshotColumn;
    }

    return columns;
  }

  bool _resolveNullable(ConstantReader? reader, DartType type) {
    final fieldNullable = type.nullabilitySuffix != NullabilitySuffix.none;
    final annNullable = reader?.peek('nullable')?.boolValue ?? true;
    return fieldNullable && annNullable;
  }

  ColumnType _resolveColumnType(
    ConstantReader? reader,
    DartType type, {
    bool isEnum = false,
    FieldElement? field,
  }) {
    ColumnType? explicitType;
    if (reader != null) {
      final explicit = reader.peek('type');
      if (explicit != null && !explicit.isNull) {
        final index = explicit.objectValue.getField('index')?.toIntValue();
        if (index != null && index >= 0 && index < ColumnType.values.length) {
          explicitType = ColumnType.values[index];
        }
      }
    }

    if (explicitType != null) {
      if (!isEnum) return explicitType;
      if (explicitType == ColumnType.text ||
          explicitType == ColumnType.integer) {
        return explicitType;
      }
      final className =
          field?.enclosingElement.displayName ?? '<unknown class>';
      final fieldName = field?.displayName ?? '<unknown field>';
      throw InvalidGenerationSourceError(
        'Enum column $className.$fieldName must use ColumnType.text or ColumnType.integer.',
        element: field,
      );
    }

    if (isEnum) return ColumnType.integer;

    return _inferColumnType(type);
  }

  ColumnType _inferColumnType(DartType type) {
    var name = type.getDisplayString();
    if (type.nullabilitySuffix == NullabilitySuffix.question) {
      name = name.substring(0, name.length - 1);
    }
    if (type is InterfaceType && (type.isDartCoreList || type.isDartCoreMap)) {
      return ColumnType.json;
    }
    switch (name) {
      case 'int':
        return ColumnType.integer;
      case 'String':
        return ColumnType.text;
      case 'bool':
        return ColumnType.boolean;
      case 'double':
        return ColumnType.doublePrecision;
      case 'DateTime':
        return ColumnType.dateTime;
      default:
        return ColumnType.text;
    }
  }

  String _columnTypeToString(ColumnType type) {
    switch (type) {
      case ColumnType.integer:
        return 'int';
      case ColumnType.text:
      case ColumnType.character:
      case ColumnType.varChar:
        return 'varchar';
      case ColumnType.boolean:
        return 'boolean';
      case ColumnType.doublePrecision:
        return 'double';
      case ColumnType.dateTime:
      case ColumnType.timestamp:
        return 'timestamp';
      case ColumnType.json:
        return 'json';
      case ColumnType.binary:
      case ColumnType.blob:
        return 'blob';
      case ColumnType.uuid:
        return 'uuid';
    }
  }

  String? _dartObjToLiteral(DartObject? obj) {
    if (obj == null) return null;
    final i = obj.toIntValue();
    if (i != null) return i.toString();
    final d = obj.toDoubleValue();
    if (d != null) return d.toString();
    final b = obj.toBoolValue();
    if (b != null) return b ? 'true' : 'false';
    final s = obj.toStringValue();
    if (s != null) return "'${s.replaceAll("'", "''")}'";
    return null;
  }

  Future<SchemaSnapshot?> _readSnapshot(
    BuildStep step,
    AssetId snapshotId,
  ) async {
    if (!await step.canRead(snapshotId)) {
      final root = await _packageRoot(step);
      final file = File(p.join(root, snapshotId.path));
      if (!file.existsSync()) {
        return null;
      }
      final text = await file.readAsString();
      final json = jsonDecode(text);
      if (json is! Map<String, dynamic>) return null;
      return SchemaSnapshot.fromJson(json);
    }
    final text = await step.readAsString(snapshotId);
    final json = jsonDecode(text);
    if (json is! Map<String, dynamic>) return null;
    return SchemaSnapshot.fromJson(json);
  }

  Future<void> _writeSnapshot(
    BuildStep step,
    AssetId snapshotId,
    SchemaSnapshot snapshot,
  ) async {
    final jsonText = const JsonEncoder.withIndent(
      '  ',
    ).convert(snapshot.toJson());
    await step.writeAsString(snapshotId, jsonText);
  }

  bool _equals(SchemaSnapshot a, SchemaSnapshot b) {
    final aj = jsonEncode(a.toJson());
    final bj = jsonEncode(b.toJson());
    return aj == bj;
  }

  Future<void> _writeMigrations(
    BuildStep step,
    String migrationId,
    List<String> up,
    List<String> down,
  ) async {
    final root = await _packageRoot(step);
    print(root);
    final dir = Directory('$root/$snapshotDirName/$migrationsDirName');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final sqlPath = '${dir.path}/$migrationId.sql';
    final dartPath = '${dir.path}/$migrationId.dart';

    final sqlBuffer = StringBuffer()
      ..writeln('-- up')
      ..writeln(up.map((s) => s.trim()).join('\n'))
      ..writeln()
      ..writeln('-- down')
      ..writeln(down.map((s) => s.trim()).join('\n'))
      ..writeln();
    await File(sqlPath).writeAsString(sqlBuffer.toString());

    final className = _migrationClassName(migrationId);
    final dartBuffer = StringBuffer()
      ..writeln('/// Generated migration $migrationId')
      ..writeln('class $className {')
      ..writeln('  const $className();')
      ..writeln()
      ..writeln('  List<String> up() => const [');
    for (final stmt in up) {
      dartBuffer.writeln("    ${_dartString(stmt)},");
    }
    dartBuffer
      ..writeln('  ];')
      ..writeln()
      ..writeln('  List<String> down() => const [');
    for (final stmt in down) {
      dartBuffer.writeln("    ${_dartString(stmt)},");
    }
    dartBuffer
      ..writeln('  ];')
      ..writeln('}');
    await File(dartPath).writeAsString(dartBuffer.toString());
  }

  Future<String> _packageRoot(BuildStep step) async {
    final packageConfig = await step.packageConfig;
    final pkg = packageConfig.packages.firstWhere(
      (p) => p.name == step.inputId.package,
      orElse: () => packageConfig.packages.first,
    );
    if (pkg.root.scheme == 'file') {
      return pkg.root.toFilePath();
    }
    return Directory.current.path;
  }

  _SchemaDiff _diff(SchemaSnapshot from, SchemaSnapshot to) {
    final up = <String>[];
    final down = <String>[];

    final fromTables = from.tables;
    final toTables = to.tables;

    for (final entry in toTables.entries) {
      if (!fromTables.containsKey(entry.key)) {
        up.add(_createTableSql(entry.value));
        down.insert(0, _dropTableSql(entry.value.name));
      }
    }

    for (final entry in fromTables.entries) {
      if (!toTables.containsKey(entry.key)) {
        up.add(_dropTableSql(entry.value.name));
        down.insert(0, _createTableSql(entry.value));
      }
    }

    for (final entry in toTables.entries) {
      final name = entry.key;
      final next = entry.value;
      final prev = fromTables[name];
      if (prev == null) continue;

      final prevCols = prev.columns;
      final nextCols = next.columns;

      for (final colEntry in nextCols.entries) {
        if (!prevCols.containsKey(colEntry.key)) {
          up.add(_addColumnSql(name, colEntry.value));
          down.insert(0, _dropColumnSql(name, colEntry.value.name));
        }
      }

      for (final colEntry in prevCols.entries) {
        if (!nextCols.containsKey(colEntry.key)) {
          up.add(_dropColumnSql(name, colEntry.value.name));
          down.insert(0, _addColumnSql(name, colEntry.value));
        }
      }

      for (final colEntry in nextCols.entries) {
        final prevCol = prevCols[colEntry.key];
        if (prevCol == null) continue;
        final nextCol = colEntry.value;

        final forward = _alterColumnSql(name, prevCol, nextCol);
        final backward = _alterColumnSql(name, nextCol, prevCol);

        if (forward.isNotEmpty) {
          up.addAll(forward);
        }
        if (backward.isNotEmpty) {
          down.insertAll(0, backward.reversed);
        }
      }
    }

    return _SchemaDiff(up: up, down: down);
  }

  String _createTableSql(SnapshotTable table) {
    final cols = table.columns.values.map(_columnDefinition).join(',\n  ');
    return 'CREATE TABLE IF NOT EXISTS ${_quoteQualified(table.name)} (\n  $cols\n);';
  }

  String _dropTableSql(String tableName) {
    return 'DROP TABLE IF EXISTS ${_quoteQualified(tableName)};';
  }

  String _addColumnSql(String tableName, SnapshotColumn column) {
    return 'ALTER TABLE ${_quoteQualified(tableName)} ADD COLUMN ${_columnDefinition(column)};';
  }

  String _dropColumnSql(String tableName, String columnName) {
    return 'ALTER TABLE ${_quoteQualified(tableName)} DROP COLUMN "$columnName";';
  }

  List<String> _alterColumnSql(
    String tableName,
    SnapshotColumn from,
    SnapshotColumn to,
  ) {
    final statements = <String>[];
    final table = _quoteQualified(tableName);
    final col = '"${to.name}"';

    if (from.type != to.type) {
      statements.add('ALTER TABLE $table ALTER COLUMN $col TYPE ${to.type};');
    }

    if (from.nullable != to.nullable) {
      statements.add(
        to.nullable
            ? 'ALTER TABLE $table ALTER COLUMN $col DROP NOT NULL;'
            : 'ALTER TABLE $table ALTER COLUMN $col SET NOT NULL;',
      );
    }

    if (from.defaultValue != to.defaultValue) {
      if (to.defaultValue == null || to.defaultValue!.isEmpty) {
        statements.add('ALTER TABLE $table ALTER COLUMN $col DROP DEFAULT;');
      } else {
        statements.add(
          'ALTER TABLE $table ALTER COLUMN $col SET DEFAULT ${to.defaultValue};',
        );
      }
    }

    if (from.unique != to.unique) {
      statements.add(
        to.unique
            ? '-- NOTE: unique constraint change for $table.$col may require an index'
            : '-- NOTE: unique constraint drop for $table.$col may require dropping an index',
      );
    }

    if (from.isPrimaryKey != to.isPrimaryKey) {
      statements.add(
        '-- NOTE: primary key change for $table.$col requires table rebuild',
      );
    }

    return statements;
  }

  String _columnDefinition(SnapshotColumn column) {
    final parts = <String>['"${column.name}" ${column.type}'];
    if (!column.nullable) parts.add('NOT NULL');
    if (column.isPrimaryKey) parts.add('PRIMARY KEY');
    if (column.unique) parts.add('UNIQUE');
    if (column.defaultValue != null && column.defaultValue!.isNotEmpty) {
      parts.add('DEFAULT ${column.defaultValue}');
    }
    return parts.join(' ');
  }

  String _quoteQualified(String qualifiedName) {
    if (!qualifiedName.contains('.')) {
      return '"$qualifiedName"';
    }
    return qualifiedName.split('.').map((part) => '"$part"').join('.');
  }

  String _migrationClassName(String migrationId) {
    final sanitized = migrationId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return 'LoxiaMigration_$sanitized';
  }

  String _dartString(String value) {
    final escaped = value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    return "'$escaped'";
  }

  String _buildMigrationId() {
    final ts = DateTime.now().toUtc();
    return '${ts.year.toString().padLeft(4, '0')}${ts.month.toString().padLeft(2, '0')}${ts.day.toString().padLeft(2, '0')}${ts.hour.toString().padLeft(2, '0')}${ts.minute.toString().padLeft(2, '0')}${ts.second.toString().padLeft(2, '0')}';
  }

  String _toSnake(String input) {
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final c = input[i];
      final isUpper = c.toUpperCase() == c && c.toLowerCase() != c;
      if (isUpper && i != 0) buffer.write('_');
      buffer.write(c.toLowerCase());
    }
    return buffer.toString();
  }
}

class _SchemaDiff {
  _SchemaDiff({required this.up, required this.down});

  final List<String> up;
  final List<String> down;
}
