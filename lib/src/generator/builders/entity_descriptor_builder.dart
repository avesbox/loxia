/// Builder for generating the EntityDescriptor top-level variable.
library;

import 'package:code_builder/code_builder.dart';

import '../../annotations/column.dart';
import 'column_builder.dart';
import 'models.dart';
import 'relation_builder.dart';

/// Builds the EntityDescriptor top-level final variable for an entity.
class EntityDescriptorBuilder {
  const EntityDescriptorBuilder();

  final _columnBuilder = const ColumnDescriptorBuilder();
  final _relationBuilder = const RelationDescriptorBuilder();

  /// Builds the EntityDescriptor field declaration.
  Field build(EntityGenerationContext context) {
    return Field(
      (b) => b
        ..name = context.descriptorVarName
        ..modifier = FieldModifier.final$
        ..type = TypeReference(
          (t) => t
            ..symbol = 'EntityDescriptor'
            ..types.addAll([
              refer(context.entityName),
              refer(context.partialEntityName),
            ]),
        )
        ..assignment = _buildDescriptorInstance(context).code,
    );
  }

  Expression _buildDescriptorInstance(EntityGenerationContext context) {
    final entityName = context.entityName;
    final repoName = '${entityName}Repository';
    return refer('EntityDescriptor').newInstance([], {
      'entityType': refer(context.entityName),
      'tableName': literalString(context.tableName),
      if (context.schema != null) 'schema': literalString(context.schema!),
      'columns': _columnBuilder.buildList(context.columns),
      'relations': _relationBuilder.buildConstList(context.relations),
      'fromRow': _buildFromRow(context),
      'toRow': _buildToRow(context),
      'fieldsContext': refer(context.fieldsContextName).constInstance([]),
      'repositoryFactory': Method(
        (m) => m
          ..requiredParameters.add(
            Parameter(
              (p) => p
                ..name = 'engine'
                ..type = refer('EngineAdapter'),
            ),
          )
          ..body = refer(repoName).newInstance([refer('engine')]).code
          ..lambda = true,
      ).closure,
      if (_hasHooks(context)) 'hooks': _buildHooks(context),
      'defaultSelect': Method(
        (m) => m
          ..body = refer('${context.entityName}Select').newInstance([]).code
          ..lambda = true,
      ).closure,
    });
  }

  bool _hasHooks(EntityGenerationContext context) {
    return context.hooks.isNotEmpty ||
        context.createdAtFields.isNotEmpty ||
        context.updatedAtFields.isNotEmpty;
  }

  Expression _buildHooks(EntityGenerationContext context) {
    final args = <String, Expression>{};
    final hookNames = <String>{
      ...context.hooks.keys,
      if (context.createdAtFields.isNotEmpty ||
          context.updatedAtFields.isNotEmpty)
        'prePersist',
      if (context.updatedAtFields.isNotEmpty) 'preUpdate',
    };

    for (final hookName in hookNames) {
      final statements = _buildHookStatements(context, hookName);
      if (statements.isEmpty) continue;
      args[hookName] = _buildHookClosure(statements);
    }
    final hooksType = TypeReference(
      (t) => t
        ..symbol = 'EntityHooks'
        ..types.add(refer(context.entityName)),
    );
    return hooksType.newInstance([], args);
  }

  List<String> _buildHookStatements(
    EntityGenerationContext context,
    String hookName,
  ) {
    final statements = <String>[];

    if (hookName == 'prePersist') {
      for (final field in context.createdAtFields) {
        statements.add('e.${field.fieldName} = ${field.valueExpression};');
      }
      for (final field in context.updatedAtFields) {
        statements.add('e.${field.fieldName} = ${field.valueExpression};');
      }
    }

    if (hookName == 'preUpdate') {
      for (final field in context.updatedAtFields) {
        statements.add('e.${field.fieldName} = ${field.valueExpression};');
      }
    }

    final methods = context.hooks[hookName] ?? const [];
    for (final method in methods) {
      statements.add('e.$method();');
    }

    return statements;
  }

  Expression _buildHookClosure(List<String> statements) {
    return Method((m) {
      m.requiredParameters.add(Parameter((p) => p..name = 'e'));
      m.body = Block((b) {
        for (final statement in statements) {
          b.statements.add(Code(statement));
        }
      });
    }).closure;
  }

