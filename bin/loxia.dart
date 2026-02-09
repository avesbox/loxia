import 'dart:io';

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
    case 'inspect':
      await _runInspect(options);
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
  stdout.writeln('  inspect           Inspect database and generate entities');
  stdout.writeln('');
  stdout.writeln('Options:');
  stdout.writeln(
    '  --engine <name>   Database engine: sqlite|postgres (default: sqlite)',
  );
  stdout.writeln(
    '  --db <path>       Path to SQLite database file (required for sqlite)',
  );
  stdout.writeln('  --pg-host <host>  Postgres host (required for postgres)');
  stdout.writeln('  --pg-port <port>  Postgres port (required for postgres)');
  stdout.writeln(
    '  --pg-db <name>    Postgres database (required for postgres)',
  );
  stdout.writeln(
    '  --pg-user <name>  Postgres username (required for postgres)',
  );
  stdout.writeln(
    '  --pg-password <pw> Postgres password (required for postgres)',
  );
  stdout.writeln(
    '  --pg-ssl <bool>   Postgres SSL (true/false, default: false)',
  );
  stdout.writeln(
    '  --migrations <path>  Dart migrations file (default: lib/migrations.dart)',
  );
  stdout.writeln(
    '  --output <path>      Output directory for entities (default: lib/src/entities)',
  );
  stdout.writeln(
    '  --steps <n>       Number of migrations to revert (default: 1)',
  );
  stdout.writeln('');
  stdout.writeln('Examples:');
  stdout.writeln('  loxia migrate:run --db ./app.db');
  stdout.writeln('  loxia migrate:revert --db ./app.db --steps 2');
  stdout.writeln(
    '  loxia migrate:run --engine postgres --pg-host localhost --pg-port 5432 --pg-db app --pg-user postgres --pg-password secret',
  );
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
  await _runMigrationRunner(options, mode: 'run', steps: 0);
}

Future<void> _revertMigrations(Map<String, String> options) async {
  final steps = int.tryParse(options['steps'] ?? '1') ?? 1;
  if (steps <= 0) {
    stderr.writeln('--steps must be >= 1');
    exit(64);
  }
  await _runMigrationRunner(options, mode: 'revert', steps: steps);
}

Future<void> _runInspect(Map<String, String> options) async {
  final output = options['output'] ?? 'lib/src/entities';
  final engine = (options['engine'] ?? 'sqlite').toLowerCase();
  
  final args = <String>[engine, output];
  if (engine == 'sqlite') {
    final dbPath = options['db'];
    if (dbPath == null || dbPath.trim().isEmpty) {
      stderr.writeln('Missing required option: --db');
      exit(64);
    }
    args.add(dbPath);
  } else if (engine == 'postgres') {
     final host = options['pg-host'];
    final port = options['pg-port'];
    final database = options['pg-db'];
    final user = options['pg-user'];
    final password = options['pg-password'];
    if ([
      host,
      port,
      database,
      user,
      password,
    ].any((v) => v == null || v.trim().isEmpty)) {
      stderr.writeln(
        'Missing required postgres options: --pg-host --pg-port --pg-db --pg-user --pg-password',
      );
      exit(64);
    }
    final ssl = (options['pg-ssl'] ?? 'false').toLowerCase();
    args.addAll([host!, port!, database!, user!, password!, ssl]);
  } else {
    stderr.writeln('Unknown engine: $engine');
    exit(64);
  }

  final runnerPath = await _writeInspectRunner();
  final runArgs = ['run', runnerPath, ...args];
  final result = await Process.run(Platform.resolvedExecutable, runArgs);
  
  if (result.stdout != null && result.stdout.toString().trim().isNotEmpty) {
    stdout.write(result.stdout);
  }
  if (result.stderr != null && result.stderr.toString().trim().isNotEmpty) {
    stderr.write(result.stderr);
  }
  if (result.exitCode != 0) {
    exit(result.exitCode);
  }
}

