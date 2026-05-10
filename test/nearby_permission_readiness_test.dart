import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:traillink/features/nearby/data/nearby_permission_service.dart';

void main() {
  group('nearby permission readiness mapping', () {
    test('granted permissions with location service enabled are ready', () {
      final state = NearbyPermissionService.mapStatusesForReadiness(
        const [
          PermissionStatus.granted,
          PermissionStatus.granted,
        ],
        locationServiceEnabled: true,
      );

      expect(state.granted, isTrue);
      expect(state.readiness, NearbyPermissionReadiness.ready);
    });

    test('denied permissions are missing', () {
      final state = NearbyPermissionService.mapStatusesForReadiness(
        const [
          PermissionStatus.granted,
          PermissionStatus.denied,
        ],
        locationServiceEnabled: true,
      );

      expect(state.granted, isFalse);
      expect(state.readiness, NearbyPermissionReadiness.missing);
    });

    test('permanently denied permissions are blocked', () {
      final state = NearbyPermissionService.mapStatusesForReadiness(
        const [
          PermissionStatus.permanentlyDenied,
        ],
        locationServiceEnabled: true,
      );

      expect(state.granted, isFalse);
      expect(state.readiness, NearbyPermissionReadiness.blocked);
    });

    test('disabled location service keeps readiness missing', () {
      final state = NearbyPermissionService.mapStatusesForReadiness(
        const [
          PermissionStatus.granted,
        ],
        locationServiceEnabled: false,
      );

      expect(state.granted, isFalse);
      expect(state.readiness, NearbyPermissionReadiness.missing);
      expect(state.message, contains('Location services'));
    });
  });
}