  Expression _buildFromRow(EntityGenerationContext context) {
    final assignments = <String, Expression>{};

    // Add column assignments
    for (final c in context.columns) {
      assignments[c.prop] = _fromRowAccessor(c);
    }

    // Add relation constructor literals
    for (final r in context.relations) {
      if (r.constructorLiteral != null) {
        assignments[r.fieldName] = CodeExpression(Code(r.constructorLiteral!));
      }
    }

    return Method(
      (m) => m
        ..requiredParameters.add(Parameter((p) => p..name = 'row'))
        ..body = refer(context.entityName).newInstance([], assignments).code
        ..lambda = true,
    ).closure;
  }

  Expression _fromRowAccessor(GenColumn c) {
    final col = refer('row').index(literalString(c.name));
    final baseType = c.dartTypeCode.replaceAll('?', '');
    final isNullable = c.dartTypeCode.endsWith('?');

    if (c.dartTypeCode == 'bool') {
      return col.equalTo(literalNum(1));
    }

    if (c.isEnum) {
      final source = "row['${c.name}']";
      final enumType = c.enumTypeName ?? c.dartTypeCode;
      final expr = c.type == ColumnType.text
          ? '$enumType.values.byName($source as String)'
          : '$enumType.values[$source as int]';
      final wrapped = c.nullable ? '$source == null ? null : $expr' : expr;
      return CodeExpression(Code(wrapped));
    }

    if (c.isCreatedAt || c.isUpdatedAt) {
      switch (baseType) {
        case 'int':
          final expr = col
              .asA(refer('DateTime'))
              .property('millisecondsSinceEpoch');
          return isNullable
              ? col.nullSafeProperty('millisecondsSinceEpoch')
              : expr;
        case 'double':
          final expr = col
              .asA(refer('DateTime'))
              .property('millisecondsSinceEpoch')
              .property('toDouble')
              .call([]);
          return isNullable
              ? col
                    .nullSafeProperty('millisecondsSinceEpoch')
                    .nullSafeProperty('toDouble')
                    .call([])
              : expr;
        case 'String':
          final expr = col
              .asA(refer('DateTime'))
              .property('toIso8601String')
              .call([]);
          return isNullable
              ? col.nullSafeProperty('toIso8601String').call([])
              : expr;
        default:
          return col.asA(refer(c.dartTypeCode));
      }
    }

    return col.asA(refer(c.dartTypeCode));
  }

  Expression _buildToRow(EntityGenerationContext context) {
    final entries = <Expression, Expression>{};

    // Add column entries
    for (final c in context.columns) {
      entries[literalString(c.name)] = _toRowValue(c);
    }

    // Add owning join column entries
    for (final relation in context.owningJoinColumns) {
      final accessor = relation.targetPrimaryFieldName == null
          ? literalNull
          : refer('e')
                .property(relation.fieldName)
                .nullSafeProperty(relation.targetPrimaryFieldName!);
      entries[literalString(relation.joinColumn!.name)] = accessor;
    }

    return Method(
      (m) => m
        ..requiredParameters.add(Parameter((p) => p..name = 'e'))
        ..body = literalMap(entries).code
        ..lambda = true,
    ).closure;
  }

  Expression _toRowValue(GenColumn c) {
    final value = refer('e').property(c.prop);
    final baseType = c.dartTypeCode.replaceAll('?', '');

    if (c.isEnum) {
      final source = 'e.${c.prop}';
      final expr = c.type == ColumnType.text
          ? (c.nullable ? '$source?.name' : '$source.name')
          : (c.nullable ? '$source?.index' : '$source.index');
      return CodeExpression(Code(expr));
    }

    if (!c.isCreatedAt && !c.isUpdatedAt) {
      return value;
    }

    switch (baseType) {
      case 'int':
        return value
            .equalTo(literalNull)
            .conditional(
              literalNull,
              refer('DateTime').property('fromMillisecondsSinceEpoch').call([
                value.asA(refer('int')),
              ]),
            );
      case 'double':
        return value
            .equalTo(literalNull)
            .conditional(
              literalNull,
              refer('DateTime').property('fromMillisecondsSinceEpoch').call([
                value.property('toInt').call([]),
              ]),
            );
      case 'String':
        return value
            .equalTo(literalNull)
            .conditional(
              literalNull,
              refer(
                'DateTime',
              ).property('parse').call([value.asA(refer('String'))]),
            );
      default:
        return value;
    }
  }
}
