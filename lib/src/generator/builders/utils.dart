/// Utility functions for code generation.
library;

import 'package:code_builder/code_builder.dart';

/// Creates a const list literal.
Expression constList(List<Expression> items, [Reference? type]) {
  return literalConstList(items, type);
}

/// Gets the simple type name from a type code (removes generics and qualifiers).
String simpleTypeName(String typeCode) {
  final genericsIndex = typeCode.indexOf('<');
  final trimmed =
      genericsIndex == -1 ? typeCode : typeCode.substring(0, genericsIndex);
  final dotIndex = trimmed.lastIndexOf('.');
  return dotIndex == -1 ? trimmed : trimmed.substring(dotIndex + 1);
}

/// Escapes a string for use in generated code.
String escapeString(String value) => value.replaceAll("'", "\\'");
