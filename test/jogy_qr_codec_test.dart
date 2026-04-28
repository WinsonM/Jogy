import 'package:flutter_test/flutter_test.dart';
import 'package:jogy_app/features/scan/services/jogy_qr_codec.dart';

void main() {
  group('JogyQrCodec', () {
    test('builds and parses user profile QR payloads', () {
      final payload = JogyQrCodec.userProfile('user-123');

      expect(payload, 'jogy://user/profile/user-123');

      final target = JogyQrCodec.parse(payload);
      expect(target, isNotNull);
      expect(target!.targetType, JogyQrCodec.userProfileType);
      expect(target.targetId, 'user-123');
      expect(target.isUserProfile, isTrue);
    });

    test('trims scanned payloads before parsing', () {
      final target = JogyQrCodec.parse('  jogy://user/profile/user-123\n');

      expect(target, isNotNull);
      expect(target!.targetId, 'user-123');
    });

    test('rejects non-navigable user profile payloads', () {
      expect(JogyQrCodec.parse('jogy://user/profile/unknown'), isNull);
      expect(() => JogyQrCodec.userProfile(' '), throwsArgumentError);
    });

    test('normalizes backend resolve responses', () {
      final target = JogyQrCodec.fromResolveResponse({
        'target_type': 'user_profile',
        'target_id': 123,
      });

      expect(target, isNotNull);
      expect(target!.targetType, JogyQrCodec.userProfileType);
      expect(target.targetId, '123');
    });
  });
}
