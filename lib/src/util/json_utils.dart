import 'dart:convert';

/// Encodes a Dart object to a JSON string for storage in JSON columns.
Object? encodeJsonColumn(Object? value) {
  if (value == null) return null;
  return jsonEncode(value);
}

/// Decodes a database value coming from a JSON column into Dart types.
/// If the value is already a Map/List it is returned as-is.
Object? decodeJsonColumn(Object? value) {
  if (value == null) return null;
  if (value is String) {
    return jsonDecode(value);
  }
  return value;
}
