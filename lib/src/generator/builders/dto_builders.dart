/// Builders for generating InsertDto and UpdateDto classes.
library;

import 'package:code_builder/code_builder.dart';

import '../../annotations/column.dart';
import 'models.dart';

/// Builds the InsertDto class for an entity.
class InsertDtoBuilder {
  const InsertDtoBuilder();

  /// Builds the complete InsertDto class.
  Class build(EntityGenerationContext context) {
    final insertableColumns = context.columns
        .where((c) => !c.autoIncrement && !c.isPk)
        .toList();
    final cascadeRelations = context.relations
        .where((r) => r.cascadePersist)
        .toList();

    return Class(
      (c) => c
        ..name = context.insertDtoName
        ..implements.add(
          TypeReference(
            (t) => t
              ..symbol = 'InsertDto'
              ..types.add(refer(context.entityName)),
          ),
        )
        ..constructors.add(
          _buildConstructor(context, insertableColumns, cascadeRelations),
        )
        ..fields.addAll(_buildColumnFields(insertableColumns))
        ..fields.addAll(_buildJoinColumnFields(context))
        ..fields.addAll(_buildCascadeFields(cascadeRelations))
        ..methods.add(_buildToMapMethod(context, insertableColumns))
        ..methods.add(_buildCascadesGetter(cascadeRelations))
        ..methods.add(
          _buildCopyWithMethod(context, insertableColumns, cascadeRelations),
        ),
    );
  }

  Constructor _buildConstructor(
    EntityGenerationContext context,
    List<GenColumn> columns,
    List<GenRelation> cascades,
  ) {
    final params = <Parameter>[];

    for (final c in columns) {
      final isTimestampManaged = c.isCreatedAt || c.isUpdatedAt || c.isDeletedAt;
      params.add(
        Parameter(
          (p) => p
            ..name = c.prop
            ..named = true
            ..toThis = true
            ..required =
                !isTimestampManaged && !c.nullable && c.defaultLiteral == null
            ..defaultTo = c.defaultLiteral != null
                ? Code(c.defaultLiteral!)
                : null,
        ),
      );
    }

    for (final relation in context.owningJoinColumns) {
      params.add(
        Parameter(
          (p) => p
            ..name = relation.joinColumnPropertyName!
            ..named = true
            ..toThis = true
            ..required = !relation.joinColumnNullable,
        ),
      );
    }

    for (final relation in cascades) {
      params.add(
        Parameter(
          (p) => p
            ..name = relation.fieldName
            ..named = true
            ..toThis = true,
        ),
      );
    }

    return Constructor(
      (c) => c
        ..constant = true
        ..optionalParameters.addAll(params),
    );
  }

  Iterable<Field> _buildColumnFields(List<GenColumn> columns) {
    return columns.map(
      (c) => Field(
        (f) => f
          ..name = c.prop
          ..modifier = FieldModifier.final$
          ..type = refer(
            (c.nullable || c.isCreatedAt || c.isUpdatedAt || c.isDeletedAt)
                ? _nullableType(c.dartTypeCode)
                : c.dartTypeCode,
          ),
      ),
    );
  }

  Iterable<Field> _buildJoinColumnFields(EntityGenerationContext context) {
    return context.owningJoinColumns.map((relation) {
      final joinType = relation.joinColumnBaseDartType!;
      final typeWithNull = relation.joinColumnNullable
          ? '$joinType?'
          : joinType;
      return Field(
        (f) => f
          ..name = relation.joinColumnPropertyName!
          ..modifier = FieldModifier.final$
          ..type = refer(typeWithNull),
      );
    });
  }

  Iterable<Field> _buildCascadeFields(List<GenRelation> relations) {
    return relations.map((relation) {
      final targetDto = '${relation.targetTypeCode}InsertDto';
      final type = relation.isCollection ? 'List<$targetDto>?' : '$targetDto?';
      return Field(
        (f) => f
          ..name = relation.fieldName
          ..modifier = FieldModifier.final$
          ..type = refer(type),
      );
    });
  }

