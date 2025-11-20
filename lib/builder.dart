import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/generator/entity_generator.dart';

Builder entityDescriptorBuilder(BuilderOptions options) =>
    SharedPartBuilder([LoxiaEntityGenerator()], 'loxia');
