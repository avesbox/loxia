import '../entity.dart';

abstract class InsertDto<T extends Entity> {
  Map<String, dynamic> toMap();
}

abstract class UpdateDto<T extends Entity> {
  Map<String, dynamic> toMap();
}

/// A partial representation of an entity where all fields are nullable.
/// Used when selecting only specific columns from a query.
abstract class PartialEntity<T extends Entity> {
  const PartialEntity();

  /// Attempts to convert this partial to a full entity.
  /// Throws [StateError] if required fields are missing.
  T toEntity();
}