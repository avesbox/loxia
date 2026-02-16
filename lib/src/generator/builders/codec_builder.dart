library;

import 'package:code_builder/code_builder.dart';

import 'models.dart';

class CodecBuilder {
  const CodecBuilder();

  Iterable<Spec> buildAll(EntityGenerationContext context) sync* {
    yield _buildEntityCodecExtension(context);
    yield _buildPartialCodecExtension(context);
    yield _buildEntityCodecInitializedFlag(context);
    yield _buildEntityCodecInitFunction(context);
  }

  Extension _buildEntityCodecExtension(EntityGenerationContext context) {
    return Extension(
      (e) => e
        ..name = '${context.entityName}Codec'
        ..on = refer(context.entityName)
        ..methods.add(_buildToEncodableMethod())
        ..methods.add(_buildToJsonStringMethod()),
    );
  }

  Extension _buildPartialCodecExtension(EntityGenerationContext context) {
    return Extension(
      (e) => e
        ..name = '${context.partialEntityName}Codec'
        ..on = refer(context.partialEntityName)
        ..methods.add(_buildToEncodableMethod())
        ..methods.add(_buildToJsonStringMethod()),
    );
  }

  Method _buildToEncodableMethod() {
    return Method(
      (m) => m
        ..name = 'toEncodable'
        ..returns = refer('Object?')
        ..body = Code('return toJson();'),
    );
  }

  Method _buildToJsonStringMethod() {
    return Method(
      (m) => m
        ..name = 'toJsonString'
        ..returns = refer('String')
        ..body = Code('return encodeJsonColumn(toJson()) as String;'),
    );
  }

  Field _buildEntityCodecInitializedFlag(EntityGenerationContext context) {
    return Field(
      (f) => f
        ..name = context.codecInitializedFlagName
        ..modifier = FieldModifier.var$
        ..assignment = Code('false'),
    );
  }

  Method _buildEntityCodecInitFunction(EntityGenerationContext context) {
    final entityType = context.entityName;
    final entityJsonExtension = '${context.entityName}Json';
    final initializedFlag = context.codecInitializedFlagName;
    return Method(
      (m) => m
        ..name = context.codecInitFunctionName
        ..returns = refer('void')
        ..body = Code(
          'if ($initializedFlag) return; '
          'EntityJsonRegistry.register<$entityType>((value) => '
          '$entityJsonExtension(value).toJson()); '
          '$initializedFlag = true;',
        ),
    );
  }
}
