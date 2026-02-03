import 'package:sqlite3/sqlite3.dart' as sq;

import '../migrations/schema.dart';
import '../annotations/column.dart';
import 'engine_adapter.dart';

class SqliteEngine implements EngineAdapter {
  SqliteEngine._(this._open);

  final sq.Database Function() _open;
  sq.Database? _db;

  static SqliteEngine inMemory() => SqliteEngine._(() => sq.sqlite3.openInMemory());

  static SqliteEngine file(String path) => SqliteEngine._(() => sq.sqlite3.open(path, mutex: true));

  @override
  Future<void> open() async {
    _db = _open();
  }

  @override
  Future<void> close() async {
    _db?.close();
    _db = null;
  }

  @override
  Future<void> executeBatch(List<String> statements) async {
    final db = _ensureDb();
    for (final s in statements) {
      db.execute(s);
    }
  }

  @override
  Future<int> execute(String sql, [List<Object?> params = const []]) async {
    final db = _ensureDb();
    if (params.isEmpty) {
      db.execute(sql);
    } else {
      final stmt = db.prepare(sql);
      try {
        stmt.execute(params);
      } finally {
        stmt.close();
      }
    }
    final rs = db.select('SELECT changes() AS c');
    return (rs.first['c'] as int?) ?? 0;
  }

  @override
  Future<List<Map<String, dynamic>>> query(String sql, [List<Object?> params = const []]) async {
    final db = _ensureDb();
    final sq.ResultSet rs;
    if (params.isEmpty) {
      rs = db.select(sql);
    } else {
      final stmt = db.prepare(sql);
      try {
        rs = stmt.select(params);
      } finally {
        stmt.close();
      }
    }
    final cols = rs.columnNames;
    return rs.rows
        .map((row) => {
              for (var i = 0; i < cols.length; i++) cols[i]: row[i],
            })
        .toList(growable: false);
  }

  @override
  Future<SchemaState> readSchema() async {
    final db = _ensureDb();
    final tables = <String, SchemaTable>{};
    final tableRows = db.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
    );
    for (final row in tableRows) {
      final name = row['name'] as String;
      final colRs = db.select('PRAGMA table_info("$name")');
      final cols = <String, SchemaColumn>{};
      for (final c in colRs) {
        final cname = c['name'] as String;
        final ctypeStr = (c['type'] as String?) ?? '';
        final notNull = (c['notnull'] as int?) == 1;
        final pk = (c['pk'] as int?) == 1;
        cols[cname] = SchemaColumn(
          name: cname,
          type: _mapType(ctypeStr),
          nullable: !notNull,
          isPrimaryKey: pk,
        );
      }
      tables[name] = SchemaTable(name: name, columns: cols);
    }
    return SchemaState(tables: tables);
  }

  ColumnType _mapType(String t) {
    final up = t.toUpperCase();
    if (up.contains('INT')) return ColumnType.integer;
    if (up.contains('CHAR') || up.contains('CLOB') || up.contains('TEXT')) return ColumnType.text;
    if (up.contains('BLOB')) return ColumnType.binary;
    if (up.contains('REAL') || up.contains('FLOA') || up.contains('DOUB')) return ColumnType.doublePrecision;
    if (up.contains('JSON')) return ColumnType.json;
    if (up.contains('BOOL')) return ColumnType.boolean;
    if (up.contains('TIME') || up.contains('DATE')) return ColumnType.dateTime;
    // Fallback to text affinity per SQLite rules
    return ColumnType.text;
  }

  sq.Database _ensureDb() {
    final db = _db;
    if (db == null) {
      throw StateError('SqliteEngine is not open');
    }
    return db;
  }
}