  Method _buildToMapMethod(
    EntityGenerationContext context,
    List<GenColumn> columns,
  ) {
    final createdAtExpr = {
      for (final f in context.createdAtFields) f.fieldName: f.valueExpression,
    };
    final updatedAtExpr = {
      for (final f in context.updatedAtFields) f.fieldName: f.valueExpression,
    };

    final deletedAtExpr = {
      for (final f in context.deletedAtFields) f.fieldName: f.valueExpression,
    };

    final entries = <String>[];

    for (final c in columns) {
      final timestampExpr = createdAtExpr[c.prop] ?? updatedAtExpr[c.prop] ?? deletedAtExpr[c.prop];
      var valueExpr = timestampExpr != null
          ? _timestampLiteralToDateTime(c, timestampExpr)
          : _timestampPropToDateTime(c, c.prop);
      valueExpr = _enumToStorage(c, valueExpr);
      entries.add("'${c.name}': $valueExpr");
    }

    for (final relation in context.owningJoinColumns) {
      final prop = relation.joinColumnPropertyName;
      if (relation.joinColumnNullable) {
        entries.add("if($prop != null) '${relation.joinColumn!.name}': $prop");
      } else {
        entries.add("'${relation.joinColumn!.name}': $prop");
      }
    }

    return Method(
      (m) => m
        ..annotations.add(refer('override'))
        ..name = 'toMap'
        ..returns = refer('Map<String, dynamic>')
        ..body = Code('return {${entries.join(', ')}};')
        ..lambda = false,
    );
  }

  Method _buildCascadesGetter(List<GenRelation> relations) {
    final entries = <String>[];
    for (final relation in relations) {
      entries.add(
        "if(${relation.fieldName} != null) '${relation.fieldName}': ${relation.fieldName}",
      );
    }
    final body = entries.isEmpty
        ? 'return const {};'
        : 'return {${entries.join(', ')}};';
    return Method(
      (m) => m
        ..name = 'cascades'
        ..type = MethodType.getter
        ..returns = refer('Map<String, dynamic>')
        ..body = Code(body),
    );
  }

  Method _buildCopyWithMethod(
    EntityGenerationContext context,
    List<GenColumn> columns,
    List<GenRelation> cascades,
  ) {
    final params = <Parameter>[];

    for (final c in columns) {
      final nullableType = _nullableType(c.dartTypeCode);
      params.add(
        Parameter(
          (p) => p
            ..name = c.prop
            ..named = true
            ..type = refer(nullableType),
        ),
      );
    }

    for (final relation in context.owningJoinColumns) {
      final joinType = relation.joinColumnBaseDartType!;
      final typeWithNull = relation.joinColumnNullable
          ? '$joinType?'
          : joinType;
      params.add(
        Parameter(
          (p) => p
            ..name = relation.joinColumnPropertyName!
            ..named = true
            ..type = refer(typeWithNull),
        ),
      );
    }

    for (final relation in cascades) {
      final targetDto = '${relation.targetTypeCode}InsertDto';
      final type = relation.isCollection ? 'List<$targetDto>?' : '$targetDto?';
      params.add(
        Parameter(
          (p) => p
            ..name = relation.fieldName
            ..named = true
            ..type = refer(type),
        ),
      );
    }

    final args = <String>[];
    for (final c in columns) {
      args.add('${c.prop}: ${c.prop} ?? this.${c.prop}');
    }
    for (final relation in context.owningJoinColumns) {
      final prop = relation.joinColumnPropertyName!;
      args.add('$prop: $prop ?? this.$prop');
    }
    for (final relation in cascades) {
      final prop = relation.fieldName;
      args.add('$prop: $prop ?? this.$prop');
    }

    return Method(
      (m) => m
        ..name = 'copyWith'
        ..returns = refer(context.insertDtoName)
        ..optionalParameters.addAll(params)
        ..body = Code('return ${context.insertDtoName}(${args.join(', ')});'),
    );
  }
}

