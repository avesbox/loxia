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

  /// Returns the primary key value for this partial entity.
  ///
  /// Used by repository.save() to decide between insert and update.
  Object? get primaryKeyValue;

  /// Attempts to convert this partial to a full entity.
  /// Throws [StateError] if required fields are missing.
  T toEntity();

  /// Converts this partial to an InsertDto.
  /// Throws [StateError] if required fields are missing.
  InsertDto<T> toInsertDto();

  /// Converts this partial to an UpdateDto.
  UpdateDto<T> toUpdateDto();

  /// Converts this partial entity to a JSON map.
  Map<String, dynamic> toJson();
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

  bool get hasNextPage => page < pageCount;
  bool get hasPreviousPage => page > 1;

  Map<String, dynamic> toJson() => {
    'items': items is List<PartialEntity>
      ? (items as List<PartialEntity>).map((e) => e.toJson()).toList()
      : items,
    'total': total,
    'page': page,
    'pageSize': pageSize,
    'pageCount': pageCount,
    'hasNextPage': hasNextPage,
    'hasPreviousPage': hasPreviousPage,
  };
}

/// Represents an update operation for a ManyToMany relation.
///
/// This class allows fine-grained control over how a ManyToMany collection
/// is updated:
/// - [add]: Add new target IDs to the collection
/// - [remove]: Remove target IDs from the collection
/// - [set]: Replace the entire collection with a new set of IDs
///
/// If [set] is provided, [add] and [remove] are ignored.
class ManyToManyCascadeUpdate {
  const ManyToManyCascadeUpdate({this.add, this.remove, this.set});

  /// Target IDs to add to the collection.
  final List<int>? add;

  /// Target IDs to remove from the collection.
  final List<int>? remove;

  /// Replace the entire collection with these target IDs.
  /// If set, [add] and [remove] are ignored.
  final List<int>? set;
}
