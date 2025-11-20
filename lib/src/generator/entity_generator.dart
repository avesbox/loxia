import 'dart:async';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import '../../loxia.dart' show Column, ColumnType, EntityMeta, PrimaryKey;

class LoxiaEntityGenerator extends GeneratorForAnnotation<EntityMeta> {
  @override
  Future<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    if (element is! ClassElement) return '';
    final clazz = element;
    final className = clazz.displayName;
    if (clazz.isAbstract) return '';
    final table = annotation.peek('table')?.stringValue ?? _toSnake(className);
    final schema = annotation.peek('schema')?.stringValue;

    final columns = <_GenColumn>[];

    for (final field in clazz.fields.where((f) => !f.isStatic)) {
      final colAnnObj = _firstAnnotation(field, Column) ?? _firstAnnotation(field, PrimaryKey);
      if (colAnnObj == null) continue;
      final colAnn = ConstantReader(colAnnObj);

      final isPk = _firstAnnotation(field, PrimaryKey) != null;
      final colName = colAnn.peek('name')?.stringValue ?? _toSnake(field.displayName);
      final dartType = field.type;
      final nullable = dartType.nullabilitySuffix != NullabilitySuffix.none;
      final unique = colAnn.peek('unique')?.boolValue ?? false;
      final defaultValue = colAnn.peek('defaultValue')?.objectValue;

      final autoInc = isPk ? (colAnn.peek('autoIncrement')?.boolValue ?? false) : false;
      final uuid = isPk ? (colAnn.peek('uuid')?.boolValue ?? false) : false;

      final type = _resolveColumnType(colAnn, dartType);
      final dartTypeCode = dartType.getDisplayString();

      columns.add(_GenColumn(
        name: colName,
        prop: field.displayName,
        type: type,
        dartTypeCode: dartTypeCode,
        nullable: nullable,
        unique: unique,
        isPk: isPk,
        autoIncrement: autoInc,
        uuid: uuid,
        defaultLiteral: _dartObjToLiteral(defaultValue),
      ));
    }

    final buf = StringBuffer();
    buf.writeln('final EntityDescriptor<$className> \$${className}EntityDescriptor = EntityDescriptor<$className>(');
    buf.writeln("  entityType: $className,");
    buf.writeln("  tableName: '$table',");
    if (schema != null) {
      buf.writeln("  schema: '$schema',");
    }
    buf.writeln('  columns: [');
    for (final c in columns) {
      buf.writeln('    ColumnDescriptor(');
      buf.writeln("      name: '${c.name}',");
      buf.writeln("      propertyName: '${c.prop}',");
      buf.writeln('      type: ColumnType.${c.type.name},');
      buf.writeln('      nullable: ${c.nullable},');
      buf.writeln('      unique: ${c.unique},');
      buf.writeln('      isPrimaryKey: ${c.isPk},');
      buf.writeln('      autoIncrement: ${c.autoIncrement},');
      buf.writeln('      uuid: ${c.uuid},');
      if (c.defaultLiteral != null) {
        buf.writeln('      defaultValue: ${c.defaultLiteral},');
      }
      buf.writeln('    ),');
    }
    buf.writeln('  ],');
    buf.writeln('  relations: const [],');
    // fromRow mapping
    buf.writeln('  fromRow: (row) => $className(');
    for (final c in columns) {
      buf.writeln("    ${c.prop}: row['${c.name}'] as ${c.dartTypeCode},");
    }
    buf.writeln('  ),');
    // toRow mapping
    buf.writeln('  toRow: (e) => {');
    for (final c in columns) {
      buf.writeln("    '${c.name}': e.${c.prop},");
    }
    buf.writeln('  },');
    buf.write('  fieldsContext: const ${className}FieldsContext(),');
    buf.writeln(');');
    buf.writeln();
    final builderFieldsClass = '${className}FieldsContext';
    buf.writeln('class $builderFieldsClass extends QueryFieldsContext<$className> {');
    buf.writeln('  const $builderFieldsClass();');
    for (final c in columns) {
      buf.writeln("  QueryField<${c.dartTypeCode}> get ${c.prop} => const QueryField<${c.dartTypeCode}>('${c.name}');");
    }
    buf.writeln('}');
    final queryClass = '${className}Query';
    buf.writeln('class $queryClass extends QueryBuilder<$className> {');
    buf.writeln('  const $queryClass(this._builder);');
    buf.writeln('  final WhereExpression Function($builderFieldsClass q) _builder;');
    buf.writeln('  @override');
    buf.writeln('  WhereExpression build(QueryFieldsContext<$className> context) {');
    buf.writeln('    if (context is! $builderFieldsClass) {');
    buf.writeln("      throw ArgumentError('Expected $builderFieldsClass for $queryClass');");
    buf.writeln('    }');
    buf.writeln('    return _builder(context);');
    buf.writeln('  }');
    buf.writeln('}');
    final insertDtoName = '${className}InsertDto';
    buf.writeln('class $insertDtoName implements InsertDto<$className> {');
    buf.writeln('  const $insertDtoName({');
    for (final c in columns.where((c) => !c.autoIncrement && !c.isPk)) {
      buf.writeln('   ${c.nullable ? '' : 'required '}this.${c.prop},');
    }
    buf.writeln('  });');
    for (final c in columns.where((c) => !c.autoIncrement && !c.isPk)) {
      buf.writeln('  final ${c.dartTypeCode} ${c.prop};');
    }
    buf.writeln();
    buf.writeln('  @override');
    buf.writeln('  Map<String, dynamic> toMap() {');
    buf.writeln('    return {');
    for (final c in columns.where((c) => !c.autoIncrement && !c.isPk)) {
      buf.writeln("      '${c.name}': ${c.prop},");
    }
    buf.writeln('    };');
    buf.writeln('  }');
    buf.writeln('}');
    final updateDtoName = '${className}UpdateDto';
    buf.writeln('class $updateDtoName implements UpdateDto<$className> {');
    buf.writeln('  const $updateDtoName({');
    for (final c in columns.where((c) => !c.autoIncrement && !c.isPk)) {
      buf.writeln('    this.${c.prop},');
    }
    buf.writeln('  });');
    for (final c in columns.where((c) => !c.autoIncrement && !c.isPk)) {
      buf.writeln('  final ${c.dartTypeCode}${c.nullable ? '' : '?'} ${c.prop};');
    }
    buf.writeln();
    buf.writeln('  @override');
    buf.writeln('  Map<String, dynamic> toMap() {');
    buf.writeln('    return {');
    for (final c in columns.where((c) => !c.autoIncrement && !c.isPk)) {
      buf.writeln("      if(${c.prop} != null) '${c.name}': ${c.prop},");
    }
    buf.writeln('    };');
    buf.writeln('  }');
    buf.writeln('}');

