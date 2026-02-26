import '../metadata/entity_descriptor.dart';
import '../metadata/column_descriptor.dart';
import '../metadata/relation_descriptor.dart';
import '../metadata/unique_constraint_descriptor.dart';
import '../annotations/column.dart';
import 'schema.dart';

/// Simple diff that generates forward-only DDL actions to sync schema.
class MigrationPlan {
  final List<String> statements;
  const MigrationPlan(this.statements);
  bool get isEmpty => statements.isEmpty;
}

class MigrationPlanner {
  MigrationPlan diff({
    required List<EntityDescriptor> entities,
    required SchemaState current,
    bool supportsAlterTableAddConstraint = true,
  }) {
    final stmts = <String>[];
    final entityByType = {for (final e in entities) e.entityType: e};
    final processedJoinTables = <String>{};
    final joinTableSpecs = <_JoinTableSpec>[];
    // Collect foreign key constraints to add after all tables are created.
    // This avoids "relation does not exist" errors for bidirectional relations.
    final deferredForeignKeys = <_DeferredForeignKey>[];

    for (final entity in entities) {
      final joinColumns = _collectJoinColumns(entity, entityByType);
      final table = current.tables[entity.tableName];
      if (table == null) {
        final cols = <String>[];
        for (final c in entity.columns) {
          cols.add(_columnDDL(c));
        }
        // Add join columns and defer FK constraints only if the engine
        // supports ALTER TABLE ... ADD CONSTRAINT.
        for (final jc in joinColumns) {
          cols.add(
            supportsAlterTableAddConstraint
                ? _joinColumnDDLWithoutFK(jc)
                : _joinColumnDDLWithFK(jc),
          );
          if (supportsAlterTableAddConstraint) {
            deferredForeignKeys.add(
              _DeferredForeignKey(
                tableName: entity.tableName,
                columnName: jc.name,
                referencesTable: jc.referencesTable,
                referencesColumn: jc.referencesColumn,
                onDeleteCascade: jc.onDeleteCascade,
              ),
            );
          }
        }
        final create =
            'CREATE TABLE IF NOT EXISTS ${entity.tableName} (\n  ${cols.join(',\n  ')}\n)';
        stmts.add(create);
      } else {
        for (final c in entity.columns) {
          if (!table.columns.containsKey(c.name)) {
            stmts.add(
              'ALTER TABLE ${entity.tableName} ADD COLUMN ${_columnDDL(c)}',
            );
          }
        }
        for (final jc in joinColumns) {
          if (!table.columns.containsKey(jc.name)) {
            stmts.add(
              'ALTER TABLE ${entity.tableName} ADD COLUMN ${_joinColumnDDLWithoutFK(jc)}',
            );
            if (supportsAlterTableAddConstraint) {
              deferredForeignKeys.add(
                _DeferredForeignKey(
                  tableName: entity.tableName,
                  columnName: jc.name,
                  referencesTable: jc.referencesTable,
                  referencesColumn: jc.referencesColumn,
                  onDeleteCascade: jc.onDeleteCascade,
                ),
              );
            }
          }
        }
      }

      for (final relation in entity.relations.where(
        (r) => r.isOwningSide && r.joinTable != null,
      )) {
        final joinSpec = _buildJoinTableSpec(entity, relation, entityByType);
        if (processedJoinTables.add(joinSpec.name)) {
          joinTableSpecs.add(joinSpec);
        }
      }
    }

    // Process join tables after all base tables are ensured to exist.
    // Add columns without FK constraints, defer FKs to the final phase.
    for (final joinSpec in joinTableSpecs) {
      final schemaTable = current.tables[joinSpec.name];
      if (schemaTable == null) {
        final cols = joinSpec.columns
            .map(
              supportsAlterTableAddConstraint
                  ? _joinColumnDDLWithoutFK
                  : _joinColumnDDLWithFK,
            )
            .join(',\n  ');
        final create =
            'CREATE TABLE IF NOT EXISTS ${joinSpec.name} (\n  $cols\n)';
        stmts.add(create);
        if (supportsAlterTableAddConstraint) {
          for (final col in joinSpec.columns) {
            deferredForeignKeys.add(
              _DeferredForeignKey(
                tableName: joinSpec.name,
                columnName: col.name,
                referencesTable: col.referencesTable,
                referencesColumn: col.referencesColumn,
                onDeleteCascade: col.onDeleteCascade,
              ),
            );
          }
        }
      } else {
        for (final col in joinSpec.columns) {
          if (!schemaTable.columns.containsKey(col.name)) {
            stmts.add(
              'ALTER TABLE ${joinSpec.name} ADD COLUMN ${_joinColumnDDLWithoutFK(col)}',
            );
            if (supportsAlterTableAddConstraint) {
              deferredForeignKeys.add(
                _DeferredForeignKey(
                  tableName: joinSpec.name,
                  columnName: col.name,
                  referencesTable: col.referencesTable,
                  referencesColumn: col.referencesColumn,
                  onDeleteCascade: col.onDeleteCascade,
                ),
              );
            }
          }
        }
      }
    }

    // Add all foreign key constraints after all tables and columns exist.
    // This ensures bidirectional relations work correctly.
    if (supportsAlterTableAddConstraint) {
      for (final fk in deferredForeignKeys) {
        stmts.add(_foreignKeyConstraintDDL(fk));
      }
    }

    // Process composite unique constraints after all tables are created.
    for (final entity in entities) {
      for (final constraint in entity.uniqueConstraints) {
        stmts.add(_uniqueConstraintDDL(entity.tableName, constraint));
      }
    }

    return MigrationPlan(stmts);
  }

