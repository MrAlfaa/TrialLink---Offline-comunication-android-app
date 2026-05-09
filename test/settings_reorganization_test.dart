import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:traillink/core/identity/local_identity_repository.dart';

void main() {
  test('settings source exposes profile editor and no broken technical actions',
      () {
    final source =
        File('lib/features/settings/presentation/settings_screen.dart')
            .readAsStringSync();

    expect(source, contains('class ProfileSettingsScreen'));
    expect(source, contains("context.go('/settings/profile')"));
    expect(source, isNot(contains("context.go('/home/status')")));
    expect(source, isNot(contains('onPressed: () {}')));
  });

  test('feature controls no longer expose duplicated voice and radio toggles',
      () {
    final source =
        File('lib/features/settings/presentation/settings_screen.dart')
            .readAsStringSync();
    final featureItems =
        source.substring(source.indexOf('const _featureItems'));

    expect(featureItems, isNot(contains("key: 'enable_voice_note_ptt'")));
    expect(featureItems, isNot(contains("key: 'enable_live_radio'")));
    expect(source, contains("_boolTile('voice_note_ptt_enabled'"));
    expect(source, contains("_boolTile('live_radio_enabled'"));
  });

  test('profile validation accepts optional blank email', () {
    expect(
      () => LocalIdentityRepository.validateProfileInput(
        displayName: 'Dhananjaya',
        email: '   ',
        emergencyNote: 'Blue jacket',
      ),
      returnsNormally,
    );
  });

  test('profile validation rejects bad display name, email, and long note', () {
    expect(
      () => LocalIdentityRepository.validateProfileInput(displayName: 'A'),
      throwsA(isA<StateError>()),
    );
    expect(
      () => LocalIdentityRepository.validateProfileInput(
        displayName: 'Dhananjaya',
        email: 'not-an-email',
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      () => LocalIdentityRepository.validateProfileInput(
        displayName: 'Dhananjaya',
        emergencyNote: 'x' * 201,
      ),
      throwsA(isA<StateError>()),
    );
  });
}
