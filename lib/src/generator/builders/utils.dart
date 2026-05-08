/// Utility functions for code generation.
library;

import 'package:code_builder/code_builder.dart';

import '../../annotations/column.dart';
import 'models.dart';

/// Creates a const list literal.
Expression constList(List<Expression> items, [Reference? type]) {
  return literalConstList(items, type);
}

/// Gets the simple type name from a type code (removes generics and qualifiers).
String simpleTypeName(String typeCode) {
  final genericsIndex = typeCode.indexOf('<');
  final trimmed = genericsIndex == -1
      ? typeCode
      : typeCode.substring(0, genericsIndex);
  final dotIndex = trimmed.lastIndexOf('.');
  return dotIndex == -1 ? trimmed : trimmed.substring(dotIndex + 1);
}

/// Escapes a string for use in generated code.
String escapeString(String value) => value.replaceAll("'", "\\'");

String enumReadExpression(GenColumn c, String source, {String? enumType}) {
  final resolvedEnumType =
      enumType ?? c.enumTypeName ?? c.dartTypeCode.replaceAll('?', '');
  final enumValueAccessor = c.enumValueAccessor;

  switch (c.type) {
    case ColumnType.text:
      if (enumValueAccessor != null) {
        return '$resolvedEnumType.values.firstWhere((entry) => entry.$enumValueAccessor == ($source as String))';
      }
      return '$resolvedEnumType.values.byName($source as String)';
    case ColumnType.integer:
      if (enumValueAccessor != null) {
        return '$resolvedEnumType.values.firstWhere((entry) => entry.$enumValueAccessor == ($source as int))';
      }
      return '$resolvedEnumType.values[$source as int]';
    default:
      return '$source as $resolvedEnumType';
  }
}

String enumStoreExpression(GenColumn c, String source, {bool? isNullable}) {
  final nullable = isNullable ?? c.nullable;
  final enumValueAccessor =
      c.enumValueAccessor ??
      switch (c.type) {
        ColumnType.text => 'name',
        ColumnType.integer => 'index',
        _ => null,
      };

  if (enumValueAccessor == null) return source;
  return nullable
      ? '$source?.$enumValueAccessor'
      : '$source.$enumValueAccessor';
}
