import 'package:code_builder/code_builder.dart';
import 'package:loxia/src/generator/builders/builders.dart';

class RepositoryExtensionsBuilder {
  const RepositoryExtensionsBuilder();

  static final RegExp _sqlParamPattern = RegExp(r'@(\w+)');

  Extension build(EntityGenerationContext context) {
    final extensionName = '${context.entityName}RepositoryExtensions';

    return Extension(
      (e) => e
        ..name = extensionName
        ..on = refer(
          'EntityRepository<${context.className}, PartialEntity<${context.className}>>',
        )
        ..methods.addAll(
          context.queries.map((q) => _buildQueryMethod(q, context)),
        ),
    );
  }

  /// Detects the SQL operation type from the query.
  _SqlOperationType _detectOperationType(String sql) {
    final trimmed = sql.trim().toUpperCase();
    if (trimmed.startsWith('INSERT')) return _SqlOperationType.insert;
    if (trimmed.startsWith('UPDATE')) return _SqlOperationType.update;
    if (trimmed.startsWith('DELETE')) return _SqlOperationType.delete;
    return _SqlOperationType.select;
  }

  /// Extracts parameter names from SQL (e.g., @id, @name -> ['id', 'name'])
  List<String> _extractSqlParams(String sql) {
    return _sqlParamPattern.allMatches(sql).map((m) => m.group(1)!).toList();
  }

  /// Extracts unique parameter names preserving their first appearance order.
  List<String> _extractUniqueSqlParams(String sql) {
    final ordered = <String>[];
    final seen = <String>{};

    for (final param in _extractSqlParams(sql)) {
      if (seen.add(param)) {
        ordered.add(param);
      }
    }

    return ordered;
  }

  /// Checks if the hooks indicate an entity is needed for mutations.
  bool _requiresEntityForMutation(List<String> hooks) {
    return hooks.any(
      (h) =>
          h == 'prePersist' ||
          h == 'postPersist' ||
          h == 'preUpdate' ||
          h == 'postUpdate' ||
          h == 'preRemove' ||
          h == 'postRemove',
    );
  }

  Method _buildQueryMethod(GenQuery query, EntityGenerationContext context) {
    return Method((m) {
      m
        ..name = query.name
        ..modifier = MethodModifier.async;

      final opType = _detectOperationType(query.sql);
      final sqlParams = _extractSqlParams(query.sql);
      final uniqueSqlParams = _extractUniqueSqlParams(query.sql);
      final hasPostLoad = query.lifecycleHooks.contains('postLoad');
      final requiresEntity = _requiresEntityForMutation(query.lifecycleHooks);
      final analysis = query.analysisResult;

      // Handle mutations (INSERT/UPDATE/DELETE)
      if (opType != _SqlOperationType.select) {
        _buildMutationMethod(
          m,
          query,
          context,
          opType,
          uniqueSqlParams,
          sqlParams,
          requiresEntity,
        );
        return;
      }

      // Use analysis to determine single result - defaults to false if no analysis
      final isSingleResult = analysis?.isSingleResult ?? false;

      // Determine return type based on analysis
      final returnType = _determineReturnType(
        context,
        analysis,
        isSingleResult,
      );
      m.returns = refer(returnType);

      // Add parameters for SQL params
      for (final param in uniqueSqlParams) {
        m.requiredParameters.add(
          Parameter(
            (p) => p
              ..name = param
              ..type = refer(_parameterTypeCode(context, param, analysis)),
          ),
        );
      }

      // Build method body based on return type
      final buffer = StringBuffer();
      final sqlWithPlaceholders = _replaceSqlParams(query.sql);
      buffer.writeln(
        "final rows = await engine.query('$sqlWithPlaceholders', [${_buildArgumentList(sqlParams)}]);",
      );

      if (analysis != null && analysis.matchesEntity) {
        // Return full entity
        _buildEntityReturnBody(buffer, isSingleResult, hasPostLoad);
      } else if (analysis != null && analysis.matchesPartialEntity) {
        // Return partial entity
        _buildPartialEntityReturnBody(buffer, isSingleResult, context);
      } else if (analysis != null && analysis.requiresDto) {
        // Return generated DTO
        _buildDtoReturnBody(buffer, isSingleResult, analysis);
      } else {
        // Fallback to partial entity behavior
        _buildPartialEntityReturnBody(buffer, isSingleResult, context);
      }

      m.body = Code(buffer.toString());
    });
  }

