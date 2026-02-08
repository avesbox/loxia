---
title: Loxia - Lightweight ORM for Dart
titleTemplate: false
layout: page
sidebar: false
---

<script setup>
  import Home from './components/home/home.vue';
</script>

<Home>
  <template #start>

```dart
part 'user.g.dart';

@EntityMeta()
class User extends Entity{
  @PrimaryKey()
  final int id;

  @Column()
  final String name;

  @Column()
  final String email;

  User(this.id, this.name, this.email);

  static EntityDescriptor<User, UserPartial> get entity => 
    $UserEntityDescriptor;
}
```

  </template>
</Home>
