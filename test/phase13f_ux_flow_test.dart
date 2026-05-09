import 'package:flutter_test/flutter_test.dart';
import 'package:traillink/core/mode/mode_models.dart';
import 'package:traillink/core/settings/app_settings_defaults.dart';
import 'package:traillink/features/app_lock/data/trail_pin_service.dart';

void main() {
  group('Phase 13F flow settings', () {
    test('adds unified identity, splash, and Auto/Manual mode keys', () {
      final keys = AppSettingsDefaults.byKey.keys;

      expect(keys, contains('mode_control_type'));
      expect(keys, contains('manual_communication_mode'));
      expect(keys, contains('identity_sync_state'));
      expect(keys, contains('identity_bootstrap_synced_at'));
      expect(keys, contains('splash_intro_seen'));
    });

    test('manual communication mode maps to existing internal user modes', () {
      expect(ManualCommunicationMode.online.userMode, UserMode.online);
      expect(ManualCommunicationMode.offline.userMode, UserMode.offline);
    });

    test('TrailLink PIN is exactly four digits', () {
      expect(TrailPinService.isValidPin('1234'), isTrue);
      expect(TrailPinService.isValidPin('123'), isFalse);
      expect(TrailPinService.isValidPin('12345'), isFalse);
      expect(TrailPinService.isValidPin('12a4'), isFalse);
    });
  });
}
