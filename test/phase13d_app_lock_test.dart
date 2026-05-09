import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

import 'package:traillink/features/app_lock/data/app_lock_repository.dart';
import 'package:traillink/features/app_lock/data/app_lock_secure_storage.dart';
import 'package:traillink/features/app_lock/data/models/app_lock_state.dart';
import 'package:traillink/features/app_lock/data/models/app_lock_status.dart';
import 'package:traillink/features/app_lock/data/trail_pin_service.dart';
import 'package:traillink/features/auth/data/models/user_model.dart';
import 'package:traillink/features/emergency/data/emergency_packet_service.dart';
import 'package:traillink/features/emergency/data/models/emergency_event_model.dart';
import 'package:traillink/features/offline_channel/data/models/offline_channel_model.dart';

void main() {
  group('Phase 13D PIN security', () {
    test('PIN validation accepts exactly 4 numeric digits', () {
      expect(TrailPinService.isValidPin('1234'), isTrue);
      expect(TrailPinService.isValidPin('123456'), isFalse);
      expect(TrailPinService.isValidPin('123'), isFalse);
      expect(TrailPinService.isValidPin('1234567'), isFalse);
      expect(TrailPinService.isValidPin('12a4'), isFalse);
      expect(TrailPinService.isValidPin(''), isFalse);
    });

    test('PIN hash uses salt and never equals plain PIN', () {
      final first = TrailPinService.hashPin(pin: '123456', salt: 'salt-one');
      final second = TrailPinService.hashPin(pin: '123456', salt: 'salt-two');

      expect(first, isNot('123456'));
      expect(second, isNot('123456'));
      expect(first, isNot(second));
      expect(TrailPinService.constantTimeEquals(first, first), isTrue);
      expect(TrailPinService.constantTimeEquals(first, second), isFalse);
    });

    test('configured PIN verifies correct value and rejects wrong value',
        () async {
      final storage = _MemoryAppLockSecureStorage();
      final service = TrailPinService(storage: storage);

      await service.configurePin('2468');

      expect(await service.hasPin(), isTrue);
      expect(storage.hash, isNot('2468'));
      expect(await service.verifyPin('2468'), isTrue);
      expect(await service.verifyPin('1357'), isFalse);
    });
  });

  group('Phase 13D lock decisions', () {
    test('timeout parsing handles supported labels', () {
      expect(AppLockRepository.parseTimeout('immediately'), Duration.zero);
      expect(
        AppLockRepository.parseTimeout('30 seconds'),
        const Duration(seconds: 30),
      );
      expect(
        AppLockRepository.parseTimeout('1 minute'),
        const Duration(minutes: 1),
      );
      expect(
        AppLockRepository.parseTimeout('5 minutes'),
        const Duration(minutes: 5),
      );
      expect(
        AppLockRepository.parseTimeout('15 minutes'),
        const Duration(minutes: 15),
      );
    });

    test('resume lock decision uses background timestamp and timeout', () {
      final now = DateTime.utc(2026, 5, 6, 12);
      expect(
        AppLockRepository.shouldLockOnResume(
          appLockEnabled: true,
          lastBackgroundedAt: now.subtract(const Duration(seconds: 31)),
          timeout: const Duration(seconds: 30),
          now: now,
        ),
        isTrue,
      );
      expect(
        AppLockRepository.shouldLockOnResume(
          appLockEnabled: true,
          lastBackgroundedAt: now.subtract(const Duration(seconds: 10)),
          timeout: const Duration(seconds: 30),
          now: now,
        ),
        isFalse,
      );
      expect(
        AppLockRepository.shouldLockOnResume(
          appLockEnabled: false,
          lastBackgroundedAt: now.subtract(const Duration(minutes: 5)),
          timeout: const Duration(seconds: 30),
          now: now,
        ),
        isFalse,
      );
    });

    test('recent unlock grace prevents biometric prompt resume relock', () {
      final now = DateTime.utc(2026, 5, 9, 10, 30);
      expect(
        AppLockRepository.shouldSkipResumeRelock(
          unlockInProgress: false,
          lastUnlockCompletedAt: now.subtract(const Duration(seconds: 2)),
          now: now,
          grace: const Duration(seconds: 3),
        ),
        isTrue,
      );
      expect(
        AppLockRepository.shouldSkipResumeRelock(
          unlockInProgress: false,
          lastUnlockCompletedAt: now.subtract(const Duration(seconds: 4)),
          now: now,
          grace: const Duration(seconds: 3),
        ),
        isFalse,
      );
      expect(
        AppLockRepository.shouldSkipResumeRelock(
          unlockInProgress: true,
          lastUnlockCompletedAt: null,
          now: now,
          grace: const Duration(seconds: 3),
        ),
        isTrue,
      );
    });

    test('lock state marks private UI locked for locked and setupRequired', () {
      expect(
        AppLockState.initial().copyWith(status: AppLockStatus.locked).isLocked,
        isTrue,
      );
      expect(
        AppLockState.initial()
            .copyWith(status: AppLockStatus.setupRequired)
            .isLocked,
        isTrue,
      );
      expect(
        AppLockState.initial()
            .copyWith(status: AppLockStatus.unlocked)
            .isLocked,
        isFalse,
      );
    });
  });

  group('Phase 13D app-lock routing integration', () {
    test('router refreshes redirects when app lock state changes', () {
      final routerSource = File('lib/app/router.dart').readAsStringSync();

      expect(routerSource, contains('refreshListenable:'));
      expect(routerSource, contains('appLockControllerProvider'));
    });

    test('splash initializes app lock before private route decision', () {
      final splashSource =
          File('lib/features/splash/splash_screen.dart').readAsStringSync();

      expect(
        splashSource,
        contains('read(appLockControllerProvider.notifier).initialize()'),
      );
    });

    test('setup security handoff syncs app lock controller before PIN setup',
        () {
      final setupSource =
          File('lib/features/setup/presentation/setup_screens.dart')
              .readAsStringSync();

      expect(setupSource, contains('appLockControllerProvider.notifier'));
      expect(
        setupSource,
        contains('enableAppLock()'),
      );
    });
  });

  group('Phase 13D locked SOS policy', () {
    test('SOS packet omits location when no coordinates are attached', () {
      final packet = EmergencyPacketService().createSosPacket(
        channel: OfflineChannelModel(
          channelId: 'channel-1',
          channelCode: 'TL-OFF-8K2P',
          channelName: 'Demo Channel',
          createdByUserId: 'guest-1',
          createdAt: DateTime.utc(2026),
        ),
        user: const UserModel(
          id: 'guest-1',
          fullName: 'Guest Explorer',
          email: '',
        ),
        event: EmergencyEventModel(
          localEventId: 'event-1',
          offlineChannelId: 'channel-1',
          channelCode: 'TL-OFF-8K2P',
          alertType: 'sos',
          message: 'Need help',
          priority: 'emergency',
          status: 'pending',
          deliveryMode: 'offline',
          ackStatus: 'waiting',
          retryCount: 0,
          createdAt: DateTime.utc(2026),
          syncState: 'local_only',
        ),
      );

      expect(packet.packetType, 'sos');
      expect(packet.payload.containsKey('location'), isFalse);
      expect(packet.priority, 'emergency');
    });
  });
}

class _MemoryAppLockSecureStorage extends AppLockSecureStorage {
  String? hash;
  String? salt;

  @override
  Future<String?> readPinHash() async => hash;

  @override
  Future<String?> readPinSalt() async => salt;

  @override
  Future<void> writePin({
    required String hash,
    required String salt,
  }) async {
    this.hash = hash;
    this.salt = salt;
  }

  @override
  Future<void> clearPin() async {
    hash = null;
    salt = null;
  }

  @override
  Future<bool> hasPin() async {
    return hash != null && hash!.isNotEmpty && salt != null && salt!.isNotEmpty;
  }
}
