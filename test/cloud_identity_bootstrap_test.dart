import 'package:flutter_test/flutter_test.dart';
import 'package:traillink/features/auth/data/models/user_model.dart';
import 'package:traillink/features/cloud_identity/data/cloud_identity_status_model.dart';

void main() {
  group('Cloud identity contracts', () {
    test('UserModel parses cloud bootstrap identity fields', () {
      final user = UserModel.fromJson({
        'id': 'cloud_1',
        'publicUserId': 'UID-202605080022',
        'localUserId': 'local_abc',
        'displayName': 'Dhananjaya',
        'email': 'user@example.com',
        'phoneNumber': '0771234567',
        'emergencyNote': 'Blue jacket',
      });

      expect(user.id, 'cloud_1');
      expect(user.publicUserId, 'UID-202605080022');
      expect(user.localUserId, 'local_abc');
      expect(user.displayName, 'Dhananjaya');
      expect(user.fullName, 'Dhananjaya');
      expect(user.emergencyNote, 'Blue jacket');
    });

    test('CloudSyncState reports blocking account creation progress', () {
      final state = CloudSyncState.creatingAccount(
        currentStep: 'Creating cloud profile',
        progressPercent: 45,
      );

      expect(state.isActive, isTrue);
      expect(state.isBlocking, isTrue);
      expect(state.isCreatingAccount, isTrue);
      expect(state.isGeneratingUid, isTrue);
      expect(state.currentStep, 'Creating cloud profile');
      expect(state.progressPercent, 45);
    });

    test('CloudSyncState reports success with public user id', () {
      final state = CloudSyncState.success('UID-202605080022');

      expect(state.isActive, isTrue);
      expect(state.isBlocking, isFalse);
      expect(state.publicUserId, 'UID-202605080022');
      expect(state.currentStep, 'Cloud account ready');
    });
  });
}
