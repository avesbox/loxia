/// Timestamp column annotations.
class CreatedAt {
  const CreatedAt({this.utc = false});

  final bool utc;
}

class UpdatedAt {
  const UpdatedAt({this.utc = false});

  final bool utc;
}

class DeletedAt {
  const DeletedAt({this.utc = false});

  final bool utc;
}
