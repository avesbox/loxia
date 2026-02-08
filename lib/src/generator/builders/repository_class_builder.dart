import 'package:code_builder/code_builder.dart';
import 'models.dart';

class RepositoryClassBuilder {
  // Implementation of the RepositoryClassBuilder
  const RepositoryClassBuilder();

  Class build(EntityGenerationContext context) {
    final entityName = context.className;
    final partialName = '${entityName}Partial';
    final repoName = '${entityName}Repository';
    final descriptorName = '\$${entityName}EntityDescriptor';

    return Class((c) => c
      ..name = repoName
      ..extend = refer('EntityRepository<$entityName, $partialName>')
      // Define the constructor that Serinus will call
      ..constructors.add(Constructor((ctor) => ctor
        ..requiredParameters.add(Parameter((p) => p
          ..name = 'engine'
          ..type = refer('EngineAdapter')
        ))
        ..initializers.add(
          refer('super').call([
            refer(descriptorName), // The generated global descriptor
            refer('engine'),       // The injected engine
            refer('$descriptorName.fieldsContext'), // The context
          ]).code,
        )
      ))
    );
  }
}