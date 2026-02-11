import 'package:sqlparser/sqlparser.dart';
import 'package:source_gen/source_gen.dart';

import '../../annotations/column.dart' show ColumnType;
import '../builders/models.dart';

/// Represents a resolved column from SQL analysis.
class ResolvedQueryColumn {
  ResolvedQueryColumn({
    required this.name,
    required this.dartType,
    required this.nullable,
    this.originalColumnName,
  });

  /// The name of the column in the result (may be alias).
  final String name;

  /// The Dart type to use for this column.
  final String dartType;

  /// Whether the column is nullable.
  final bool nullable;

  /// The original column name if this is an alias.
  final String? originalColumnName;
}

/// Represents the result type analysis of a SQL query.
class QueryResultAnalysis {
  QueryResultAnalysis({
    required this.columns,
    required this.matchesEntity,
    required this.matchesPartialEntity,
    required this.hasJoins,
    required this.hasAggregates,
    required this.isSingleResult,
    required this.dtoClassName,
  });

  /// The resolved columns from the SELECT statement.
  final List<ResolvedQueryColumn> columns;

  /// Whether the columns exactly match the entity's columns.
  final bool matchesEntity;

  /// Whether the columns are a subset of the entity's columns (no aliases/expressions).
  final bool matchesPartialEntity;

  /// Whether the query contains JOINs.
  final bool hasJoins;

  /// Whether the query contains aggregate functions.
  final bool hasAggregates;

  /// Whether the query is guaranteed to return a single result.
  /// Detected by LIMIT 1 or aggregate functions without GROUP BY.
  final bool isSingleResult;

  /// The generated DTO class name if needed.
  final String dtoClassName;

  /// Returns true if a DTO class needs to be generated.
  bool get requiresDto => !matchesEntity && !matchesPartialEntity;
}

