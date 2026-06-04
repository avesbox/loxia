import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:loxia/builder.dart';
import 'package:test/test.dart';

void main() {
  test(
    'generates fromJson-based hydration for custom json column types',
    () async {
      final readerWriter = await _createReaderWriter();

      await testBuilder(
        entityDescriptorBuilder(BuilderOptions.empty),
        {'loxia|lib/json_decoder_generation_input.dart': _entitySource},
        rootPackage: 'loxia',
        outputs: {
          'loxia|lib/json_decoder_generation_input.loxia.g.part': decodedMatches(
            allOf([
              contains('fromRow: (row) => User('),
              contains("phone: row['phone'] == null"),
              contains("decodeJsonColumn(row['phone'])"),
              contains(
                'factory UserInsertDto.fromMap(Map<String, dynamic> map)',
              ),
              contains("map['phone'] is String"),
              contains("decodeJsonColumn(map['phone'])"),
              contains(
                'UserPartial hydrate(Map<String, dynamic> row, {String? path})',
              ),
              contains("decodeJsonColumn(readValue(row, 'phone', path: path))"),
              contains('PhoneModel.fromJson('),
            ]),
          ),
        },
        readerWriter: readerWriter,
      );
    },
  );

  test(
    'generates registry-based hydration for custom json column types and lists',
    () async {
      final readerWriter = await _createReaderWriter();

      await testBuilder(
        entityDescriptorBuilder(BuilderOptions.empty),
        {'loxia|lib/json_registry_decoder_input.dart': _registryEntitySource},
        rootPackage: 'loxia',
        outputs: {
          'loxia|lib/json_registry_decoder_input.loxia.g.part': decodedMatches(
            allOf([
              contains('EntityJsonRegistry.decode<Preferences>('),
              contains('EntityJsonRegistry.decode<PreferenceItem>(entry)'),
              contains("decodeJsonColumn(row['preferences'])"),
              contains("decodeJsonColumn(row['items'])"),
              contains(
                'factory UserInsertDto.fromMap(Map<String, dynamic> map)',
              ),
              contains("decodeJsonColumn(map['preferences'])"),
              contains("decodeJsonColumn(map['items'])"),
              contains(
                'UserPartial hydrate(Map<String, dynamic> row, {String? path})',
              ),
            ]),
          ),
        },
        readerWriter: readerWriter,
      );
    },
  );
}

Future<TestReaderWriter> _createReaderWriter() async {
  final readerWriter = TestReaderWriter(rootPackage: 'loxia');
  await readerWriter.testing.loadIsolateSources();
  return readerWriter;
}

const String _entitySource = r'''
import 'package:loxia/loxia.dart';

part 'json_decoder_generation_input.g.dart';

class PhoneModel {
  final String? code;
  final String? number;

  const PhoneModel({this.code, this.number});

  factory PhoneModel.fromJson(Map<String, dynamic> json) {
    return PhoneModel(
      code: json['code'] as String?,
      number: json['number'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {'code': code, 'number': number};
}

@EntityMeta(table: 'users')
class User extends Entity {
  @PrimaryKey(uuid: true)
  @Column()
  final String id;

  @Column(type: ColumnType.json)
  final PhoneModel? phone;

  const User({required this.id, this.phone});
}
''';

const String _registryEntitySource = r'''
import 'package:loxia/loxia.dart';

part 'json_registry_decoder_input.g.dart';

class Preferences {
  final String theme;

  const Preferences({required this.theme});

  Map<String, dynamic> toJson() => {'theme': theme};
}

class PreferenceItem {
  final String key;

  const PreferenceItem({required this.key});

  Map<String, dynamic> toJson() => {'key': key};
}

@EntityMeta(table: 'users')
class User extends Entity {
  @PrimaryKey(uuid: true)
  @Column()
  final String id;

  @Column(type: ColumnType.json)
  final Preferences preferences;

  @Column(type: ColumnType.json)
  final List<PreferenceItem> items;

  const User({
    required this.id,
    required this.preferences,
    required this.items,
  });
}
''';