    return buf.toString();
  }

  DartObject? _firstAnnotation(FieldElement field, Type t) {
    final want = t.toString();
    final metas = (field.metadata as dynamic);
    final iterable = (metas is Iterable) ? metas : (metas.annotations as Iterable);
    for (final meta in iterable) {
      final obj = meta.computeConstantValue();
      if (obj == null) continue;
      final typeName = obj.type?.getDisplayString();
      if (typeName == want) return obj;
    }
    return null;
  }

  ColumnType _resolveColumnType(ConstantReader ann, DartType type) {
    final explicit = ann.peek('type');
    if (explicit != null && !explicit.isNull) {
      // If a specific ColumnType was provided, map it directly by reading the enum name.
      final ev = explicit.objectValue;
      final typeName = ev.type?.getDisplayString();
      if (typeName != null && typeName.endsWith('ColumnType')) {
        // Not reliable across analyzer versions; fall back to inference.
      }
    }
    return _inferColumnType(type);
  }

  ColumnType _inferColumnType(DartType type) {
    var name = type.getDisplayString();
    if (type.nullabilitySuffix == NullabilitySuffix.question) {
      name = name.substring(0, name.length - 1);
    }
    switch (name) {
      case 'int':
        return ColumnType.integer;
      case 'String':
        return ColumnType.text;
      case 'bool':
        return ColumnType.boolean;
      case 'double':
        return ColumnType.doublePrecision;
      case 'DateTime':
        return ColumnType.dateTime;
      default:
        return ColumnType.text;
    }
  }

  String? _dartObjToLiteral(DartObject? obj) {
    if (obj == null) return null;
    final type = obj.type?.getDisplayString();
    final i = obj.toIntValue();
    if (i != null) return i.toString();
    final d = obj.toDoubleValue();
    if (d != null) return d.toString();
    if (type == 'bool') return (obj.toBoolValue() ?? false) ? 'true' : 'false';
    final s = obj.toStringValue();
    if (s != null) return "'${s.replaceAll("'", "\\'")}'";
    return null;
  }

  String _toSnake(String input) {
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final c = input[i];
      final isUpper = c.toUpperCase() == c && c.toLowerCase() != c;
      if (isUpper && i != 0) buffer.write('_');
      buffer.write(c.toLowerCase());
    }
    return buffer.toString();
  }
}

class _GenColumn {
  _GenColumn({
    required this.name,
    required this.prop,
    required this.type,
    required this.dartTypeCode,
    required this.nullable,
    required this.unique,
    required this.isPk,
    required this.autoIncrement,
    required this.uuid,
    this.defaultLiteral,
  });

  final String name;
  final String prop;
  final ColumnType type;
  final String dartTypeCode;
  final bool nullable;
  final bool unique;
  final bool isPk;
  final bool autoIncrement;
  final bool uuid;
  final String? defaultLiteral;
}