Future<void> _runMigrationRunner(
  Map<String, String> options, {
  required String mode,
  required int steps,
}) async {
  final engine = (options['engine'] ?? 'sqlite').toLowerCase();
  final args = <String>[mode, engine];
  if (engine == 'sqlite') {
    final dbPath = options['db'];
    if (dbPath == null || dbPath.trim().isEmpty) {
      stderr.writeln('Missing required option: --db');
      exit(64);
    }
    args.add(dbPath);
  } else if (engine == 'postgres') {
    final host = options['pg-host'];
    final port = options['pg-port'];
    final database = options['pg-db'];
    final user = options['pg-user'];
    final password = options['pg-password'];
    if ([
      host,
      port,
      database,
      user,
      password,
    ].any((v) => v == null || v.trim().isEmpty)) {
      stderr.writeln(
        'Missing required postgres options: --pg-host --pg-port --pg-db --pg-user --pg-password',
      );
      exit(64);
    }
    final ssl = (options['pg-ssl'] ?? 'false').toLowerCase();
    args.addAll([host!, port!, database!, user!, password!, ssl]);
  } else {
    stderr.writeln('Unknown engine: $engine');
    exit(64);
  }

  final migrationsPath = options['migrations'] ?? 'lib/migrations.dart';
  final packageName = _readPackageName();
  final importUri = _resolveMigrationImport(migrationsPath, packageName);
  final runnerPath = await _writeRunner(importUri);

  final runArgs = ['run', runnerPath, ...args, if (steps > 0) steps.toString()];

  final result = await Process.run(Platform.resolvedExecutable, runArgs);

  if (result.stdout != null && result.stdout.toString().trim().isNotEmpty) {
    stdout.write(result.stdout);
  }
  if (result.stderr != null && result.stderr.toString().trim().isNotEmpty) {
    stderr.write(result.stderr);
  }
  if (result.exitCode != 0) {
    exit(result.exitCode);
  }
}

String _readPackageName() {
  final file = File('pubspec.yaml');
  if (!file.existsSync()) {
    stderr.writeln('pubspec.yaml not found in current directory');
    exit(64);
  }
  final lines = file.readAsLinesSync();
  for (final line in lines) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('name:')) {
      return trimmed.substring('name:'.length).trim();
    }
  }
  stderr.writeln('Package name not found in pubspec.yaml');
  exit(64);
}

String _resolveMigrationImport(String path, String packageName) {
  final normalized = path.replaceAll('\\', '/');
  if (normalized.startsWith('package:')) {
    return normalized;
  }
  if (!normalized.startsWith('lib/')) {
    stderr.writeln('Migrations path must be under lib/ or a package: URI');
    exit(64);
  }
  return 'package:$packageName/${normalized.substring('lib/'.length)}';
}

Future<String> _writeRunner(String importUri) async {
  final dir = Directory('.loxia');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  final file = File(
    '${dir.path}${Platform.pathSeparator}migration_runner.dart',
  );
  await file.writeAsString(_runnerSource(importUri));
  return file.path;
}

Future<String> _writeInspectRunner() async {
  final dir = Directory('.loxia');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  final file = File(
    '${dir.path}${Platform.pathSeparator}inspect_runner.dart',
  );
  await file.writeAsString(_inspectRunnerSource());
  return file.path;
}

