import 'package:code_builder/code_builder.dart';
import 'package:loxia/src/generator/builders/builders.dart';

class RepositoryExtensionsBuilder {
  const RepositoryExtensionsBuilder();

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
    final regex = RegExp(r'@(\w+)');
    return regex.allMatches(sql).map((m) => m.group(1)!).toList();
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
      for (final param in sqlParams) {
        final col = _findColumn(context, param);
        m.requiredParameters.add(
          Parameter(
            (p) => p
              ..name = param
              ..type = refer(col?.dartTypeCode ?? 'Object?'),
          ),
        );
      }

      // Build method body based on return type
      final buffer = StringBuffer();
      final sqlWithPlaceholders = _replaceSqlParams(query.sql, sqlParams);
      buffer.writeln(
        "final rows = await engine.query('$sqlWithPlaceholders', [${sqlParams.join(', ')}]);",
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
      final paramValues = sqlParams.map((p) => 'entity.$p').join(', ');
      final sqlWithPlaceholders = _replaceSqlParams(query.sql, sqlParams);
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
      for (final param in sqlParams) {
        final col = _findColumn(context, param);
        m.requiredParameters.add(
          Parameter(
            (p) => p
              ..name = param
              ..type = refer(col?.dartTypeCode ?? 'Object?'),
          ),
        );
      }

      final sqlWithPlaceholders = _replaceSqlParams(query.sql, sqlParams);
      buffer.writeln(
        "await engine.query('$sqlWithPlaceholders', [${sqlParams.join(', ')}]);",
      );
    }

    m.body = Code(buffer.toString());
  }

  /// Replaces @param with ? placeholders for prepared statements.
  String _replaceSqlParams(String sql, List<String> params) {
    var result = sql;
    for (final param in params) {
      result = result.replaceAll('@$param', '?');
    }
    return result;
  }

  /// Finds a column by property name.
  GenColumn? _findColumn(EntityGenerationContext context, String propName) {
    for (final col in context.columns) {
      if (col.prop == propName) return col;
    }
    return null;
  }
}

enum _SqlOperationType { select, insert, update, delete }
