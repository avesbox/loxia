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

/// Standard pagination result for repository queries.
class PaginatedResult<P> {
  const PaginatedResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.pageCount,
  });

  final List<P> items;
  final int total;
  final int page;
  final int pageSize;
  final int pageCount;
}