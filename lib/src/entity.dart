/// Base class for all ORM entities.
///
/// The class itself does not impose any behavior but helps keep the API
/// type-safe by constraining repositories and descriptors to entity types.
abstract class Entity {
  const Entity();
}
