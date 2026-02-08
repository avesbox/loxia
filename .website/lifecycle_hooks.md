# Lifecycle Hooks

Lifecycle hooks allow you to execute custom logic at specific points during an entity's lifecycle. Use hooks to implement validation, auditing, computed fields, or any business logic that should run automatically when entities are loaded, saved, updated, or deleted.

## Overview

Loxia provides seven lifecycle hook annotations:

| Hook | Triggered When |
|------|----------------|
| `@PrePersist` | Before a new entity is inserted |
| `@PostPersist` | After a new entity is inserted |
| `@PreUpdate` | Before an existing entity is updated |
| `@PostUpdate` | After an existing entity is updated |
| `@PreRemove` | Before an entity is deleted |
| `@PostRemove` | After an entity is deleted |
| `@PostLoad` | After an entity is loaded from the database |

## Defining Hooks

Add hook annotations to methods in your entity class. Methods must be instance methods (not static) and should not return a value that needs to be awaited.

```dart
@EntityMeta(table: 'users')
class User extends Entity {
  @PrimaryKey(autoIncrement: true)
  final int id;

  @Column()
  final String email;

  @Column()
  String? normalizedEmail;

  @Column()
  DateTime? createdAt;

  @Column()
  DateTime? updatedAt;

  User({
    required this.id,
    required this.email,
    this.normalizedEmail,
    this.createdAt,
    this.updatedAt,
  });

  @PrePersist
  void onPrePersist() {
    normalizedEmail = email.toLowerCase().trim();
    createdAt = DateTime.now();
  }

  @PreUpdate
  void onPreUpdate() {
    normalizedEmail = email.toLowerCase().trim();
    updatedAt = DateTime.now();
  }

  @PostLoad
  void onPostLoad() {
    // Initialize transient fields or validate loaded data
  }
}
```

## Hook Descriptions

### @PrePersist

Executes before a new entity is inserted into the database. Use this hook to:

- Set default values
- Normalize data
- Generate computed fields
- Validate entity state before insert

```dart
@PrePersist
void beforeInsert() {
  slug = title.toLowerCase().replaceAll(' ', '-');
  createdAt = DateTime.now();
}
```

### @PostPersist

Executes after a new entity is successfully inserted. Use this hook to:

- Trigger notifications
- Log creation events
- Update related caches

```dart
@PostPersist
void afterInsert() {
  print('Created new user with ID: $id');
}
```

### @PreUpdate

Executes before an existing entity is updated. Use this hook to:

- Update timestamp fields
- Recalculate computed values
- Validate changes

```dart
@PreUpdate
void beforeUpdate() {
  updatedAt = DateTime.now();
  version += 1;
}
```

### @PostUpdate

Executes after an entity is successfully updated. Use this hook to:

- Trigger change notifications
- Invalidate caches
- Log modifications

```dart
@PostUpdate
void afterUpdate() {
  print('User $id was updated at $updatedAt');
}
```

### @PreRemove

Executes before an entity is deleted. Use this hook to:

- Perform cleanup operations
- Validate deletion is allowed
- Archive data before removal

```dart
@PreRemove
void beforeDelete() {
  // Archive to a separate table or log
  print('About to delete user: $email');
}
```

### @PostRemove

Executes after an entity is successfully deleted. Use this hook to:

- Clean up related resources
- Send notifications
- Update statistics

```dart
@PostRemove
void afterDelete() {
  print('User $email has been deleted');
}
```

### @PostLoad

Executes after an entity is loaded from the database. Use this hook to:

- Initialize transient (non-persisted) fields
- Deserialize complex data
- Validate loaded state

```dart
@PostLoad
void afterLoad() {
  // Parse JSON stored in a text column
  if (metadataJson != null) {
    metadata = jsonDecode(metadataJson);
  }
}
```

## Multiple Hooks

You can define multiple methods for the same hook, and a single method can have multiple hook annotations:

```dart
@EntityMeta(table: 'articles')
class Article extends Entity {
  // ...

  @PrePersist
  @PreUpdate
  void normalizeContent() {
    slug = title.toLowerCase().replaceAll(' ', '-');
    excerpt = content.substring(0, min(200, content.length));
  }

  @PrePersist
  void setCreatedAt() {
    createdAt = DateTime.now();
  }

  @PreUpdate
  void setUpdatedAt() {
    updatedAt = DateTime.now();
  }
}
```

## Hook Execution Context

Hooks execute within the same transaction as the database operation:

- If a hook throws an exception, the entire operation is rolled back
- Hooks have access to the current entity state
- Changes made in `@Pre*` hooks are persisted with the operation

```dart
@PrePersist
void validate() {
  if (email.isEmpty) {
    throw ValidationException('Email cannot be empty');
  }
}
```

## Best Practices

1. **Keep hooks lightweight** — Avoid long-running operations that could slow down database transactions

2. **Don't perform database queries** — Hooks don't have direct access to repositories; use cascade operations for related entities

3. **Use appropriate hooks** — Choose `@Pre*` hooks for data modification, `@Post*` hooks for side effects

4. **Handle exceptions carefully** — Exceptions in hooks will abort the operation and rollback the transaction

5. **Avoid circular dependencies** — Don't modify related entities in ways that could trigger infinite loops

## Quick Reference

| Hook | Timing | Use Case |
|------|--------|----------|
| `@PrePersist` | Before INSERT | Set defaults, validate, compute fields |
| `@PostPersist` | After INSERT | Notifications, logging |
| `@PreUpdate` | Before UPDATE | Update timestamps, validate changes |
| `@PostUpdate` | After UPDATE | Notifications, cache invalidation |
| `@PreRemove` | Before DELETE | Validation, archival |
| `@PostRemove` | After DELETE | Cleanup, notifications |
| `@PostLoad` | After SELECT | Initialize transient fields, deserialize |
