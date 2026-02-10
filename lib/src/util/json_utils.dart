import 'dart:convert';

/// Encodes a Dart object to a JSON string for storage in JSON columns.
Object? encodeJsonColumn(Object? value) {
  if (value == null) return null;
  return jsonEncode(value);
}

/// Decodes a database value coming from a JSON column into Dart types.
/// If the value is already a Map/List it is returned as-is.
/// Also handles PostgreSQL native array format: {val1,val2,"quoted val"}
Object? decodeJsonColumn(Object? value) {
  if (value == null) return null;
  if (value is List || value is Map) return value;
  if (value is String) {
    final trimmed = value.trim();
    // PostgreSQL array format: {val1,val2,...}
    // Distinguish from JSON object by checking for "key": pattern
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      // JSON objects have "key": patterns, PostgreSQL arrays don't
      if (!RegExp(r'"[^"]*"\s*:').hasMatch(trimmed)) {
        return _parsePostgresArray(trimmed);
      }
    }
    return jsonDecode(value);
  }
  return value;
}

/// Parses PostgreSQL array format: {val1,val2,"quoted, val"}
List<String> _parsePostgresArray(String value) {
  final inner = value.substring(1, value.length - 1);
  if (inner.isEmpty) return [];

  final result = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;
  var i = 0;

  while (i < inner.length) {
    final char = inner[i];

    if (char == '"' && !inQuotes) {
      inQuotes = true;
      i++;
      continue;
    }

    if (char == '"' && inQuotes) {
      // Check for escaped quote ""
      if (i + 1 < inner.length && inner[i + 1] == '"') {
        buffer.write('"');
        i += 2;
        continue;
      }
      inQuotes = false;
      i++;
      continue;
    }

    if (char == ',' && !inQuotes) {
      result.add(buffer.toString());
      buffer.clear();
      i++;
      continue;
    }

    buffer.write(char);
    i++;
  }

  // Add last element
  if (buffer.isNotEmpty || inner.endsWith(',')) {
    result.add(buffer.toString());
  }

  return result;
}
