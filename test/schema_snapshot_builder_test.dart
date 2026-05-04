import 'package:build_test/build_test.dart';
import 'package:loxia/src/generator/schema_snapshot_builder.dart';
import 'package:test/test.dart';

void main() {
  test('preserves explicit text columns in schema snapshots', () async {
    await testBuilder(
      SchemaSnapshotBuilder(emitMigrations: false),
      {
        'loxia|pubspec.yaml': 'name: loxia',
        'loxia|lib/test_entity.dart': '''
import 'package:loxia/src/annotations/column.dart';
import 'package:loxia/src/annotations/entity_meta.dart';

@EntityMeta(table: 'posts')
class Post {
  @PrimaryKey()
  final int id;

  @Column(type: ColumnType.text)
  final String body;

  Post(this.id, this.body);
}
''',
        'loxia|lib/src/annotations/column.dart': '''
class Column {
  final String? name;
  final ColumnType? type;
  final bool nullable;
  final bool unique;
  final dynamic defaultValue;

  const Column({
    this.name,
    this.type,
    this.nullable = false,
    this.unique = false,
    this.defaultValue,
  });
}

class PrimaryKey {
  final bool autoIncrement;
  final bool uuid;

  const PrimaryKey({this.autoIncrement = false, this.uuid = false});
}

enum ColumnType {
  integer,
  text,
  character,
  varChar,
  boolean,
  doublePrecision,
  dateTime,
  timestamp,
  json,
  binary,
  blob,
  uuid,
}
''',
        'loxia|lib/src/annotations/entity_meta.dart': '''
class EntityMeta {
  final String? table;
  final String? schema;
  final bool omitNullJsonFields;
  final List<Query> queries;
  final List<Object> uniqueConstraints;
  final List<Object> indexes;

  const EntityMeta({
    this.table,
    this.schema,
    this.omitNullJsonFields = true,
    this.queries = const [],
    this.uniqueConstraints = const [],
    this.indexes = const [],
  });
}

class Query {
  final String name;
  final String sql;
  final List<Object> lifecycleHooks;

  const Query({
    required this.name,
    required this.sql,
    this.lifecycleHooks = const [],
  });
}
''',
      },
      rootPackage: 'loxia',
      outputs: {
        'loxia|.loxia/schema_v1.json':
            '{\n'
            '  "version": "1.0",\n'
            '  "tables": {\n'
            '    "posts": {\n'
            '      "columns": {\n'
            '        "id": {\n'
            '          "type": "int",\n'
            '          "nullable": false,\n'
            '          "isPrimaryKey": true,\n'
            '          "unique": false\n'
            '        },\n'
            '        "body": {\n'
            '          "type": "text",\n'
            '          "nullable": false,\n'
            '          "isPrimaryKey": false,\n'
            '          "unique": false\n'
            '        }\n'
            '      }\n'
            '    }\n'
            '  }\n'
            '}',
      },
    );
  });
}