/// Analyzes SQL queries at build time using sqlparser.
///
/// This class extends basic validation to include:
/// - Schema registration for accurate column resolution
/// - SELECT column analysis
/// - Return type determination (Entity, PartialEntity, or generated DTO)
class SqlAnalyzer {
  SqlAnalyzer(this.context) {
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

  /// Validates and analyzes a SQL query.
  ///
  /// [queryName] is used for error reporting.
  /// [sql] is the raw SQL string to analyze.
  ///
  /// Throws [InvalidGenerationSourceError] if the SQL is invalid.
  QueryResultAnalysis analyze(String queryName, String sql) {
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

    // Analyze the parsed statement
    final stmt = result.root;

    if (stmt is SelectStatement) {
      return _analyzeSelectStatement(queryName, stmt, result);
    } else if (stmt is InsertStatement ||
        stmt is UpdateStatement ||
        stmt is DeleteStatement) {
      // For mutations, return a void result
      return QueryResultAnalysis(
        columns: [],
        matchesEntity: false,
        matchesPartialEntity: false,
        hasJoins: false,
        hasAggregates: false,
        isSingleResult: false,
        dtoClassName: '${_toPascalCase(queryName)}Result',
      );
    } else {
      throw InvalidGenerationSourceError(
        'Unsupported SQL statement type in query "$queryName" on ${context.className}.\n'
        'Only SELECT, INSERT, UPDATE, and DELETE statements are supported.',
        todo: 'Use one of the supported SQL statement types',
      );
    }
  }

  /// Analyzes a SELECT statement to determine result columns.
  QueryResultAnalysis _analyzeSelectStatement(
    String queryName,
    SelectStatement stmt,
    AnalysisContext result,
  ) {
    final hasJoins = stmt.from != null && _hasJoinClause(stmt.from!);
    final hasAggregates = _hasAggregateFunctions(stmt);
    final isSingleResult = _isSingleResultQuery(stmt, hasAggregates);

    // Check for SELECT *
    final isSelectAll =
        stmt.columns.length == 1 && stmt.columns.first is StarResultColumn;

    if (isSelectAll && !hasJoins && !hasAggregates) {
      // SELECT * FROM table - matches full entity
      return QueryResultAnalysis(
        columns: context.columns
            .map(
              (c) => ResolvedQueryColumn(
                name: c.prop,
                dartType: c.dartTypeCode,
                nullable: c.nullable,
                originalColumnName: c.name,
              ),
            )
            .toList(),
        matchesEntity: true,
        matchesPartialEntity: false,
        hasJoins: false,
        hasAggregates: false,
        isSingleResult: isSingleResult,
        dtoClassName: '${_toPascalCase(queryName)}Result',
      );
    }

    // Analyze individual columns
    final resolvedColumns = <ResolvedQueryColumn>[];
    final entityColumnNames = context.columns
        .map((c) => c.name.toLowerCase())
        .toSet();
    final entityPropNames = context.columns
        .map((c) => c.prop.toLowerCase())
        .toSet();
    var allMatchEntityColumns = true;

    for (final col in stmt.columns) {
      if (col is StarResultColumn) {
        // Star result - add all entity columns
        for (final entityCol in context.columns) {
          resolvedColumns.add(
            ResolvedQueryColumn(
              name: entityCol.prop,
              dartType: entityCol.dartTypeCode,
              nullable: entityCol.nullable,
              originalColumnName: entityCol.name,
            ),
          );
        }
      } else if (col is ExpressionResultColumn) {
        final resolved = _resolveExpressionColumn(col, result);
        resolvedColumns.add(resolved);

        // Check if this matches an entity column
        final name =
            resolved.originalColumnName?.toLowerCase() ??
            resolved.name.toLowerCase();
        if (!entityColumnNames.contains(name) &&
            !entityPropNames.contains(name)) {
          allMatchEntityColumns = false;
        }
      }
    }

    // Determine if columns match entity or partial
    final matchesEntity =
        allMatchEntityColumns &&
        !hasJoins &&
        !hasAggregates &&
        resolvedColumns.length == context.columns.length &&
        _columnsMatchEntity(resolvedColumns);

    final matchesPartialEntity =
        !matchesEntity && allMatchEntityColumns && !hasJoins && !hasAggregates;

    return QueryResultAnalysis(
      columns: resolvedColumns,
      matchesEntity: matchesEntity,
      matchesPartialEntity: matchesPartialEntity,
      hasJoins: hasJoins,
      hasAggregates: hasAggregates,
      isSingleResult: isSingleResult,
      dtoClassName: '${_toPascalCase(queryName)}Result',
    );
  }

  /// Resolves a single expression column to a query column.
  ResolvedQueryColumn _resolveExpressionColumn(
    ExpressionResultColumn col,
    AnalysisContext result,
  ) {
    final expression = col.expression;
    final alias = col.as;

    // Determine the column name
    String columnName;
    String? originalColumnName;

    if (alias != null) {
      columnName = alias;
      if (expression is Reference) {
        originalColumnName = expression.columnName;
      }
    } else if (expression is Reference) {
      columnName = expression.columnName;
      originalColumnName = expression.columnName;
    } else if (expression is FunctionExpression) {
      // For functions like COUNT(*), use the function name as column name
      columnName = _generateFunctionColumnName(expression);
    } else {
      // Fallback: use a generated name
      columnName = 'column${col.hashCode}';
    }

    // Determine the type and nullability
    String dartType;
    bool nullable;

    if (expression is Reference) {
      // Try to find the column in the entity
      final entityCol = _findEntityColumnByName(expression.columnName);
      if (entityCol != null) {
        dartType = entityCol.dartTypeCode;
        nullable = entityCol.nullable;
        columnName = _toCamelCase(columnName);
      } else {
        // Use the resolved type from sqlparser
        dartType = _resolveExpressionType(expression, result);
        // Derive nullable from the type string
        nullable = dartType.endsWith('?');
      }
    } else {
      dartType = _resolveExpressionType(expression, result);
      // Derive nullable from the type string
      nullable = dartType.endsWith('?');
    }

    return ResolvedQueryColumn(
      name: _toCamelCase(columnName),
      dartType: dartType,
      nullable: nullable,
      originalColumnName: originalColumnName,
    );
  }

  /// Generates a column name for aggregate functions.
  String _generateFunctionColumnName(FunctionExpression expr) {
    final name = expr.name.toLowerCase();
    if (expr.parameters is ExprFunctionParameters) {
      final params = expr.parameters as ExprFunctionParameters;
      if (params.parameters.isNotEmpty) {
        final firstParam = params.parameters.first;
        if (firstParam is Reference) {
          return '$name${_toPascalCase(firstParam.columnName)}';
        } else if (firstParam is StarFunctionParameter) {
          return '${name}All';
        }
      }
    }
    return name;
  }

  /// Resolves the Dart type for an expression.
  String _resolveExpressionType(Expression expr, AnalysisContext result) {
    // Fallback based on expression type
    if (expr is FunctionExpression) {
      return _inferFunctionType(expr);
    }

    // For references, try to find the column in our schema
    if (expr is Reference) {
      final entityCol = _findEntityColumnByName(expr.columnName);
      if (entityCol != null) {
        return entityCol.dartTypeCode;
      }
    }

    // Default to Object?
    return 'Object?';
  }

  /// Infers the return type of common SQL functions.
  String _inferFunctionType(FunctionExpression expr) {
    switch (expr.name.toUpperCase()) {
      case 'COUNT':
        return 'int';
      case 'SUM':
      case 'AVG':
        return 'double?';
      case 'MIN':
      case 'MAX':
        // Type depends on the argument, default to Object?
        return 'Object?';
      case 'LENGTH':
      case 'CHAR_LENGTH':
        return 'int';
      case 'UPPER':
      case 'LOWER':
      case 'TRIM':
      case 'LTRIM':
      case 'RTRIM':
      case 'SUBSTR':
      case 'SUBSTRING':
      case 'CONCAT':
      case 'GROUP_CONCAT':
        return 'String?';
      case 'ABS':
      case 'ROUND':
        return 'num?';
      case 'COALESCE':
      case 'IFNULL':
      case 'NULLIF':
        // Type depends on arguments
        return 'Object?';
      default:
        return 'Object?';
    }
  }

  /// Checks if a FROM clause contains JOIN statements.
  bool _hasJoinClause(Queryable from) {
    if (from is JoinClause) {
      return true;
    }
    return false;
  }

  /// Checks if a SELECT statement contains aggregate functions.
  bool _hasAggregateFunctions(SelectStatement stmt) {
    for (final col in stmt.columns) {
      if (col is ExpressionResultColumn) {
        if (_isAggregate(col.expression)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Determines if a SELECT statement returns a single result.
  ///
  /// Returns true if:
  /// - The query has LIMIT 1
  /// - The query has aggregate functions without GROUP BY (e.g., COUNT(*))
  bool _isSingleResultQuery(SelectStatement stmt, bool hasAggregates) {
    // Check for LIMIT 1
    final limit = stmt.limit;
    if (limit != null && limit is Limit) {
      final limitExpr = limit.count;
      if (limitExpr is NumericLiteral && limitExpr.value == 1) {
        return true;
      }
    }

    // Aggregates without GROUP BY return a single row
    if (hasAggregates && stmt.groupBy == null) {
      return true;
    }

    return false;
  }

  /// Checks if an expression is an aggregate function.
  bool _isAggregate(Expression expr) {
    if (expr is FunctionExpression) {
      final name = expr.name.toUpperCase();
      return const [
        'COUNT',
        'SUM',
        'AVG',
        'MIN',
        'MAX',
        'GROUP_CONCAT',
        'TOTAL',
      ].contains(name);
    }
    return false;
  }

  /// Finds an entity column by SQL column name.
  GenColumn? _findEntityColumnByName(String columnName) {
    final lower = columnName.toLowerCase();
    for (final col in context.columns) {
      if (col.name.toLowerCase() == lower || col.prop.toLowerCase() == lower) {
        return col;
      }
    }
    return null;
  }

  /// Checks if resolved columns match the entity columns exactly.
  bool _columnsMatchEntity(List<ResolvedQueryColumn> resolved) {
    if (resolved.length != context.columns.length) return false;

    final entityNames = context.columns
        .map((c) => c.prop.toLowerCase())
        .toSet();
    for (final col in resolved) {
      if (!entityNames.contains(col.name.toLowerCase())) {
        return false;
      }
    }
    return true;
  }

  /// Validates that SQL variables match valid parameter names.
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

  /// Converts snake_case to camelCase.
  String _toCamelCase(String input) {
    if (input.isEmpty) return input;

    final parts = input.split('_');
    if (parts.length == 1) {
      return input[0].toLowerCase() + input.substring(1);
    }

    final buffer = StringBuffer(parts.first.toLowerCase());
    for (var i = 1; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        buffer.write(parts[i][0].toUpperCase());
        buffer.write(parts[i].substring(1).toLowerCase());
      }
    }
    return buffer.toString();
  }

  /// Converts a string to PascalCase.
  String _toPascalCase(String input) {
    if (input.isEmpty) return input;

    // Handle snake_case
    if (input.contains('_')) {
      return input.split('_').map((part) {
        if (part.isEmpty) return '';
        return part[0].toUpperCase() + part.substring(1).toLowerCase();
      }).join();
    }

    // Already camelCase or PascalCase
    return input[0].toUpperCase() + input.substring(1);
  }
}