/// Builds the UpdateDto class for an entity.
class UpdateDtoBuilder {
  const UpdateDtoBuilder();

  /// Builds the complete UpdateDto class.
  Class build(EntityGenerationContext context) {
    final updateableColumns = context.columns
        .where((c) => !c.autoIncrement && !c.isPk)
        .toList();
    final cascadeRelations = context.relations
        .where((r) => r.cascadeMerge)
        .toList();

    return Class(
      (c) => c
        ..name = context.updateDtoName
        ..implements.add(
          TypeReference(
            (t) => t
              ..symbol = 'UpdateDto'
              ..types.add(refer(context.entityName)),
          ),
        )
        ..constructors.add(
          _buildConstructor(context, updateableColumns, cascadeRelations),
        )
        ..fields.addAll(_buildColumnFields(updateableColumns))
        ..fields.addAll(_buildJoinColumnFields(context))
        ..fields.addAll(_buildCascadeFields(cascadeRelations))
        ..methods.add(_buildToMapMethod(context, updateableColumns))
        ..methods.add(_buildCascadesGetter(cascadeRelations)),
    );
  }

  Constructor _buildConstructor(
    EntityGenerationContext context,
    List<GenColumn> columns,
    List<GenRelation> cascades,
  ) {
    final params = <Parameter>[];

    for (final c in columns) {
      params.add(
        Parameter(
          (p) => p
            ..name = c.prop
            ..named = true
            ..toThis = true,
        ),
      );
    }

    for (final relation in context.owningJoinColumns) {
      params.add(
        Parameter(
          (p) => p
            ..name = relation.joinColumnPropertyName!
            ..named = true
            ..toThis = true,
        ),
      );
    }

    for (final relation in cascades) {
      params.add(
        Parameter(
          (p) => p
            ..name = relation.fieldName
            ..named = true
            ..toThis = true,
        ),
      );
    }

    return Constructor(
      (c) => c
        ..constant = true
        ..optionalParameters.addAll(params),
    );
  }

  Iterable<Field> _buildColumnFields(List<GenColumn> columns) {
    return columns.map((c) {
      // For update DTO, all fields are optional (nullable)
      final type = _nullableType(c.dartTypeCode);
      return Field(
        (f) => f
          ..name = c.prop
          ..modifier = FieldModifier.final$
          ..type = refer(type),
      );
    });
  }

  Iterable<Field> _buildJoinColumnFields(EntityGenerationContext context) {
    return context.owningJoinColumns.map((relation) {
      final joinType = relation.joinColumnBaseDartType!;
      return Field(
        (f) => f
          ..name = relation.joinColumnPropertyName!
          ..modifier = FieldModifier.final$
          ..type = refer('$joinType?'),
      );
    });
  }

  Iterable<Field> _buildCascadeFields(List<GenRelation> relations) {
    return relations.map((relation) {
      final targetDto = '${relation.targetTypeCode}UpdateDto';
      final type = relation.isCollection ? 'List<$targetDto>?' : '$targetDto?';
      return Field(
        (f) => f
          ..name = relation.fieldName
          ..modifier = FieldModifier.final$
          ..type = refer(type),
      );
    });
  }

