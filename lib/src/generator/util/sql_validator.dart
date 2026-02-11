import 'package:sqlparser/sqlparser.dart';
import 'package:source_gen/source_gen.dart';

import '../../annotations/column.dart' show ColumnType;
import '../builders/models.dart';

/// Validates SQL queries at build time using sqlparser.
class SqlValidator {
  SqlValidator(this.context) {
    _engine = SqlEngine();
    _registerSchema();
  }

  final EntityGenerationContext context;
  late final SqlEngine _engine;

  /// Registers the entity's schema with the SQL engine.
  void _registerSchema() {
    final table = _createTable();
    _engine.registerTable(table);
  }

  /// Creates a sqlparser Table from the entity context.
  Table _createTable() {
    final columns = context.columns.map((col) {
      return TableColumn(
        col.name,
        _mapColumnType(col.type),
        isGenerated: col.autoIncrement,
      );
    }).toList();

    // Also add join columns for relations
    for (final rel in context.owningJoinColumns) {
      if (rel.joinColumn != null) {
        columns.add(
          TableColumn(
            rel.joinColumn!.name,
            _mapDartType(rel.joinColumnBaseDartType ?? 'int'),
          ),
        );
      }
    }

    return Table(name: context.tableName, resolvedColumns: columns);
  }

  /// Maps Loxia ColumnType to sqlparser ResolvedType.
  ResolvedType _mapColumnType(ColumnType type) {
    switch (type) {
      case ColumnType.integer:
        return const ResolvedType(type: BasicType.int);
      case ColumnType.doublePrecision:
        return const ResolvedType(type: BasicType.real);
      case ColumnType.text:
        return const ResolvedType(type: BasicType.text);
      case ColumnType.character:
        return const ResolvedType(type: BasicType.text);
      case ColumnType.varChar:
        return const ResolvedType(type: BasicType.text);
      case ColumnType.blob:
        return const ResolvedType(type: BasicType.blob);
      case ColumnType.binary:
        return const ResolvedType(type: BasicType.blob);
      case ColumnType.boolean:
        return const ResolvedType(
          type: BasicType.int,
        ); // SQLite stores bool as int
      case ColumnType.dateTime:
        return const ResolvedType(type: BasicType.text); // ISO string
      case ColumnType.timestamp:
        return const ResolvedType(type: BasicType.text); // ISO string
      case ColumnType.json:
        return const ResolvedType(type: BasicType.text); // JSON as text
      case ColumnType.uuid:
        return const ResolvedType(type: BasicType.text);
    }
  }

  /// Maps Dart type strings to sqlparser ResolvedType.
  ResolvedType _mapDartType(String dartType) {
    final baseType = dartType.replaceAll('?', '');
    switch (baseType) {
      case 'int':
        return const ResolvedType(type: BasicType.int);
      case 'double':
        return const ResolvedType(type: BasicType.real);
      case 'num':
        return const ResolvedType(type: BasicType.real);
      case 'bool':
        return const ResolvedType(type: BasicType.int);
      case 'String':
        return const ResolvedType(type: BasicType.text);
      case 'DateTime':
        return const ResolvedType(type: BasicType.text);
      default:
        return const ResolvedType(type: BasicType.text);
    }
  }

  /// Validates a SQL query and returns any errors.
  ///
  /// The [queryName] is used for error reporting.
  /// The [sql] is the raw SQL string to validate.
  ///
  /// Throws [InvalidGenerationSourceError] if the SQL is invalid.
  void validate(String queryName, String sql) {
    // Replace @param placeholders with :param for sqlparser's variable syntax
    final normalizedSql = _normalizeVariables(sql);

    final result = _engine.analyze(normalizedSql);

    if (result.errors.isNotEmpty) {
      final errorMessages = result.errors
          .map(
            (e) => '  - ${e.message} at ${e.span?.text ?? 'unknown location'}',
          )
          .join('\n');

      throw InvalidGenerationSourceError(
        'Invalid SQL in query "$queryName" on ${context.className}:\n$errorMessages\n\nSQL: $sql',
        todo: 'Fix the SQL syntax or column references',
      );
    }
  }

  /// Validates that SQL variables match method parameters.
  ///
  /// [sqlParams] are the parameter names extracted from the SQL.
  /// Returns a list of parameter names that don't match any column.
  List<String> validateVariables(String queryName, List<String> sqlParams) {
    final unknownParams = <String>[];

    for (final param in sqlParams) {
      final matchesColumn = context.columns.any((c) => c.prop == param);
      final matchesJoinColumn = context.owningJoinColumns.any(
        (r) => r.joinColumnPropertyName == param,
      );

      if (!matchesColumn && !matchesJoinColumn) {
        unknownParams.add(param);
      }
    }

    return unknownParams;
  }

  /// Normalizes @param to :param for sqlparser.
  String _normalizeVariables(String sql) {
    return sql.replaceAllMapped(
      RegExp(r'@(\w+)'),
      (match) => ':${match.group(1)}',
    );
  }
}
