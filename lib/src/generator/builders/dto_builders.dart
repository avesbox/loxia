/// Builders for generating InsertDto and UpdateDto classes.
library;

import 'package:code_builder/code_builder.dart';

import '../../annotations/column.dart';
import 'models.dart';
import 'utils.dart';

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
        ..constructors.add(
          _buildFromMapConstructor(
            context,
            insertableColumns,
            cascadeRelations,
          ),
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
      final isTimestampManaged =
          c.isCreatedAt || c.isUpdatedAt || c.isDeletedAt;
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

  Constructor _buildFromMapConstructor(
    EntityGenerationContext context,
    List<GenColumn> columns,
    List<GenRelation> cascades,
  ) {
    return Constructor(
      (c) => c
        ..factory = true
        ..name = 'fromMap'
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'map'
              ..type = refer('Map<String, dynamic>'),
          ),
        )
        ..body = _buildFromMapBody(
          context,
          columns,
          cascades,
          isInsertDto: true,
        ),
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
      final timestampExpr =
          createdAtExpr[c.prop] ??
          updatedAtExpr[c.prop] ??
          deletedAtExpr[c.prop];
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
      params.add(
        Parameter(
          (p) => p
            ..name = relation.joinColumnPropertyName!
            ..named = true
            ..type = refer('$joinType?'), // Always nullable for copyWith
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
        ..constructors.add(
          _buildFromMapConstructor(
            context,
            updateableColumns,
            cascadeRelations,
          ),
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

  Constructor _buildFromMapConstructor(
    EntityGenerationContext context,
    List<GenColumn> columns,
    List<GenRelation> cascades,
  ) {
    return Constructor(
      (c) => c
        ..factory = true
        ..name = 'fromMap'
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'map'
              ..type = refer('Map<String, dynamic>'),
          ),
        )
        ..body = _buildFromMapBody(
          context,
          columns,
          cascades,
          isInsertDto: false,
        ),
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

Code _buildFromMapBody(
  EntityGenerationContext context,
  List<GenColumn> columns,
  List<GenRelation> cascades, {
  required bool isInsertDto,
}) {
  final dtoName = isInsertDto ? context.insertDtoName : context.updateDtoName;
  final buffer = StringBuffer();
  buffer.writeln('return $dtoName(');

  for (final column in columns) {
    buffer.writeln(
      '  ${column.prop}: ${_fromMapColumnValue(column, isInsertDto: isInsertDto)},',
    );
  }

  for (final relation in context.owningJoinColumns) {
    final prop = relation.joinColumnPropertyName!;
    buffer.writeln(
      '  $prop: ${_fromMapJoinColumnValue(relation, isInsertDto: isInsertDto)},',
    );
  }

  for (final relation in cascades) {
    buffer.writeln(
      '  ${relation.fieldName}: ${_fromMapCascadeValue(relation, isInsertDto: isInsertDto)},',
    );
  }

  buffer.writeln(');');
  return Code(buffer.toString());
}

String _nullableType(String type) {
  return type.endsWith('?') ? type : '$type?';
}

String _mapValueExpr(String key) {
  return "map['$key']";
}

String _mapHasKeyExpr(String key) {
  return "map.containsKey('$key')";
}

String _fromMapColumnValue(GenColumn c, {required bool isInsertDto}) {
  final source = _mapValueExpr(c.name);
  final hasKey = _mapHasKeyExpr(c.name);
  final baseType = c.dartTypeCode.replaceAll('?', '');
  final isNullable =
      !isInsertDto ||
      c.dartTypeCode.endsWith('?') ||
      c.isCreatedAt ||
      c.isUpdatedAt ||
      c.isDeletedAt;
  final defaultLiteral = isInsertDto ? c.defaultLiteral : null;

  if (c.type == ColumnType.dateTime && baseType == 'DateTime') {
    final parsed =
        '$source is String ? DateTime.parse($source.toString()) : $source as DateTime';
    return _wrapFromMapValue(
      source: source,
      hasKey: hasKey,
      parsed: parsed,
      isNullable: isNullable,
      defaultLiteral: defaultLiteral,
    );
  }

  if (c.type == ColumnType.json) {
    final parsed = _fromMapJsonValue(c, source);
    return _wrapFromMapValue(
      source: source,
      hasKey: hasKey,
      parsed: parsed,
      isNullable: isNullable,
      defaultLiteral: defaultLiteral,
    );
  }

  if (baseType == 'bool') {
    final expr = '$source is bool ? $source : $source == 1';
    return _wrapFromMapValue(
      source: source,
      hasKey: hasKey,
      parsed: expr,
      isNullable: isNullable,
      defaultLiteral: defaultLiteral,
    );
  }

  if (c.isEnum) {
    final enumType = c.enumTypeName ?? baseType;
    final expr = enumReadExpression(c, source, enumType: enumType);
    return _wrapFromMapValue(
      source: source,
      hasKey: hasKey,
      parsed: expr,
      isNullable: isNullable,
      defaultLiteral: defaultLiteral,
    );
  }

  if (c.isCreatedAt || c.isUpdatedAt || c.isDeletedAt) {
    final parsed =
        '($source is String ? DateTime.parse($source.toString()) : $source as DateTime)';
    String expr;
    switch (baseType) {
      case 'int':
        expr = '$parsed.millisecondsSinceEpoch';
      case 'double':
        expr = '$parsed.millisecondsSinceEpoch.toDouble()';
      case 'String':
        expr = '$parsed.toIso8601String()';
      default:
        expr = parsed;
    }
    return _wrapFromMapValue(
      source: source,
      hasKey: hasKey,
      parsed: expr,
      isNullable: isNullable,
      defaultLiteral: defaultLiteral,
    );
  }

  final parsed = _fromMapScalarValue(source, baseType, false);
  return _wrapFromMapValue(
    source: source,
    hasKey: hasKey,
    parsed: parsed,
    isNullable: isNullable,
    defaultLiteral: defaultLiteral,
  );
}

String _fromMapJoinColumnValue(
  GenRelation relation, {
  required bool isInsertDto,
}) {
  final source = _mapValueExpr(relation.joinColumn!.name);
  final hasKey = _mapHasKeyExpr(relation.joinColumn!.name);
  final isNullable = !isInsertDto || relation.joinColumnNullable;
  final parsed = _fromMapScalarValue(
    source,
    relation.joinColumnBaseDartType!,
    false,
  );
  return _wrapFromMapValue(
    source: source,
    hasKey: hasKey,
    parsed: parsed,
    isNullable: isNullable,
  );
}

String _wrapFromMapValue({
  required String source,
  required String hasKey,
  required String parsed,
  required bool isNullable,
  String? defaultLiteral,
}) {
  final nullableParsed = '$source == null ? null : $parsed';
  if (defaultLiteral != null) {
    return '$hasKey ? ${isNullable ? nullableParsed : parsed} : $defaultLiteral';
  }
  return isNullable ? nullableParsed : parsed;
}

String _fromMapScalarValue(String source, String dartType, bool isNullable) {
  switch (dartType) {
    case 'double':
      return isNullable
          ? '($source as num?)?.toDouble()'
          : '($source as num).toDouble()';
    case 'num':
      return isNullable ? '$source as num?' : '$source as num';
    default:
      return isNullable ? '$source as $dartType?' : '$source as $dartType';
  }
}

String _fromMapCascadeValue(GenRelation relation, {required bool isInsertDto}) {
  final source = _mapValueExpr(relation.fieldName);
  final dtoName =
      '${relation.targetTypeCode}${isInsertDto ? 'Insert' : 'Update'}Dto';

  if (relation.isCollection) {
    return "$source == null ? null : ($source as List).map<$dtoName>((entry) => entry is $dtoName ? entry : $dtoName.fromMap((entry as Map).cast<String, dynamic>())).toList()";
  }

  return "$source == null ? null : ($source is $dtoName ? $source : $dtoName.fromMap(($source as Map).cast<String, dynamic>()))";
}

String _fromMapJsonValue(GenColumn c, String source) {
  final baseType = c.dartTypeCode.replaceAll('?', '');
  final decoded = '$source is String ? decodeJsonColumn($source) : $source';
  final casted = _castJsonValue(decoded, baseType);
  return c.nullable ? '$source == null ? null : $casted' : casted;
}

String _castJsonValue(String decoded, String baseType) {
  final listMatch = RegExp(r'^List<(.+)>$').firstMatch(baseType);
  if (listMatch != null) {
    final elem = listMatch.group(1)!;
    return '(($decoded) as List).cast<$elem>()';
  }

  final mapMatch = RegExp(r'^Map<([^,>]+),\s*(.+)>$').firstMatch(baseType);
  if (mapMatch != null) {
    final key = mapMatch.group(1)!;
    final value = mapMatch.group(2)!;
    return '(($decoded) as Map).cast<$key, $value>()';
  }

  if (baseType == 'List') {
    return '(($decoded) as List).cast<dynamic>()';
  }
  if (baseType == 'Map') {
    return '(($decoded) as Map).cast<dynamic, dynamic>()';
  }

  return '$decoded as $baseType';
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

String _enumToStorage(
  GenColumn c,
  String expr, [
  bool toUpdateDto = false,
  bool toDeletedAt = false,
]) {
  if (!c.isEnum) return expr;
  return enumStoreExpression(
    c,
    expr,
    isNullable: c.nullable || toUpdateDto || toDeletedAt,
  );
}