  /// Determines the return type string for a SELECT query.
  String _determineReturnType(
    EntityGenerationContext context,
    GenQueryAnalysisResult? analysis,
    bool isSingleResult,
  ) {
    final entityName = context.className;

    if (analysis != null && analysis.matchesEntity) {
      // Full entity return
      return isSingleResult
          ? 'Future<$entityName>'
          : 'Future<List<$entityName>>';
    } else if (analysis != null && analysis.matchesPartialEntity) {
      // Partial entity return
      return isSingleResult
          ? 'Future<PartialEntity<$entityName>>'
          : 'Future<List<PartialEntity<$entityName>>>';
    } else if (analysis != null && analysis.requiresDto) {
      // Generated DTO return
      return isSingleResult
          ? 'Future<${analysis.dtoClassName}>'
          : 'Future<List<${analysis.dtoClassName}>>';
    } else {
      // Default to partial entity
      return isSingleResult
          ? 'Future<PartialEntity<$entityName>>'
          : 'Future<List<PartialEntity<$entityName>>>';
    }
  }

  /// Builds method body for full entity returns.
  void _buildEntityReturnBody(
    StringBuffer buffer,
    bool isSingleResult,
    bool hasPostLoad,
  ) {
    if (isSingleResult) {
      buffer.writeln('final entity = descriptor.fromRow(rows.first);');
      if (hasPostLoad) {
        buffer.writeln('descriptor.hooks?.postLoad?.call(entity);');
      }
      buffer.writeln('return entity;');
    } else {
      buffer.writeln(
        'final entities = rows.map((row) => descriptor.fromRow(row)).toList();',
      );
      if (hasPostLoad) {
        buffer.writeln('for (final entity in entities) {');
        buffer.writeln('  descriptor.hooks?.postLoad?.call(entity);');
        buffer.writeln('}');
      }
      buffer.writeln('return entities;');
    }
  }

  /// Builds method body for partial entity returns.
  void _buildPartialEntityReturnBody(
    StringBuffer buffer,
    bool isSingleResult,
    EntityGenerationContext context,
  ) {
    buffer.writeln('final selectOpts = ${context.selectClassName}();');

    if (isSingleResult) {
      buffer.writeln('return selectOpts.hydrate(rows.first);');
    } else {
      buffer.writeln(
        'return rows.map((row) => selectOpts.hydrate(row)).toList();',
      );
    }
  }

  /// Builds method body for generated DTO returns.
  void _buildDtoReturnBody(
    StringBuffer buffer,
    bool isSingleResult,
    GenQueryAnalysisResult analysis,
  ) {
    final dtoName = analysis.dtoClassName;

    if (isSingleResult) {
      buffer.writeln('return $dtoName.fromMap(rows.first);');
    } else {
      buffer.writeln(
        'return rows.map((row) => $dtoName.fromMap(row)).toList();',
      );
    }
  }

