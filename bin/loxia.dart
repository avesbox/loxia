import 'dart:convert';
import 'dart:io';

import 'package:loxia/loxia.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first == 'help' || args.first == '--help') {
    _printUsage();
    exit(0);
  }

  final command = args.first;
  final options = _parseOptions(args.sublist(1));

  switch (command) {
    case 'migrate:run':
      await _runMigrations(options);
      return;
    case 'migrate:revert':
      await _revertMigrations(options);
      return;
    default:
      stderr.writeln('Unknown command: $command');
      _printUsage();
      exit(64);
  }
}

void _printUsage() {
  stdout.writeln('Loxia CLI');
  stdout.writeln('');
  stdout.writeln('Usage: loxia <command> [options]');
  stdout.writeln('');
  stdout.writeln('Commands:');
  stdout.writeln('  migrate:run       Apply pending migrations');
  stdout.writeln('  migrate:revert    Revert applied migrations');
  stdout.writeln('');
  stdout.writeln('Options:');
  stdout.writeln('  --db <path>       Path to SQLite database file (required)');
  stdout.writeln(
    '  --dir <path>      Migrations directory (default: .loxia/migrations)',
  );
  stdout.writeln(
    '  --steps <n>       Number of migrations to revert (default: 1)',
  );
  stdout.writeln('');
  stdout.writeln('Examples:');
  stdout.writeln('  loxia migrate:run --db ./app.db');
  stdout.writeln('  loxia migrate:revert --db ./app.db --steps 2');
}

Map<String, String> _parseOptions(List<String> args) {
  final options = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg.startsWith('--')) {
      final key = arg.substring(2);
      final value = (i + 1) < args.length ? args[i + 1] : '';
      if (value.isNotEmpty && !value.startsWith('--')) {
        options[key] = value;
        i++;
      } else {
        options[key] = 'true';
      }
    }
  }
  return options;
}

Future<void> _runMigrations(Map<String, String> options) async {
  final dbPath = options['db'];
  if (dbPath == null || dbPath.trim().isEmpty) {
    stderr.writeln('Missing required option: --db');
    exit(64);
  }
  final dirPath = options['dir'] ?? '.loxia/migrations';

  final migrations = _listMigrations(dirPath);
  if (migrations.isEmpty) {
    stdout.writeln('No migrations found in $dirPath');
    return;
  }

  final applied = await _readApplied(dirPath);
  final pending = migrations.where((m) => !applied.contains(m.id)).toList();

  if (pending.isEmpty) {
    stdout.writeln('No pending migrations');
    return;
  }

  final engine = SqliteEngine.file(dbPath);
  await engine.open();
  try {
    for (final migration in pending) {
      stdout.writeln('Applying ${migration.id}...');
      final sql = await _readMigrationSql(migration.path);
      if (sql.up.isEmpty) {
        stdout.writeln('  Skipped (no up statements)');
        applied.add(migration.id);
        await _writeApplied(dirPath, applied);
        continue;
      }
      await engine.executeBatch(sql.up);
      applied.add(migration.id);
      await _writeApplied(dirPath, applied);
    }
    stdout.writeln('Migrations complete');
  } catch (e) {
    stderr.writeln('Migration failed: $e');
    exit(1);
  } finally {
    await engine.close();
  }
}

Future<void> _revertMigrations(Map<String, String> options) async {
  final dbPath = options['db'];
  if (dbPath == null || dbPath.trim().isEmpty) {
    stderr.writeln('Missing required option: --db');
    exit(64);
  }
  final dirPath = options['dir'] ?? '.loxia/migrations';
  final steps = int.tryParse(options['steps'] ?? '1') ?? 1;
  if (steps <= 0) {
    stderr.writeln('--steps must be >= 1');
    exit(64);
  }

  final applied = await _readApplied(dirPath);
  if (applied.isEmpty) {
    stdout.writeln('No applied migrations to revert');
    return;
  }

  final toRevert = applied.reversed.take(steps).toList();
  final engine = SqliteEngine.file(dbPath);
  await engine.open();
  try {
    for (final id in toRevert) {
      final path = _migrationPath(dirPath, id);
      if (!File(path).existsSync()) {
        stderr.writeln('Missing migration file for $id at $path');
        exit(1);
      }
      stdout.writeln('Reverting $id...');
      final sql = await _readMigrationSql(path);
      if (sql.down.isEmpty) {
        stdout.writeln('  Skipped (no down statements)');
        applied.remove(id);
        await _writeApplied(dirPath, applied);
        continue;
      }
      await engine.executeBatch(sql.down);
      applied.remove(id);
      await _writeApplied(dirPath, applied);
    }
    stdout.writeln('Revert complete');
  } catch (e) {
    stderr.writeln('Revert failed: $e');
    exit(1);
  } finally {
    await engine.close();
  }
}

List<_MigrationFile> _listMigrations(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) return [];
  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return files
      .map(
        (f) => _MigrationFile(id: _migrationIdFromPath(f.path), path: f.path),
      )
      .toList();
}

String _migrationIdFromPath(String path) {
  final fileName = path.split(Platform.pathSeparator).last;
  return fileName.replaceAll('.sql', '');
}

String _migrationPath(String dirPath, String id) {
  return '$dirPath${Platform.pathSeparator}$id.sql';
}

Future<List<String>> _readApplied(String dirPath) async {
  final file = File('$dirPath${Platform.pathSeparator}applied.json');
  if (!file.existsSync()) return [];
  final text = await file.readAsString();
  final json = jsonDecode(text);
  if (json is! List) return [];
  return json.map((e) => e.toString()).toList();
}

Future<void> _writeApplied(String dirPath, List<String> applied) async {
  final file = File('$dirPath${Platform.pathSeparator}applied.json');
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(applied));
}

Future<_MigrationSql> _readMigrationSql(String path) async {
  final content = await File(path).readAsString();
  final lower = content.toLowerCase();
  final upIndex = lower.indexOf('-- up');
  final downIndex = lower.indexOf('-- down');

  String upSection;
  String downSection;
  if (upIndex == -1 && downIndex == -1) {
    upSection = content;
    downSection = '';
  } else {
    final upStart = upIndex == -1 ? 0 : upIndex;
    final downStart = downIndex == -1 ? content.length : downIndex;
    upSection = content.substring(upStart, downStart);
    downSection = downIndex == -1 ? '' : content.substring(downStart);
  }

  final upStatements = _splitStatements(
    _stripComments(_stripMarker(upSection)),
  );
  final downStatements = _splitStatements(
    _stripComments(_stripMarker(downSection)),
  );

  return _MigrationSql(up: upStatements, down: downStatements);
}

String _stripMarker(String section) {
  final lines = section.split('\n');
  final filtered = <String>[];
  for (final line in lines) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('-- up') || trimmed.startsWith('-- down')) {
      continue;
    }
    filtered.add(line);
  }
  return filtered.join('\n');
}

String _stripComments(String section) {
  final lines = section.split('\n');
  final filtered = <String>[];
  for (final line in lines) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('--')) {
      continue;
    }
    filtered.add(line);
  }
  return filtered.join('\n');
}

List<String> _splitStatements(String section) {
  final parts = section.split(';');
  return parts.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
}

class _MigrationFile {
  _MigrationFile({required this.id, required this.path});

  final String id;
  final String path;
}

class _MigrationSql {
  _MigrationSql({required this.up, required this.down});

  final List<String> up;
  final List<String> down;
}
