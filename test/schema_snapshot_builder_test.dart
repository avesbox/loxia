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
  final String? enumValueField;

  const Column({
    this.name,
    this.type,
    this.nullable = false,
    this.unique = false,
    this.defaultValue,
    this.enumValueField,
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

  test('includes enum defaults in schema snapshots', () async {
    await testBuilder(
      SchemaSnapshotBuilder(emitMigrations: false),
      {
        'loxia|pubspec.yaml': 'name: loxia',
        'loxia|lib/test_entity.dart': '''
import 'package:loxia/src/annotations/column.dart';
import 'package:loxia/src/annotations/entity_meta.dart';

enum Status { draft, published }

@EntityMeta(table: 'posts')
class Post {
  @PrimaryKey()
  final int id;

  @Column(type: ColumnType.text, defaultValue: Status.draft)
  final Status stateText;

  @Column(type: ColumnType.integer, defaultValue: Status.published)
  final Status stateInt;

  Post(this.id, this.stateText, this.stateInt);
}
''',
        'loxia|lib/src/annotations/column.dart': '''
class Column {
  final String? name;
  final ColumnType? type;
  final bool nullable;
  final bool unique;
  final dynamic defaultValue;
  final String? enumValueField;

  const Column({
    this.name,
    this.type,
    this.nullable = false,
    this.unique = false,
    this.defaultValue,
    this.enumValueField,
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
            '        "state_text": {\n'
            '          "type": "text",\n'
            '          "nullable": false,\n'
            '          "isPrimaryKey": false,\n'
            '          "unique": false,\n'
            '          "defaultValue": "\'draft\'"\n'
            '        },\n'
            '        "state_int": {\n'
            '          "type": "int",\n'
            '          "nullable": false,\n'
            '          "isPrimaryKey": false,\n'
            '          "unique": false,\n'
            '          "defaultValue": "1"\n'
            '        }\n'
            '      }\n'
            '    }\n'
            '  }\n'
            '}',
      },
    );
  });

  test('includes custom string enum defaults in schema snapshots', () async {
    await testBuilder(
      SchemaSnapshotBuilder(emitMigrations: false),
      {
        'loxia|pubspec.yaml': 'name: loxia',
        'loxia|lib/test_entity.dart': '''
import 'package:loxia/src/annotations/column.dart';
import 'package:loxia/src/annotations/entity_meta.dart';

enum Status {
  draft('DRAFT'),
  published('PUBLISHED');

  const Status(this.value);

  final String value;
}

@EntityMeta(table: 'posts')
class Post {
  @PrimaryKey()
  final int id;

  @Column(
    type: ColumnType.text,
    defaultValue: Status.published,
    enumValueField: 'value',
  )
  final Status status;

  Post(this.id, this.status);
}
''',
        'loxia|lib/src/annotations/column.dart': '''
class Column {
  final String? name;
  final ColumnType? type;
  final bool nullable;
  final bool unique;
  final dynamic defaultValue;
  final String? enumValueField;

  const Column({
    this.name,
    this.type,
    this.nullable = false,
    this.unique = false,
    this.defaultValue,
    this.enumValueField,
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
            '        "status": {\n'
            '          "type": "text",\n'
            '          "nullable": false,\n'
            '          "isPrimaryKey": false,\n'
            '          "unique": false,\n'
            '          "defaultValue": "\'PUBLISHED\'"\n'
            '        }\n'
            '      }\n'
            '    }\n'
            '  }\n'
            '}',
      },
    );
  });
}
