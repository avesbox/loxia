/// Builder for generating Query result DTO classes.
library;

import 'package:code_builder/code_builder.dart';

import 'models.dart';

/// Builds DTO classes for custom query results.
///
/// When a query selects columns that don't match the entity structure
/// (e.g., aggregates, aliases, specific columns), this builder generates
/// a typed DTO class to hold the results.
class QueryResultDtoBuilder {
  const QueryResultDtoBuilder();

  /// Builds all DTO classes for queries that require them.
  List<Class> buildAll(EntityGenerationContext context) {
    final classes = <Class>[];

    for (final query in context.queries) {
      if (query.analysisResult != null && query.analysisResult!.requiresDto) {
        classes.add(build(query, context));
      }
    }

    return classes;
  }

  /// Builds a single DTO class for a query.
  Class build(GenQuery query, EntityGenerationContext context) {
    final analysis = query.analysisResult!;

    return Class((c) {
      c
        ..name = analysis.dtoClassName
        ..docs.add('/// Result DTO for the [${query.name}] query.')
        ..modifier = ClassModifier.final$
        ..fields.addAll(_buildFields(analysis))
        ..constructors.add(_buildConstructor(analysis))
        ..constructors.add(_buildFromMapConstructor(analysis));
    });
  }

  /// Builds the fields for the DTO.
  List<Field> _buildFields(GenQueryAnalysisResult analysis) {
    return analysis.columns.map((col) {
      return Field((f) {
        f
          ..name = col.name
          ..type = refer(col.dartType)
          ..modifier = FieldModifier.final$;
      });
    }).toList();
  }

  /// Builds the primary constructor.
  Constructor _buildConstructor(GenQueryAnalysisResult analysis) {
    return Constructor((ctor) {
      ctor
        ..constant = true
        ..optionalParameters.addAll(
          analysis.columns.map((col) {
            return Parameter((p) {
              p
                ..name = col.name
                ..named = true
                ..toThis = true
                ..required = !col.nullable;
            });
          }),
        );
    });
  }

  /// Builds the fromMap factory constructor.
  Constructor _buildFromMapConstructor(GenQueryAnalysisResult analysis) {
    return Constructor((ctor) {
      ctor
        ..factory = true
        ..name = 'fromMap'
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'map'
              ..type = refer('Map<String, dynamic>'),
          ),
        )
        ..body = _buildFromMapBody(analysis);
    });
  }

  /// Builds the body of the fromMap factory.
  Code _buildFromMapBody(GenQueryAnalysisResult analysis) {
    final buffer = StringBuffer();
    buffer.writeln('return ${analysis.dtoClassName}(');

    for (final col in analysis.columns) {
      // Get the map key - use original column name if available, otherwise use dart name
      final mapKey = col.originalColumnName ?? _toSnakeCase(col.name);

      // Generate the type cast
      final castExpr = _generateCast(col, mapKey);
      buffer.writeln('  ${col.name}: $castExpr,');
    }

    buffer.writeln(');');
    return Code(buffer.toString());
  }

  /// Generates the proper cast expression for a column.
  String _generateCast(GenQueryColumn col, String mapKey) {
    final baseType = col.dartType.replaceAll('?', '');
    final isNullable = col.dartType.endsWith('?');

    // Handle common types
    switch (baseType) {
      case 'int':
        if (isNullable) {
          return "map['$mapKey'] as int?";
        }
        return "map['$mapKey'] as int";

      case 'double':
        if (isNullable) {
          return "(map['$mapKey'] as num?)?.toDouble()";
        }
        return "(map['$mapKey'] as num).toDouble()";

      case 'num':
        if (isNullable) {
          return "map['$mapKey'] as num?";
        }
        return "map['$mapKey'] as num";

      case 'String':
        if (isNullable) {
          return "map['$mapKey'] as String?";
        }
        return "map['$mapKey'] as String";

      case 'bool':
        if (isNullable) {
          return "map['$mapKey'] == null ? null : (map['$mapKey'] as int) != 0";
        }
        return "(map['$mapKey'] as int) != 0";

      case 'DateTime':
        if (isNullable) {
          return "map['$mapKey'] == null ? null : DateTime.parse(map['$mapKey'] as String)";
        }
        return "DateTime.parse(map['$mapKey'] as String)";

      case 'List<int>':
        if (isNullable) {
          return "map['$mapKey'] as List<int>?";
        }
        return "map['$mapKey'] as List<int>";

      case 'Object':
        return "map['$mapKey']";

      default:
        // Generic fallback
        if (isNullable) {
          return "map['$mapKey'] as $baseType?";
        }
        return "map['$mapKey'] as $baseType";
    }
  }

  /// Converts camelCase to snake_case.
  String _toSnakeCase(String input) {
    if (input.isEmpty) return input;

    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char.toUpperCase() == char && char.toLowerCase() != char) {
        if (i > 0) buffer.write('_');
        buffer.write(char.toLowerCase());
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }
}
