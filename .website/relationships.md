# Relationships

Loxia provides a powerful and intuitive way to define relationships between entities using annotations. This guide covers how to model relationships, configure join metadata, query related data, and leverage cascade operations.

## Overview

Loxia supports four relationship types:

| Annotation | Description | Example |
|------------|-------------|---------|
| `@OneToOne` | One entity relates to exactly one other entity | User ↔ Profile |
| `@OneToMany` | One entity relates to multiple entities | User → Posts |
| `@ManyToOne` | Multiple entities relate to one entity | Posts → User |
| `@ManyToMany` | Multiple entities relate to multiple entities | Posts ↔ Tags |

## Defining Relationships

### Basic Syntax

Each relationship annotation requires the `on` parameter to specify the target entity type:

```dart
@OneToOne(on: Profile)
final Profile? profile;

@OneToMany(on: Post, mappedBy: 'author')
final List<Post> posts;

@ManyToOne(on: User)
final User? author;

@ManyToMany(on: Tag)
final List<Tag> tags;
```

### Relationship Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `on` | `Type` | **Required.** The target entity class |
| `mappedBy` | `String?` | Field name on the target entity that owns this relationship |
| `cascade` | `List<RelationCascade>` | Operations to propagate to related entities |
| `fetch` | `RelationFetchStrategy` | Metadata for fetch strategy (eager/lazy) |

## Owning vs Inverse Side

Every bidirectional relationship has an **owning side** and an **inverse side**. The owning side is responsible for the foreign key or join table in the database.

### Rules

| Annotation | Owning Side | Notes |
|------------|-------------|-------|
| `@ManyToOne` | Always owning | Cannot use `mappedBy` |
| `@OneToMany` | Always inverse | Must specify `mappedBy` |
| `@OneToOne` | Configurable | Owning if no `mappedBy`; inverse if `mappedBy` is set |
| `@ManyToMany` | Configurable | Owning if no `mappedBy`; inverse if `mappedBy` is set |

### Example: Bidirectional One-to-Many

```dart
@EntityMeta(table: 'users')
class User extends Entity {
  @PrimaryKey(autoIncrement: true)
  final int id;

  @Column()
  final String email;

  // Inverse side - references the owning field on Post
  @OneToMany(on: Post, mappedBy: 'author')
  final List<Post> posts;

  User({required this.id, required this.email, this.posts = const []});
}

@EntityMeta(table: 'posts')
class Post extends Entity {
  @PrimaryKey(autoIncrement: true)
  final int id;

  @Column()
  final String title;

  // Owning side - holds the foreign key
  @ManyToOne(on: User)
  @JoinColumn(name: 'author_id')
  final User? author;

  Post({required this.id, required this.title, this.author});
}
```

In this example:
- `Post.author` is the **owning side** — the `author_id` column is stored in the `posts` table
- `User.posts` is the **inverse side** — it references `Post.author` via `mappedBy`

## Join Metadata

### @JoinColumn

Use `@JoinColumn` on the owning side of `@ManyToOne` or `@OneToOne` relationships to configure the foreign key column:

```dart
@ManyToOne(on: User)
@JoinColumn(name: 'user_id', referencedColumnName: 'id')
final User? user;
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `name` | `String` | Auto-generated | Column name for the foreign key |
| `referencedColumnName` | `String` | `'id'` | Column on the target entity |
| `nullable` | `bool` | `true` | Whether the column allows NULL |
| `unique` | `bool` | `false` | Whether to add a unique constraint |

If `@JoinColumn` is omitted, Loxia generates a default column name based on the field name.

### @JoinTable

Use `@JoinTable` on the owning side of `@ManyToMany` relationships to configure the join table:

```dart
@ManyToMany(on: Tag)
@JoinTable(
  name: 'post_tags',
  joinColumns: [JoinColumn(name: 'post_id', referencedColumnName: 'id')],
  inverseJoinColumns: [JoinColumn(name: 'tag_id', referencedColumnName: 'id')],
)
final List<Tag> tags;
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | `String` | Name of the join table |
| `joinColumns` | `List<JoinColumn>` | Columns referencing the owning entity |
| `inverseJoinColumns` | `List<JoinColumn>` | Columns referencing the target entity |

## Querying Relationships

Loxia automatically generates joins when you select relation fields. Use the generated `Select` and `Relations` classes:

```dart
final results = await postRepository.find(
  select: PostSelect(
    id: true,
    title: true,
    relations: PostRelations(
      author: UserSelect(id: true, email: true),
    ),
  ),
  where: PostQuery((q) => q.author.email.like('%@example.com')),
);
```

This query:
1. Joins `posts` to `users` on the `author_id` foreign key
2. Filters posts where the author's email matches the pattern
3. Returns `PostPartial` objects with nested `UserPartial` for the author

## Cascade Operations

Cascades automatically propagate operations from a parent entity to its related entities. Configure cascades using the `cascade` parameter:

```dart
@OneToMany(on: Post, mappedBy: 'author', cascade: [RelationCascade.persist, RelationCascade.remove])
final List<Post> posts;
```

### Available Cascade Types

| Cascade | Description |
|---------|-------------|
| `RelationCascade.persist` | Propagate insert operations |
| `RelationCascade.merge` | Propagate update operations |
| `RelationCascade.remove` | Propagate delete operations |
| `RelationCascade.all` | Enable all cascade types |

### Persist Cascade

When `persist` is enabled, inserting a parent entity automatically inserts related entities.

