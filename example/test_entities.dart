import 'package:loxia/loxia.dart';

part 'test_entities.g.dart';

/// Test entity with non-nullable FK - reproduces issue #4
@EntityMeta(table: 'todos')
class TodoWithNonNullableOwner extends Entity {
  @PrimaryKey(autoIncrement: true)
  final int? id;

  @Column()
  final String title;

  @ManyToOne(on: User)
  @JoinColumn(name: 'owner_id', nullable: false)
  final User? owner;

  const TodoWithNonNullableOwner({this.id, required this.title, this.owner});

  static EntityDescriptor<
    TodoWithNonNullableOwner,
    TodoWithNonNullableOwnerPartial
  >
  get entity => $TodoWithNonNullableOwnerEntityDescriptor;
}

/// Test entity with nullable FK - for comparison
@EntityMeta(table: 'comments')
class CommentWithNullablePost extends Entity {
  @PrimaryKey(autoIncrement: true)
  final int? id;

  @Column()
  final String content;

  @ManyToOne(on: Post)
  @JoinColumn(name: 'post_id', nullable: true)
  final Post? post;

  const CommentWithNullablePost({this.id, required this.content, this.post});

  static EntityDescriptor<
    CommentWithNullablePost,
    CommentWithNullablePostPartial
  >
  get entity => $CommentWithNullablePostEntityDescriptor;
}

/// Supporting entity for TodoWithNonNullableOwner
@EntityMeta(table: 'users')
class User extends Entity {
  @PrimaryKey(autoIncrement: true)
  final int id;

  @Column()
  final String name;

  const User({required this.id, required this.name});

  static EntityDescriptor<User, UserPartial> get entity =>
      $UserEntityDescriptor;
}

/// Supporting entity for CommentWithNullablePost
@EntityMeta(table: 'posts')
class Post extends Entity {
  @PrimaryKey(autoIncrement: true)
  final int id;

  @Column()
  final String title;

  const Post({required this.id, required this.title});

  static EntityDescriptor<Post, PostPartial> get entity =>
      $PostEntityDescriptor;
}