  String _uniqueConstraintDDL(
    String tableName,
    UniqueConstraintDescriptor constraint,
  ) {
    final constraintName = constraint.generateName(tableName);
    final columns = constraint.columns.map((c) => '"$c"').join(', ');
    return 'CREATE UNIQUE INDEX IF NOT EXISTS "$constraintName" ON $tableName ($columns)';
  }

  String _columnDDL(ColumnDescriptor c) {
    final type = c.autoIncrement && c.type == ColumnType.integer
        ? 'INTEGER'
        : _typeToSql(c.type);
    final parts = <String>['"${c.name}" $type'];
    // SQLite: INTEGER PRIMARY KEY AUTOINCREMENT columns must not have NOT NULL
    final skipNotNull = c.autoIncrement && c.isPrimaryKey;
    if (!c.nullable && !skipNotNull) parts.add('NOT NULL');
    if (c.isPrimaryKey) parts.add('PRIMARY KEY');
    if (c.autoIncrement && c.type == ColumnType.integer) {
      parts.add('AUTOINCREMENT'); // SQLite specific; engine will adapt
    }
    if (c.unique) parts.add('UNIQUE');
    if (c.defaultValue != null) {
      parts.add('DEFAULT ${_defaultLiteral(c.defaultValue)}');
    }
    return parts.join(' ');
  }

  /// Creates column DDL without inline foreign key constraint.
  /// Foreign keys are added later via ALTER TABLE to handle circular references.
  String _joinColumnDDLWithoutFK(_JoinColumnSpec spec) {
    final parts = <String>['"${spec.name}" ${_typeToSql(spec.type)}'];
    if (!spec.nullable) parts.add('NOT NULL');
    if (spec.unique) parts.add('UNIQUE');
    return parts.join(' ');
  }

  String _joinColumnDDLWithFK(_JoinColumnSpec spec) {
    final parts = <String>[
      _joinColumnDDLWithoutFK(spec),
      'REFERENCES ${_quoteQualified(spec.referencesTable)}("${spec.referencesColumn}")',
      if (spec.onDeleteCascade) 'ON DELETE CASCADE',
    ];
    return parts.join(' ');
  }

  /// Generates ALTER TABLE statement to add a foreign key constraint.
  String _foreignKeyConstraintDDL(_DeferredForeignKey fk) {
    final constraintName = 'fk_${fk.tableName}_${fk.columnName}';
    return 'ALTER TABLE ${_quoteQualified(fk.tableName)} '
        'ADD CONSTRAINT "$constraintName" '
        'FOREIGN KEY ("${fk.columnName}") '
      'REFERENCES ${_quoteQualified(fk.referencesTable)}("${fk.referencesColumn}")'
      '${fk.onDeleteCascade ? ' ON DELETE CASCADE' : ''}';
  }