**Owning side** (e.g., `@ManyToOne`): The related entity is inserted first, then its primary key is used as the foreign key:

```dart
await postRepository.insert(
  PostInsertDto(
    title: 'Hello World',
    author: UserInsertDto(email: 'author@example.com'),
  ),
);
// 1. Inserts user, gets user ID
// 2. Inserts post with author_id = user ID
```

**Inverse side** (e.g., `@OneToMany`): The parent is inserted first, then its primary key is injected into children:

```dart
await userRepository.insert(
  UserInsertDto(
    email: 'author@example.com',
    posts: [
      PostInsertDto(title: 'First Post'),
      PostInsertDto(title: 'Second Post'),
    ],
  ),
);
// 1. Inserts user, gets user ID
// 2. Inserts each post with author_id = user ID
```

### Merge Cascade

When `merge` is enabled, updating a parent entity automatically updates related entities.

**Using `updateEntity()`:**

```dart
final user = await userRepository.findOneBy(where: UserQuery((q) => q.id.equals(1)));
user.posts[0].title = 'Updated Title';
await userRepository.updateEntity(user);
// Updates both the user and the modified post
```

**Using `update()` with DTOs:**

```dart
await userRepository.update(
  UserUpdateDto(
    email: 'new@email.com',
    posts: [PostUpdateDto(title: 'New Title')],
  ),
  where: UserQuery((q) => q.id.equals(1)),
);
// Updates user and all related posts
```

### Remove Cascade

When `remove` is enabled, deleting a parent entity automatically deletes related entities.

```dart
await userRepository.deleteEntity(user);
// 1. Deletes all posts where author_id = user.id
// 2. Deletes the user
```

**Execution order:**
- **Inverse-side relations**: Children are deleted before the parent
- **Owning-side relations**: Referenced entities are deleted after the parent

> **Warning:** Owning-side cascade remove can be dangerous. If multiple entities reference the same target, deleting one parent will delete the shared target, potentially causing issues for other references.

## ManyToMany Cascades

ManyToMany relationships use a join table to store associations. Cascade operations manage both the join table entries and optionally the target entities.

```
┌──────────┐       ┌────────────────┐       ┌──────────┐
│  posts   │──────▶│   post_tags    │◀──────│   tags   │
│  (id)    │       │ (post_id,      │       │  (id)    │
│          │       │  tag_id)       │       │          │
└──────────┘       └────────────────┘       └──────────┘
```

### Remove Cascade

Deleting an entity removes its join table entries (but not the target entities):

```dart
@ManyToMany(on: Tag, cascade: [RelationCascade.remove])
@JoinTable(name: 'post_tags', ...)
final List<Tag> tags;
```

```dart
await postRepository.deleteEntity(post);
// 1. DELETE FROM post_tags WHERE post_id = ?
// 2. DELETE FROM posts WHERE id = ?
// Tags remain in the database
```

### Persist Cascade

Inserting an entity can create new target entities and join table entries:

```dart
await postRepository.insert(
  PostInsertDto(
    title: 'My Post',
    tags: [
      TagInsertDto(name: 'dart'),  // New tag - inserted
      5,                            // Existing tag ID - linked only
    ],
  ),
);
// 1. INSERT INTO posts ... RETURNING id
// 2. INSERT INTO tags (name) VALUES ('dart') RETURNING id
// 3. INSERT INTO post_tags (post_id, tag_id) VALUES (?, ?)
// 4. INSERT INTO post_tags (post_id, tag_id) VALUES (?, 5)
```

### Merge Cascade

Updating synchronizes the join table with the current collection.

**Using `updateEntity()`:**

```dart
post.tags.add(newTag);
post.tags.removeAt(0);
await postRepository.updateEntity(post);
// Automatically adds/removes join table entries
```

**Using `update()` with `ManyToManyCascadeUpdate`:**

```dart
// Add tags
await postRepository.update(
  PostUpdateDto(tags: ManyToManyCascadeUpdate(add: [4, 5])),
  where: PostQuery((q) => q.id.equals(1)),
);

// Remove tags
await postRepository.update(
  PostUpdateDto(tags: ManyToManyCascadeUpdate(remove: [1, 2])),
  where: PostQuery((q) => q.id.equals(1)),
);

// Replace entire collection
await postRepository.update(
  PostUpdateDto(tags: ManyToManyCascadeUpdate(set: [3, 4, 5])),
  where: PostQuery((q) => q.id.equals(1)),
);
```

| Option | Description |
|--------|-------------|
| `add` | Add target IDs to the collection |
| `remove` | Remove target IDs from the collection |
| `set` | Replace the entire collection (ignores `add`/`remove`) |

## Quick Reference

### Relationship Types

| Relation | Owning Side | Requires `mappedBy` | Storage |
|----------|-------------|---------------------|---------|
| `@ManyToOne` | Always | No | Foreign key on current table |
| `@OneToMany` | Never | Yes | Foreign key on target table |
| `@OneToOne` | If no `mappedBy` | If inverse | Foreign key or join column |
| `@ManyToMany` | If no `mappedBy` | If inverse | Join table |

### Cascade Support

| Cascade | `@ManyToOne` | `@OneToMany` | `@OneToOne` | `@ManyToMany` |
|---------|--------------|--------------|-------------|---------------|
| `persist` | ✓ | ✓ | ✓ | ✓ |
| `merge` | ✓ | ✓ | ✓ | ✓ |
| `remove` | ✓ | ✓ | ✓ | ✓ |

All relationship types fully support all cascade operations.