  Method _buildToMapMethod(
    EntityGenerationContext context,
    List<GenColumn> columns,
  ) {
    final updatedAtExpr = {
      for (final f in context.updatedAtFields) f.fieldName: f.valueExpression,
    };

    final deletedAtExpr = {
      for (final f in context.deletedAtFields) f.fieldName: f.valueExpression,
    };

    final entries = <String>[];

    for (final c in columns) {
      final timestampExpr = updatedAtExpr[c.prop] ?? deletedAtExpr[c.prop];
      if (timestampExpr != null) {
        var valueExpr = _enumToStorage(
          c,
          _timestampLiteralToDateTime(c, timestampExpr),
        );
        entries.add("'${c.name}': $valueExpr");
        continue;
      }
      var valueExpr = _enumToStorage(
        c,
        _timestampPropToDateTime(c, c.prop, true, c.isDeletedAt),
        true,
        c.isDeletedAt,
      );
      entries.add("if(${c.prop} != null) '${c.name}': $valueExpr");
    }

    for (final relation in context.owningJoinColumns) {
      entries.add(
        "if(${relation.joinColumnPropertyName} != null) '${relation.joinColumn!.name}': ${relation.joinColumnPropertyName}",
      );
    }

    return Method(
      (m) => m
        ..annotations.add(refer('override'))
        ..name = 'toMap'
        ..returns = refer('Map<String, dynamic>')
        ..body = Code('return {${entries.join(', ')}};')
        ..lambda = false,
    );
  }

  Method _buildCascadesGetter(List<GenRelation> relations) {
    final entries = <String>[];
    for (final relation in relations) {
      entries.add(
        "if(${relation.fieldName} != null) '${relation.fieldName}': ${relation.fieldName}",
      );
    }
    final body = entries.isEmpty
        ? 'return const {};'
        : 'return {${entries.join(', ')}};';
    return Method(
      (m) => m
        ..name = 'cascades'
        ..type = MethodType.getter
        ..returns = refer('Map<String, dynamic>')
        ..body = Code(body),
    );
  }
}

String _nullableType(String type) {
  return type.endsWith('?') ? type : '$type?';
}

String _timestampLiteralToDateTime(GenColumn c, String expr) {
  final base = c.dartTypeCode.replaceAll('?', '');
  switch (base) {
    case 'int':
      return 'DateTime.fromMillisecondsSinceEpoch($expr).toIso8601String()';
    case 'double':
      return 'DateTime.fromMillisecondsSinceEpoch($expr.toInt()).toIso8601String()';
    case 'String':
      return 'DateTime.parse($expr).toIso8601String()';
    default:
      if (expr.startsWith('DateTime')) {
        return '$expr.toIso8601String()';
      }
      return '$expr is DateTime ? ($expr as DateTime).toIso8601String() : $expr?.toString()';
  }
}

String _timestampPropToDateTime(
  GenColumn c,
  String prop, [
  bool toUpdateDto = false,
  bool toDeletedAt = false,
]) {
  final isNullable = c.nullable || toUpdateDto || toDeletedAt;
  if (!c.isCreatedAt && !c.isUpdatedAt && !c.isDeletedAt) {
    final base = c.dartTypeCode.replaceAll('?', '');
    if (base == 'DateTime') {
      return isNullable
          ? '$prop?.toIso8601String()'
          : '$prop.toIso8601String()';
    }
    return prop;
  }
  final base = c.dartTypeCode.replaceAll('?', '');
  switch (base) {
    case 'int':
      return '$prop == null ? null : DateTime.fromMillisecondsSinceEpoch($prop).toIso8601String()';
    case 'double':
      return '$prop == null ? null : DateTime.fromMillisecondsSinceEpoch($prop.toInt()).toIso8601String()';
    case 'String':
      return '$prop == null ? null : DateTime.parse($prop).toIso8601String()';
    default:
      if (prop.startsWith('DateTime')) {
        return isNullable
            ? '$prop?.toIso8601String()'
            : '$prop.toIso8601String()';
      }
      return '$prop is DateTime ? ($prop as DateTime).toIso8601String() : $prop?.toString()';
  }
}

String _enumToStorage(GenColumn c, String expr, [bool toUpdateDto = false, bool toDeletedAt = false]) {
  if (!c.isEnum) return expr;
  switch (c.type) {
    case ColumnType.text:
      return c.nullable || toUpdateDto || toDeletedAt ? '$expr?.name' : '$expr.name';
    case ColumnType.integer:
      return c.nullable || toUpdateDto || toDeletedAt ? '$expr?.index' : '$expr.index';
    default:
      return expr;
  }
}
