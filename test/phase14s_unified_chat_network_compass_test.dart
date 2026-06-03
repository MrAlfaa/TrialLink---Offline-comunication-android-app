import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:traillink/features/connectivity_intelligence/data/network_speed_probe_service.dart';

void main() {
  group('Phase 14S separated chat and Network Compass', () {
    test('primary chat routes keep online and nearby chat separate', () {
      final router = File('lib/app/router.dart').readAsStringSync();

      expect(router, contains('ChatScreen('));
      expect(router, contains('OfflineChatScreen('));
      expect(router, isNot(contains('UnifiedTripChatScreen(')));
      expect(router, isNot(contains('UnifiedOrCloudChatScreen(')));
    });

    test('cloud chat accepts auth access user after online bootstrap', () {
      final chatScreen = File('lib/features/chat/presentation/chat_screen.dart')
          .readAsStringSync();
      final modeController =
          File('lib/core/mode/mode_controller.dart').readAsStringSync();

      expect(chatScreen, contains('authAccessControllerProvider'));
      expect(chatScreen, contains('authState.user ?? authAccess.user'));
      expect(
        chatScreen,
        isNot(
          contains('final user = ref.watch(authControllerProvider).user;'),
        ),
      );
      expect(
        modeController,
        contains('setAuthenticatedUser(user)'),
      );
    });

    test('online cloud chat does not use offline label while reconnecting', () {
      final label = File(
        'lib/features/chat/presentation/chat_mode_label.dart',
      ).readAsStringSync();
      final chatScreen = File(
        'lib/features/chat/presentation/chat_screen.dart',
      ).readAsStringSync();

      expect(label, contains("'reconnecting' => 'Online Chat - connecting'"));
      expect(
        label,
        contains(
          "'disconnected' => 'Online Chat - waiting for connection'",
        ),
      );
      expect(label, isNot(contains("'reconnecting' => 'Offline Chat")));
      expect(label, isNot(contains("'disconnected' => 'Offline Chat")));
      expect(chatScreen, contains("label: 'Online paused'"));
      expect(chatScreen, contains("label: 'Saved locally'"));
    });

    test(
        'cloud socket uses mobile-safe transport fallback and awaitable connect',
        () {
      final socketService = File(
        'lib/features/chat/data/socket_service.dart',
      ).readAsStringSync();

      expect(socketService, contains("static const socketTransports"));
      expect(socketService, contains("'polling'"));
      expect(socketService, contains("'websocket'"));
      expect(socketService, contains('Completer<void>? _connectCompleter'));
      expect(socketService, contains('connect_timeout'));
      expect(socketService, contains('[TrailLink][Socket]'));
      expect(socketService, isNot(contains(".setTransports(['websocket'])")));
      expect(socketService, isNot(contains(r'token=$token')));
      expect(
        socketService.indexOf('_connectCompleter = completer'),
        lessThan(socketService.indexOf('await _storage.readToken()')),
      );
    });

    test('Network Compass uses local sample storage and self-hosted probe', () {
      final db =
          File('lib/core/database/local_database.dart').readAsStringSync();
      final probe = File(
        'lib/features/connectivity_intelligence/data/network_speed_probe_service.dart',
      ).readAsStringSync();
      final repo = File(
        'lib/features/connectivity_intelligence/data/network_compass_repository.dart',
      ).readAsStringSync();
      final screen = File(
        'lib/features/connectivity_intelligence/presentation/connectivity_guidance_screen.dart',
      ).readAsStringSync();

      expect(db, contains('version: 24'));
      expect(db, contains('network_speed_samples'));
      expect(probe, contains('/network/probe/ping'));
      expect(probe, contains('/network/probe/download'));
      expect(probe, isNot(contains('latitude')));
      expect(probe, isNot(contains('longitude')));
      expect(repo, contains('Geolocator.getCurrentPosition'));
      expect(repo, contains('NetworkSpeedSampleModel('));
      expect(screen, contains('Network Compass'));
      expect(screen, contains('Internet direction finder'));
      expect(screen, contains('Best internet spot nearby'));
      expect(screen, contains('Best Internet Spots'));
      expect(screen, contains('No internet measured here'));
    });

    test('speed calculation converts bytes and elapsed time to Mbps', () {
      final mbps = NetworkSpeedProbeService.calculateMbps(
        bytes: 262144,
        elapsed: const Duration(seconds: 1),
      );
      expect(mbps, closeTo(2.097, 0.01));
    });

    test('backend exposes capped probe endpoints without GPS handling', () {
      final app = File('backend/src/app.js').readAsStringSync();
      final route = File(
        'backend/src/modules/networkProbe/networkProbe.routes.js',
      ).readAsStringSync();

      expect(app, contains('/api/network/probe'));
      expect(route, contains("router.get('/ping'"));
      expect(route, contains("router.get('/download'"));
      expect(route, contains("router.post('/upload'"));
      expect(route, contains('maxDownloadBytes'));
      expect(route, contains('maxUploadBytes'));
      expect(route, isNot(contains('latitude')));
      expect(route, isNot(contains('longitude')));
    });
  });
}
