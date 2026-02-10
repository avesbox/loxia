import 'package:code_builder/code_builder.dart';
import 'package:loxia/src/generator/builders/builders.dart';

class RepositoryExtensionsBuilder {

  const RepositoryExtensionsBuilder();

  Extension build(EntityGenerationContext context) {
    final extensionName = '${context.entityName}RepositoryExtensions';

    return Extension(
      (e) => e
        ..name = extensionName
        ..on = refer('EntityRepository<${context.className}, PartialEntity<${context.className}>>')
        ..methods.addAll(context.queries.map((q) => _buildQueryMethod(q, context))),
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
    return hooks.any((h) => 
      h == 'prePersist' || h == 'postPersist' ||
      h == 'preUpdate' || h == 'postUpdate' ||
      h == 'preRemove' || h == 'postRemove'
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

      // Handle mutations (INSERT/UPDATE/DELETE)
      if (opType != _SqlOperationType.select) {
        _buildMutationMethod(m, query, context, opType, sqlParams, requiresEntity);
        return;
      }
      
      // Handle SELECT queries
      if (query.returnFullEntity) {
        m.returns = query.singleResult 
            ? refer('Future<${context.className}>') 
            : refer('Future<List<${context.className}>>');
        
        // Add parameters for SQL params
        for (final param in sqlParams) {
          final col = _findColumn(context, param);
          m.requiredParameters.add(Parameter((p) => p
            ..name = param
            ..type = refer(col?.dartTypeCode ?? 'Object?')));
        }
        
        final buffer = StringBuffer();
        final sqlWithPlaceholders = _replaceSqlParams(query.sql, sqlParams);
        buffer.writeln("final rows = await engine.query('$sqlWithPlaceholders', [${sqlParams.join(', ')}]);");
        
        if (query.singleResult) {
          buffer.writeln('final entity = descriptor.fromRow(rows.first);');
          if (hasPostLoad) {
            buffer.writeln('descriptor.hooks?.postLoad?.call(entity);');
          }
          buffer.writeln('return entity;');
        } else {
          buffer.writeln('final entities = rows.map((row) => descriptor.fromRow(row)).toList();');
          if (hasPostLoad) {
            buffer.writeln('for (final entity in entities) {');
            buffer.writeln('  descriptor.hooks?.postLoad?.call(entity);');
            buffer.writeln('}');
          }
          buffer.writeln('return entities;');
        }
        
        m.body = Code(buffer.toString());
      } else {
        m.returns = query.singleResult 
            ? refer('Future<${context.partialEntityName}>') 
            : refer('Future<List<${context.partialEntityName}>>');
        
        // Add parameters for SQL params
        for (final param in sqlParams) {
          final col = _findColumn(context, param);
          m.requiredParameters.add(Parameter((p) => p
            ..name = param
            ..type = refer(col?.dartTypeCode ?? 'Object?')));
        }
        
        final buffer = StringBuffer();
        final sqlWithPlaceholders = _replaceSqlParams(query.sql, sqlParams);
        buffer.writeln("final rows = await engine.query('$sqlWithPlaceholders', [${sqlParams.join(', ')}]);");
        
        if (query.singleResult) {
          buffer.writeln('return ${context.partialEntityName}.fromRow(rows.first);');
        } else {
          buffer.writeln('return rows.map((row) => ${context.partialEntityName}.fromRow(row)).toList();');
        }
        
        m.body = Code(buffer.toString());
      }
    });
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
      m.requiredParameters.add(Parameter((p) => p
        ..name = 'entity'
        ..type = refer(context.className)));
      
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
      buffer.writeln("await engine.query('$sqlWithPlaceholders', [$paramValues]);");
      
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
        m.requiredParameters.add(Parameter((p) => p
          ..name = param
          ..type = refer(col?.dartTypeCode ?? 'Object?')));
      }
      
      final sqlWithPlaceholders = _replaceSqlParams(query.sql, sqlParams);
      buffer.writeln("await engine.query('$sqlWithPlaceholders', [${sqlParams.join(', ')}]);");
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