String _runnerSource(String importUri) {
  return '''
import 'dart:io';

import 'package:loxia/loxia.dart';
import 'package:postgres/postgres.dart';
import '$importUri' as user;

Future<void> main(List<String> args) async {
  if (args.length < 3) {
    stderr.writeln('Usage: <run|revert> <sqlite|postgres> <dbPath|pg args...> [steps]');
    exit(64);
  }
  final mode = args[0];
  final engineType = args[1];
  final steps = args.length > 2 ? int.tryParse(args.last) ?? 1 : 1;

  EngineAdapter engine;
  if (engineType == 'sqlite') {
    final dbPath = args[2];
    engine = SqliteEngine.file(dbPath);
  } else if (engineType == 'postgres') {
    if (args.length < 8) {
      stderr.writeln('Usage: <run|revert> postgres <host> <port> <db> <user> <password> <ssl> [steps]');
      exit(64);
    }
    final host = args[2];
    final port = int.tryParse(args[3]) ?? 5432;
    final database = args[4];
    final userName = args[5];
    final password = args[6];
    final useSSL = args[7].toLowerCase() == 'true';
    engine = PostgresEngine.connect(
      Endpoint(host: host, port: port, database: database),
      settings: ConnectionSettings(
        username: userName,
        password: password,
        sslMode: useSSL ? SslMode.require : SslMode.disable,
      ),
    );
  } else {
    stderr.writeln('Unknown engine: \$engineType');
    exit(64);
  }

  await engine.open();
  try {
    await engine.ensureHistoryTable();
    final migrations = user.migrations;
    final byVersion = {for (final m in migrations) m.version: m};
    final applied = await engine.getAppliedVersions();
    final missing = applied.where((v) => !byVersion.containsKey(v)).toList();
    if (missing.isNotEmpty) {
      throw StateError('Migration history mismatch. Missing in code: \$missing');
    }

    if (mode == 'run') {
      final pending = migrations
          .where((m) => !applied.contains(m.version))
          .toList()
        ..sort((a, b) => a.version.compareTo(b.version));
      if (pending.isEmpty) {
        stdout.writeln('No pending migrations');
        return;
      }
      for (final migration in pending) {
        stdout.writeln('Applying migration \${migration.version}...');
        await engine.transaction((tx) async {
          await migration.up(tx);
          await tx.execute(
            'INSERT INTO _loxia_migrations (version, applied_at) VALUES (?, CURRENT_TIMESTAMP)',
            [migration.version],
          );
        });
      }
      stdout.writeln('Migrations complete');
      return;
    }

    if (mode == 'revert') {
      if (applied.isEmpty) {
        stdout.writeln('No applied migrations to revert');
        return;
      }
      final toRevert = applied.reversed.take(steps).toList();
      for (final version in toRevert) {
        final migration = byVersion[version];
        if (migration == null) {
          throw StateError('Missing migration class for version \$version');
        }
        stdout.writeln('Reverting migration \$version...');
        await engine.transaction((tx) async {
          await migration.down(tx);
          await tx.execute(
            'DELETE FROM _loxia_migrations WHERE version = ?',
            [version],
          );
        });
      }
      stdout.writeln('Revert complete');
      return;
    }

    stderr.writeln('Unknown mode: \$mode');
    exit(64);
  } finally {
    await engine.close();
  }
}
''';
}

String _inspectRunnerSource() {
  return '''
import 'dart:io';

import 'package:loxia/loxia.dart';
import 'package:loxia/src/datasource/sqlite_engine.dart';
import 'package:loxia/src/datasource/postgres_engine.dart';
import 'package:loxia/src/inspection/entity_writer.dart';
import 'package:postgres/postgres.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('Usage: inspect <sqlite|postgres> <output> <db args...>');
    exit(64);
  }
  final engineType = args[0];
  final outputPath = args[1];

  EngineAdapter engine;
  if (engineType == 'sqlite') {
    if (args.length < 3) {
       stderr.writeln('Usage: inspect sqlite <output> <dbPath>');
       exit(64);
    }
    final dbPath = args[2];
    engine = SqliteEngine.file(dbPath);
  } else if (engineType == 'postgres') {
    if (args.length < 8) {
      stderr.writeln('Usage: inspect postgres <output> <host> <port> <db> <user> <password> <ssl>');
      exit(64);
    }
    final host = args[2];
    final port = int.tryParse(args[3]) ?? 5432;
    final database = args[4];
    final userName = args[5];
    final password = args[6];
    final useSSL = args[7].toLowerCase() == 'true';
    engine = PostgresEngine.connect(
      Endpoint(host: host, port: port, database: database),
      settings: ConnectionSettings(
        username: userName,
        password: password,
        sslMode: useSSL ? SslMode.require : SslMode.disable,
      ),
    );
  } else {
    stderr.writeln('Unknown engine: \$engineType');
    exit(64);
  }

  stdout.writeln('Connecting to database...');
  await engine.open();
  
  try {
    stdout.writeln('Reading schema...');
    final schema = await engine.readSchema();
    
    stdout.writeln('Generating entities...');
    final writer = EntityWriter(schema);
    final files = writer.generate();
    
    final outputDir = Directory(outputPath);
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }
    
    for (final entry in files.entries) {
      final file = File('\${outputDir.path}\${Platform.pathSeparator}\${entry.key}');
      await file.writeAsString(entry.value);
      stdout.writeln('Generated: \${entry.key}');
    }
    
    stdout.writeln('Inspection complete. Generated \${files.length} files in \$outputPath');
  } catch (e, stack) {
    stderr.writeln('Error during inspection: \$e');
    stderr.writeln(stack);
    exit(1);
  } finally {
    await engine.close();
  }
}
''';
}