  String _typeToSql(ColumnType t) {
    switch (t) {
      case ColumnType.integer:
        return 'BIGINT';
      case ColumnType.text:
      case ColumnType.character:
      case ColumnType.varChar:
        return 'TEXT';
      case ColumnType.boolean:
        return 'BOOLEAN';
      case ColumnType.doublePrecision:
        return 'DOUBLE';
      case ColumnType.dateTime:
      case ColumnType.timestamp:
        return 'TIMESTAMP';
      case ColumnType.json:
        return 'JSON';
      case ColumnType.binary:
      case ColumnType.blob:
        return 'BLOB';
      case ColumnType.uuid:
        return 'UUID';
    }
  }

  String _defaultLiteral(dynamic v) {
    if (v is num) return v.toString();
    if (v is bool) return v ? 'TRUE' : 'FALSE';
    return "'${v.toString().replaceAll("'", "''")}'";
  }

  List<_JoinColumnSpec> _collectJoinColumns(
    EntityDescriptor entity,
    Map<Type, EntityDescriptor> entityByType,
  ) {
    final specs = <_JoinColumnSpec>[];
    for (final relation in entity.relations) {
      final joinColumn = relation.joinColumn;
      if (!relation.isOwningSide || joinColumn == null) continue;
      final target = _descriptorForType(relation.target, entityByType);
      specs.add(
        _joinColumnSpecFromDescriptor(
          joinColumn,
          target,
          onDeleteCascade: relation.shouldCascadeRemove,
        ),
      );
    }
    return specs;
  }

  _JoinTableSpec _buildJoinTableSpec(
    EntityDescriptor owner,
    RelationDescriptor relation,
    Map<Type, EntityDescriptor> entityByType,
  ) {
    final descriptor = relation.joinTable!;
    final columns = <_JoinColumnSpec>[];
    for (final col in descriptor.joinColumns) {
      columns.add(
        _joinColumnSpecFromDescriptor(
          col,
          owner,
          onDeleteCascade: true,
        ),
      );
    }
    final inverseDescriptor = _descriptorForType(relation.target, entityByType);
    for (final col in descriptor.inverseJoinColumns) {
      columns.add(
        _joinColumnSpecFromDescriptor(
          col,
          inverseDescriptor,
          onDeleteCascade: true,
        ),
      );
    }
    return _JoinTableSpec(name: descriptor.name, columns: columns);
  }

  _JoinColumnSpec _joinColumnSpecFromDescriptor(
    JoinColumnDescriptor descriptor,
    EntityDescriptor referenced,
    {
      required bool onDeleteCascade,
    }
  ) {
    ColumnDescriptor? referencedColumn;
    for (final column in referenced.columns) {
      if (column.name == descriptor.referencedColumnName) {
        referencedColumn = column;
        break;
      }
    }
    referencedColumn ??= referenced.primaryKey;
    if (referencedColumn == null) {
      throw StateError(
        'Referenced column ${descriptor.referencedColumnName} was not found on ${referenced.tableName}.',
      );
    }
    return _JoinColumnSpec(
      name: descriptor.name,
      type: referencedColumn.type,
      nullable: descriptor.nullable,
      unique: descriptor.unique,
      referencesTable: referenced.qualifiedTableName,
      referencesColumn: referencedColumn.name,
      onDeleteCascade: onDeleteCascade,
    );
  }

  EntityDescriptor _descriptorForType(
    Type type,
    Map<Type, EntityDescriptor> index,
  ) {
    final descriptor = index[type];
    if (descriptor == null) {
      throw StateError('Missing entity descriptor for $type');
    }
    return descriptor;
  }

  String _quoteQualified(String qualifiedName) {
    if (!qualifiedName.contains('.')) {
      return '"$qualifiedName"';
    }
    return qualifiedName.split('.').map((part) => '"$part"').join('.');
  }
}

/// Generates Dart code for a Migration class based on the current schema diff.
class MigrationGenerator {
  final MigrationPlanner _planner;