  void _buildMutationMethod(
    MethodBuilder m,
    GenQuery query,
    EntityGenerationContext context,
    _SqlOperationType opType,
    List<String> uniqueSqlParams,
    List<String> sqlParams,
    bool requiresEntity,
  ) {
    final hooks = query.lifecycleHooks;
    m.returns = refer('Future<void>');

    final buffer = StringBuffer();

    if (requiresEntity) {
      // Accept entity as parameter, extract values from it
      m.requiredParameters.add(
        Parameter(
          (p) => p
            ..name = 'entity'
            ..type = refer(context.className),
        ),
      );

      for (final param in uniqueSqlParams) {
        if (_isEntityBackedParam(context, param)) continue;
        m.requiredParameters.add(
          Parameter(
            (p) => p
              ..name = param
              ..type = refer(
                _parameterTypeCode(context, param, query.analysisResult),
              ),
          ),
        );
      }
      // Pre-hooks
      if (opType == _SqlOperationType.insert) {
        if (hooks.contains('prePersist')) {
          buffer.writeln('descriptor.hooks?.prePersist?.call(entity);');
        }
      } else if (opType == _SqlOperationType.update) {
        if (hooks.contains('preUpdate')) {
          buffer.writeln('descriptor.hooks?.preUpdate?.call(entity);');
        }
      } else if (opType == _SqlOperationType.delete) {
        if (hooks.contains('preRemove')) {
          buffer.writeln('descriptor.hooks?.preRemove?.call(entity);');
        }
      }

      // Build params list from entity properties
      final paramValues = sqlParams
          .map(
            (p) => _parameterValueExpression(context, p, requiresEntity: true),
          )
          .join(', ');
      final sqlWithPlaceholders = _replaceSqlParams(query.sql);
      buffer.writeln(
        "await engine.query('$sqlWithPlaceholders', [$paramValues]);",
      );

      // Post-hooks
      if (opType == _SqlOperationType.insert) {
        if (hooks.contains('postPersist')) {
          buffer.writeln('descriptor.hooks?.postPersist?.call(entity);');
        }
      } else if (opType == _SqlOperationType.update) {
        if (hooks.contains('postUpdate')) {
          buffer.writeln('descriptor.hooks?.postUpdate?.call(entity);');
        }
      } else if (opType == _SqlOperationType.delete) {
        if (hooks.contains('postRemove')) {
          buffer.writeln('descriptor.hooks?.postRemove?.call(entity);');
        }
      }
    } else {
      // Accept individual parameters
      for (final param in uniqueSqlParams) {
        m.requiredParameters.add(
          Parameter(
            (p) => p
              ..name = param
              ..type = refer(
                _parameterTypeCode(context, param, query.analysisResult),
              ),
          ),
        );
      }

      final sqlWithPlaceholders = _replaceSqlParams(query.sql);
      buffer.writeln(
        "await engine.query('$sqlWithPlaceholders', [${_buildArgumentList(sqlParams)}]);",
      );
    }

    m.body = Code(buffer.toString());
  }

  /// Replaces @param with ? placeholders for prepared statements.
  String _replaceSqlParams(String sql) {
    return sql.replaceAllMapped(_sqlParamPattern, (_) => '?');
  }

  /// Finds a column by property name.
  GenColumn? _findColumn(EntityGenerationContext context, String propName) {
    for (final col in context.columns) {
      if (col.prop == propName) return col;
    }
    return null;
  }

  GenRelation? _findJoinRelation(
    EntityGenerationContext context,
    String propName,
  ) {
    for (final relation in context.owningJoinColumns) {
      if (relation.joinColumnPropertyName == propName) return relation;
    }
    return null;
  }

  bool _isEntityBackedParam(EntityGenerationContext context, String paramName) {
    return _findColumn(context, paramName) != null ||
        _findJoinRelation(context, paramName) != null;
  }

  String _parameterTypeCode(
    EntityGenerationContext context,
    String paramName,
    GenQueryAnalysisResult? analysis,
  ) {
    final column = _findColumn(context, paramName);
    if (column != null) return column.dartTypeCode;

    final relation = _findJoinRelation(context, paramName);
    if (relation?.joinColumnBaseDartType case final baseType?) {
      final nullable = relation?.joinColumnNullable ?? true;
      return nullable && !baseType.endsWith('?') ? '$baseType?' : baseType;
    }

    final inferredType = analysis?.variableTypes[paramName];
    if (inferredType != null) return inferredType;

    return 'Object?';
  }

  String _parameterValueExpression(
    EntityGenerationContext context,
    String paramName, {
    required bool requiresEntity,
  }) {
    if (requiresEntity && _isEntityBackedParam(context, paramName)) {
      return 'entity.$paramName';
    }
    return paramName;
  }

  String _buildArgumentList(List<String> sqlParams) => sqlParams.join(', ');
}

enum _SqlOperationType { select, insert, update, delete }
