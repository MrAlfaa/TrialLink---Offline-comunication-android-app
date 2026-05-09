import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trip wizard routes and help routes are registered', () {
    final router = File('lib/app/router.dart').readAsStringSync();

    expect(router, contains("path: '/trip/setup-wizard'"));
    expect(router, contains('TripSetupWizardScreen'));
    expect(router, contains("path: '/help/how-it-works'"));
    expect(router, contains('HowTrailLinkWorksScreen'));
    expect(router, contains("path: '/help/manual-test'"));
    expect(router, contains('ManualTestGuideScreen'));
  });

  test('home no-trip state guides users to start or join a trip first', () {
    final source =
        File('lib/features/dashboard/dashboard_screen.dart').readAsStringSync();

    expect(source, contains('No Active Trip'));
    expect(source, contains('Start Trip'));
    expect(source, contains('Join Trip'));
    expect(source, contains('How TrailLink Works'));
    expect(source, contains("context.go('/trip/setup-wizard')"));
    expect(source, contains("context.go('/trip/setup-wizard?intent=join')"));
  });

  test('messages hub prompts for a trip before showing chat choices', () {
    final source = File('lib/features/chat/presentation/chat_hub_screen.dart')
        .readAsStringSync();

    expect(source, contains('activeTripProvider'));
    expect(source, contains('Create or join a trip first'));
    expect(source, contains('Cloud Chat'));
    expect(source, contains('Offline Channel Chat'));
    expect(source, contains('Channel Details'));
  });

  test('trip repository exposes intent-level wizard methods', () {
    final source = File('lib/features/trip/data/trip_session_repository.dart')
        .readAsStringSync();

    expect(source, contains('createCloudBackupTrip'));
    expect(source, contains('createOfflineOnlyTrip'));
    expect(source, contains('joinExistingTrip'));
    expect(source, contains("mode: 'hybrid'"));
  });

  test('wizard includes five guided steps and stores guidance flags', () {
    final source =
        File('lib/features/trip/presentation/trip_setup_wizard_screen.dart')
            .readAsStringSync();

    expect(source, contains('Choose Trip Type'));
    expect(source, contains('Create or Join'));
    expect(source, contains('Communication Preparation'));
    expect(source, contains('Readiness Check'));
    expect(source, contains('Start Trip'));
    expect(source, contains('tutorial_seen'));
    expect(source, contains('coach_marks_seen'));
  });

  test('help screens explain user and manual test flows', () {
    final howItWorks = File('lib/features/help/how_traillink_works_screen.dart')
        .readAsStringSync();
    final manual = File('lib/features/help/manual_test_guide_screen.dart')
        .readAsStringSync();

    expect(howItWorks, contains('Start or join a trip'));
    expect(howItWorks, contains('Data saves locally first'));
    expect(manual, contains('Two-device P2P test'));
    expect(manual, contains('Device A'));
    expect(manual, contains('Device B'));
  });
}