  MigrationGenerator({MigrationPlanner? planner})
    : _planner = planner ?? MigrationPlanner();

  String generate({
    required int version,
    required List<EntityDescriptor> entities,
    required SchemaState current,
  }) {
    final plan = _planner.diff(entities: entities, current: current);
    final downStatements = _buildDownStatements(plan.statements);
    final className = 'Migration$version';
    final buffer = StringBuffer()
      ..writeln('class $className extends Migration {')
      ..writeln('  $className() : super($version);')
      ..writeln()
      ..writeln('  @override')
      ..writeln('  Future<void> up(EngineAdapter engine) async {');

    if (plan.isEmpty) {
      buffer.writeln('    // No schema changes detected.');
    } else {
      for (final stmt in plan.statements) {
        buffer.writeln("    await engine.execute('${_escapeSql(stmt)}');");
      }
    }

    buffer
      ..writeln('  }')
      ..writeln()
      ..writeln('  @override')
      ..writeln('  Future<void> down(EngineAdapter engine) async {')
      ..writeln(_renderDownBody(downStatements))
      ..writeln('  }')
      ..writeln('}');

    return buffer.toString();
  }

  String _escapeSql(String sql) => sql.replaceAll("'", "\\'");

  List<String> _buildDownStatements(List<String> upStatements) {
    final down = <String>[];
    for (final stmt in upStatements.reversed) {
      final createMatch = RegExp(
        r'^CREATE\s+TABLE\s+IF\s+NOT\s+EXISTS\s+([^\s]+)',
        caseSensitive: false,
      ).firstMatch(stmt);
      if (createMatch != null) {
        final table = createMatch.group(1)!;
        down.add('DROP TABLE IF EXISTS $table');
        continue;
      }

      final addColumnMatch = RegExp(
        r'^ALTER\s+TABLE\s+([^\s]+)\s+ADD\s+COLUMN\s+"([^"]+)"',
        caseSensitive: false,
      ).firstMatch(stmt);
      if (addColumnMatch != null) {
        final table = addColumnMatch.group(1)!;
        final column = addColumnMatch.group(2)!;
        down.add('ALTER TABLE $table DROP COLUMN "$column"');
        continue;
      }

      final addConstraintMatch = RegExp(
        r'^ALTER\s+TABLE\s+([^\s]+)\s+ADD\s+CONSTRAINT\s+"([^"]+)"',
        caseSensitive: false,
      ).firstMatch(stmt);
      if (addConstraintMatch != null) {
        final table = addConstraintMatch.group(1)!;
        final constraint = addConstraintMatch.group(2)!;
        down.add('ALTER TABLE $table DROP CONSTRAINT IF EXISTS "$constraint"');
        continue;
      }
    }
    return down;
  }

  String _renderDownBody(List<String> statements) {
    if (statements.isEmpty) {
      return '    // No rollback statements could be generated.';
    }
    final buffer = StringBuffer();
    for (final stmt in statements) {
      buffer.writeln("    await engine.execute('${_escapeSql(stmt)}');");
    }
    return buffer.toString().trimRight();
  }
}

class _JoinColumnSpec {
  const _JoinColumnSpec({
    required this.name,
    required this.type,
    required this.nullable,
    required this.unique,
    required this.referencesTable,
    required this.referencesColumn,
    required this.onDeleteCascade,
  });

  final String name;
  final ColumnType type;
  final bool nullable;
  final bool unique;
  final String referencesTable;
  final String referencesColumn;
  final bool onDeleteCascade;
}

class _JoinTableSpec {
  const _JoinTableSpec({required this.name, required this.columns});

  final String name;
  final List<_JoinColumnSpec> columns;
}

/// Represents a deferred foreign key constraint to be added after all tables exist.
class _DeferredForeignKey {
  const _DeferredForeignKey({
    required this.tableName,
    required this.columnName,
    required this.referencesTable,
    required this.referencesColumn,
    required this.onDeleteCascade,
  });

  final String tableName;
  final String columnName;
  final String referencesTable;
  final String referencesColumn;
  final bool onDeleteCascade;
}
