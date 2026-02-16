import 'util/entity_json_registry.dart';

/// Base class for all ORM entities.
///
/// The class itself does not impose any behavior but helps keep the API
/// type-safe by constraining repositories and descriptors to entity types.
abstract class Entity {
  const Entity();

  /// Converts this entity to JSON using generated codecs registered at runtime.
  Map<String, dynamic> toJson() {
    final encoded = EntityJsonRegistry.tryEncode(this);
    if (encoded != null) return encoded;
    throw UnsupportedError(
      'No JSON codec registered for ${runtimeType.toString()}. '
      'Ensure generated part files are included and loaded.',
    );
  }
}
