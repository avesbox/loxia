library;

import 'package:code_builder/code_builder.dart';

import '../../annotations/column.dart';
import 'models.dart';

class JsonExtensionBuilder {
  const JsonExtensionBuilder();

  Extension build(EntityGenerationContext context) {
    return Extension(
      (e) => e
        ..name = '${context.entityName}Json'
        ..on = refer(context.entityName)
        ..methods.add(_buildToJsonMethod(context)),
    );
  }

  Method _buildToJsonMethod(EntityGenerationContext context) {
    final entries = <String>[];

    // Columns
    for (final c in context.columns) {
      final key = "'${c.prop}'";
      final source = c.prop;
      var value = source;
      if (c.isEnum) {
        if (c.type == ColumnType.text) {
          value = c.nullable ? '$value?.name' : '$value.name';
        } else if (c.type == ColumnType.integer) {
          value = c.nullable ? '$value?.index' : '$value.index';
        }
      } else if (c.type == ColumnType.dateTime &&
          c.dartTypeCode.contains('DateTime')) {
        if (c.nullable) {
          value = '$value?.toIso8601String()';
        } else {
          value = '$value.toIso8601String()';
        }
      }
      if (!c.nullable || !context.omitNullJsonFields) {
        entries.add('$key: $value');
      } else {
        entries.add('if ($source != null) $key: $value');
      }
    }

    // Relations
    for (final r in context.allSelectableRelations) {
      final key = "'${r.fieldName}'";
      final source = r.fieldName;
      var value = source;
      if (r.isCollection) {
        value = '$value?.map((e) => e.toJson()).toList()';
      } else {
        value = '$value?.toJson()';
      }
      if (context.omitNullJsonFields) {
        entries.add('if ($source != null) $key: $value');
      } else {
        entries.add('$key: $value');
      }
    }

    return Method(
      (m) => m
        ..name = 'toJson'
        ..returns = refer('Map<String, dynamic>')
        ..body = Code('return { ${entries.join(', ')} };'),
    );
  }
}
