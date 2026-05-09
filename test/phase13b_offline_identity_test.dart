import 'package:flutter_test/flutter_test.dart';
import 'package:traillink/core/database/local_database.dart';
import 'package:traillink/core/identity/auth_access_state.dart';
import 'package:traillink/core/identity/local_identity_model.dart';
import 'package:traillink/core/settings/settings_service.dart';
import 'package:traillink/core/setup/setup_progress_service.dart';
import 'package:traillink/features/trip/data/trip_session_model.dart';
import 'package:traillink/features/trip/data/trip_session_repository.dart';

void main() {
  test('setup progress returns the next incomplete setup route', () async {
    final settings = _FakeSettingsService();
    final progress = SetupProgressService(settings);

    expect(await progress.getNextSetupRoute(), '/setup/agreement');

    await progress.markAgreementAccepted();
    expect(await progress.getNextSetupRoute(), '/setup/identity');

    await progress.markIdentityConfigured();
    expect(await progress.getNextSetupRoute(), '/setup/mode');

    await progress.markModeConfigured();
    expect(await progress.getNextSetupRoute(), '/setup/features');

    await progress.markFeaturePreferencesConfigured();
    expect(await progress.getNextSetupRoute(), '/setup/security');

    await progress.markSecurityPreferencesConfigured();
    expect(await progress.getNextSetupRoute(), '/setup/trip');

    await progress.markTripConfigured();
    expect(await progress.getNextSetupRoute(), '/setup/permissions');
  });

  test('auth access state separates backend access from app shell access', () {
    expect(AuthAccessState.authenticatedOnline.canOpenAppShell, isTrue);
    expect(AuthAccessState.authenticatedOnline.canUseBackendFeatures, isTrue);
    expect(AuthAccessState.authenticatedOfflineCached.canOpenAppShell, isTrue);
    expect(
      AuthAccessState.authenticatedOfflineCached.canUseBackendFeatures,
      isFalse,
    );
    expect(AuthAccessState.guestOffline.canOpenAppShell, isTrue);
    expect(AuthAccessState.guestOffline.canUseBackendFeatures, isFalse);
    expect(AuthAccessState.unauthenticated.canOpenAppShell, isFalse);
  });

  test('local identity model maps guest database rows', () {
    final identity = LocalIdentityModel.fromDb({
      'id': 1,
      'local_user_id': 'local_123',
      'public_user_id': 'UID-202605080001',
      'cloud_user_id': 'cloud_123',
      'display_name': 'Asha',
      'identity_type': 'local_only',
      'created_offline': 1,
      'cloud_status': 'cloud_ready',
      'sync_state': 'synced',
      'last_cloud_sync_at': '2026-05-06T11:00:00.000',
      'created_at': '2026-05-06T10:00:00.000',
    });

    expect(identity.localUserId, 'local_123');
    expect(identity.publicUserId, 'UID-202605080001');
    expect(identity.cloudUserId, 'cloud_123');
    expect(identity.displayName, 'Asha');
    expect(identity.isLocalOnly, isTrue);
    expect(identity.isCloudReady, isTrue);
    expect(identity.syncState, 'synced');
    expect(identity.createdOffline, isTrue);
  });

  test('trip session model maps active offline trip rows', () {
    final trip = TripSessionModel.fromDb({
      'id': 1,
      'trip_id': 'trip-1',
      'trip_name': 'Knuckles Hike',
      'mode': 'offline',
      'offline_channel_id': 'channel-1',
      'channel_code': 'TL-OFF-8K2P',
      'local_identity_id': 'guest_123',
      'status': 'active',
      'started_at': '2026-05-06T10:00:00.000',
      'sync_state': 'local_only',
      'created_at': '2026-05-06T10:00:00.000',
    });

    expect(trip.isActive, isTrue);
    expect(trip.isOffline, isTrue);
    expect(trip.channelCode, 'TL-OFF-8K2P');
  });

  test(
      'trip repository normalizes valid channel codes and rejects invalid ones',
      () {
    final repository = TripSessionRepository();

    expect(repository.normalizeChannelCode('tl-off-8k2p'), 'TL-OFF-8K2P');
    expect(
      () => repository.normalizeChannelCode('bad code!'),
      throwsA(isA<StateError>()),
    );
  });
}

class _FakeSettingsService extends SettingsService {
  _FakeSettingsService() : super(LocalDatabase.instance);

  final Map<String, String> _values = {};

  @override
  Future<bool> getBool(String key, bool defaultValue) async {
    return (_values[key] ?? (defaultValue ? 'true' : 'false')) == 'true';
  }

  @override
  Future<void> setBool(String key, bool value) async {
    _values[key] = value ? 'true' : 'false';
  }

  @override
  Future<String> getString(String key, String defaultValue) async {
    return _values[key] ?? defaultValue;
  }

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }
}
