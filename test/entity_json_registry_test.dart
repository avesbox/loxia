import 'package:loxia/loxia.dart';
import 'package:test/test.dart';

void main() {
  group('EntityJsonRegistry decoders', () {
    test('decodes a registered custom JSON value', () {
      EntityJsonRegistry.registerDecoder<_RuntimePreferences>(
        (value) => _RuntimePreferences.fromJson(
          (value as Map).cast<String, dynamic>(),
        ),
      );

      final decoded = EntityJsonRegistry.decode<_RuntimePreferences>({
        'theme': 'dark',
      });

      expect(decoded.theme, 'dark');
      expect(
        EntityJsonRegistry.isDecoderRegistered(_RuntimePreferences),
        isTrue,
      );
    });

    test('decodes list entries using a registered custom decoder', () {
      EntityJsonRegistry.registerDecoder<_RuntimePreferenceItem>(
        (value) => _RuntimePreferenceItem.fromJson(
          (value as Map).cast<String, dynamic>(),
        ),
      );

      final decoded = [
        {'key': 'language'},
        {'key': 'timezone'},
      ].map(EntityJsonRegistry.decode<_RuntimePreferenceItem>).toList();

      expect(decoded.map((item) => item.key), ['language', 'timezone']);
    });
  });
}

final class _RuntimePreferences {
  const _RuntimePreferences({required this.theme});

  final String theme;

  factory _RuntimePreferences.fromJson(Map<String, dynamic> json) {
    return _RuntimePreferences(theme: json['theme'] as String);
  }
}

final class _RuntimePreferenceItem {
  const _RuntimePreferenceItem({required this.key});

  final String key;

  factory _RuntimePreferenceItem.fromJson(Map<String, dynamic> json) {
    return _RuntimePreferenceItem(key: json['key'] as String);
  }
}
