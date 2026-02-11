/// Lifecycle hook annotations for entities.
class PrePersist {
  const PrePersist();
}

class PostPersist {
  const PostPersist();
}

class PreUpdate {
  const PreUpdate();
}

class PostUpdate {
  const PostUpdate();
}

class PreRemove {
  const PreRemove();
}

class PostRemove {
  const PostRemove();
}

class PostLoad {
  const PostLoad();
}

enum Lifecycle {
  prePersist,
  postPersist,
  preUpdate,
  postUpdate,
  preRemove,
  postRemove,
  postLoad,
}
