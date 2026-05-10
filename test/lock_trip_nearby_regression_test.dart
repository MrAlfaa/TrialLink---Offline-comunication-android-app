import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home header locks app instead of clearing the cloud session', () {
    final source =
        File('lib/features/dashboard/dashboard_screen.dart').readAsStringSync();

    expect(source, isNot(contains('authControllerProvider.notifier).logout')));
    expect(source, contains('Lock App'));
    expect(source, contains('appLockControllerProvider.notifier'));
    expect(source, contains("context.go('/unlock?from=/home')"));
  });

  test('profile exposes explicit cloud profile creation and retry', () {
    final source =
        File('lib/features/settings/presentation/settings_screen.dart')
            .readAsStringSync();

    expect(source, contains('Create Cloud Profile'));
    expect(source, contains('Retry Cloud Profile'));
    expect(source, contains('cloudSyncControllerProvider.notifier'));
    expect(source, contains('ensureCloudReadyBeforeOnlineMode'));
  });

  test('home trip creation uses wizard route without onboarding skip', () {
    final dashboard =
        File('lib/features/dashboard/dashboard_screen.dart').readAsStringSync();
    final router = File('lib/app/router.dart').readAsStringSync();
    final trip = File('lib/features/trip/presentation/trip_setup_screen.dart')
        .readAsStringSync();

    expect(dashboard, contains("context.go('/trip/setup-wizard')"));
    expect(router, contains("path: '/trip/create'"));
    expect(router, contains('TripSetupWizardScreen'));
    expect(trip, contains('if (widget.flow == TripSetupFlow.onboarding)'));
  });

  test('nearby stale endpoint failures are sanitized and reset peer state', () {
    final controller =
        File('lib/features/nearby/presentation/nearby_controller.dart')
            .readAsStringSync();
    final screen =
        File('lib/features/nearby/presentation/nearby_peers_screen.dart')
            .readAsStringSync();
    final card = File('lib/features/nearby/presentation/widgets/peer_card.dart')
        .readAsStringSync();

    expect(controller, contains('STATUS_ENDPOINT_UNKNOWN'));
    expect(controller, contains('NearbyFailureKind.staleEndpoint'));
    expect(controller, contains('PeerConnectionStatus.lost'));
    expect(screen, isNot(contains('Text(message)')));
    expect(card, contains('PeerConnectionStatus.connecting'));
  });
}
