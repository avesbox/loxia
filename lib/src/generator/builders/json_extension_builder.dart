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
      var value = c.prop;
      if (c.type == ColumnType.dateTime &&
          c.dartTypeCode.contains('DateTime')) {
        if (c.nullable) {
          value = '$value?.toIso8601String()';
        } else {
          value = '$value.toIso8601String()';
        }
      }
      entries.add('$key: $value');
    }

    // Relations
    for (final r in context.allSelectableRelations) {
      final key = "'${r.fieldName}'";
      var value = r.fieldName;
      if (r.isCollection) {
        value = '$value.map((e) => e.toJson()).toList()';
      } else {
        value = '$value?.toJson()';
      }
      entries.add('$key: $value');
    }

    return Method(
      (m) => m
        ..name = 'toJson'
        ..returns = refer('Map<String, dynamic>')
        ..body = Code('return { ${entries.join(', ')} };'),
    );
  }
}
