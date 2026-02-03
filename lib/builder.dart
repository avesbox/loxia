import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/generator/entity_generator.dart';
import 'src/generator/schema_snapshot_builder.dart';

Builder entityDescriptorBuilder(BuilderOptions options) =>
    SharedPartBuilder([LoxiaEntityGenerator()], 'loxia');

Builder schemaSnapshotBuilder(BuilderOptions options) => SchemaSnapshotBuilder(
  snapshotVersion: options.config['version']?.toString() ?? '1.0',
  emitMigrations: options.config['emit_migrations'] as bool? ?? true,
  migrationsDirName:
      options.config['migrations_dir']?.toString() ?? 'migrations',
  includeGlobs:
      (options.config['include_globs'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
      const ['lib/**.dart'],
  excludeGlobs:
      (options.config['exclude_globs'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
      const ['**/*.g.dart', '**/*.loxia.g.part'],
);
