import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:loxia/builder.dart';
import 'package:test/test.dart';

void main() {
  group('inherited entity generation', () {
    test(
      'includes inherited annotated fields in generated partials and DTOs',
      () async {
        final readerWriter = await _createReaderWriter();

        await testBuilder(
          entityDescriptorBuilder(BuilderOptions.empty),
          {'loxia|lib/inheritance_generation_input.dart': _entitySource},
          rootPackage: 'loxia',
          outputs: {
            'loxia|lib/inheritance_generation_input.loxia.g.part': decodedMatches(
              allOf([
                contains(
                  r'final EntityDescriptor<Product, ProductPartial> $ProductEntityDescriptor',
                ),
                contains('class ProductPartial extends PartialEntity<Product>'),
                contains('this.id,'),
                contains('this.version,'),
                contains('this.createdAt,'),
                contains('this.updatedAt,'),
                contains('this.deletedAt,'),
                contains("if (id == null) missing.add('id');"),
                contains("if (version == null) missing.add('version');"),
                contains("if (createdAt == null) missing.add('createdAt');"),
                contains("if (updatedAt == null) missing.add('updatedAt');"),
                contains('return Product('),
                contains('id: id!,'),
                contains('version: version!,'),
                contains('createdAt: createdAt!,'),
                contains('updatedAt: updatedAt!,'),
                contains('deletedAt: deletedAt,'),
              ]),
            ),
          },
          readerWriter: readerWriter,
        );
      },
    );

    test('includes inherited annotated fields in schema snapshots', () async {
      final readerWriter = await _createReaderWriter();

      await testBuilder(
        schemaSnapshotBuilder(BuilderOptions.empty),
        {
          'loxia|pubspec.yaml': 'name: loxia\n',
          'loxia|lib/inheritance_generation_input.dart': _entitySource,
        },
        rootPackage: 'loxia',
        outputs: {
          'loxia|.loxia/schema_v1.json': decodedMatches(
            allOf([
              contains('"products"'),
              contains('"id"'),
              contains('"version"'),
              contains('"created_at"'),
              contains('"updated_at"'),
              contains('"deleted_at"'),
              contains('"name"'),
              contains('"price"'),
            ]),
          ),
        },
        readerWriter: readerWriter,
      );
    });

    test('supports utc timestamp annotations in generated code', () async {
      final readerWriter = await _createReaderWriter();

      await testBuilder(
        entityDescriptorBuilder(BuilderOptions.empty),
        {'loxia|lib/inheritance_generation_input.dart': _utcEntitySource},
        rootPackage: 'loxia',
        outputs: {
          'loxia|lib/inheritance_generation_input.loxia.g.part': decodedMatches(
            allOf([
              contains("propertyName: 'createdAt'"),
              contains("propertyName: 'updatedAt'"),
              contains("propertyName: 'deletedAt'"),
              contains('e.createdAt = DateTime.now().toUtc();'),
              contains('e.updatedAt = DateTime.now().toUtc();'),
              contains('useUtcForTimestamp: true'),
            ]),
          ),
        },
        readerWriter: readerWriter,
      );
    });

    test('resolves inherited primary keys for relation targets', () async {
      final readerWriter = await _createReaderWriter();

      await testBuilder(
        entityDescriptorBuilder(BuilderOptions.empty),
        {'loxia|lib/inheritance_generation_input.dart': _relationEntitySource},
        rootPackage: 'loxia',
        outputs: {
          'loxia|lib/inheritance_generation_input.loxia.g.part': decodedMatches(
            allOf([
              contains('this.accountId,'),
              contains(
                "QueryField<String?> get accountId => field<String?>(\'account_id\');",
              ),
              contains("'account_id': e.account?.id"),
            ]),
          ),
        },
        readerWriter: readerWriter,
      );
    });
  });
}

Future<TestReaderWriter> _createReaderWriter() async {
  final readerWriter = TestReaderWriter(rootPackage: 'loxia');
  await readerWriter.testing.loadIsolateSources();
  return readerWriter;
}

const String _entitySource = r'''
import 'package:loxia/loxia.dart';

part 'inheritance_generation_input.g.dart';

abstract class SyncEntity extends Entity {
  @PrimaryKey(uuid: true)
  final String id;

  @Column(defaultValue: 0)
  final int version;

  @CreatedAt()
  final DateTime createdAt;

  @UpdatedAt()
  final DateTime updatedAt;

  @DeletedAt()
  final DateTime? deletedAt;

  const SyncEntity({
    required this.id,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
}

@EntityMeta(table: 'products')
class Product extends SyncEntity {
  @Column()
  final String name;

  @Column()
  final double price;

  const Product({
    required super.id,
    required super.version,
    required super.createdAt,
    required super.updatedAt,
    super.deletedAt,
    required this.name,
    required this.price,
  });
}
''';

const String _utcEntitySource = r'''
import 'package:loxia/loxia.dart';

part 'inheritance_generation_input.g.dart';

@EntityMeta(table: 'events')
class Event extends Entity {
  @PrimaryKey(uuid: true)
  final String id;

  @CreatedAt(utc: true)
  DateTime? createdAt;

  @UpdatedAt(utc: true)
  DateTime? updatedAt;

  @DeletedAt(utc: true)
  DateTime? deletedAt;

  Event({required this.id, this.createdAt, this.updatedAt, this.deletedAt});
}
''';

const String _relationEntitySource = r'''
import 'package:loxia/loxia.dart';

part 'inheritance_generation_input.g.dart';

abstract class BaseRecord extends Entity {
  @PrimaryKey(uuid: true)
  final String id;

  const BaseRecord({required this.id});
}

@EntityMeta(table: 'accounts')
class Account extends BaseRecord {
  @Column()
  final String email;

  const Account({required super.id, required this.email});
}

@EntityMeta(table: 'users')
class User extends Entity {
  @PrimaryKey(uuid: true)
  final String id;

  @ManyToOne(on: Account)
  Account? account;

  User({required this.id, this.account});
}
''';
