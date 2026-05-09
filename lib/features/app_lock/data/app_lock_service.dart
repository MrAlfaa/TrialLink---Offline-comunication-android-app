import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/identity/auth_access_controller.dart';
import '../../../core/identity/current_user_actor.dart';
import '../../../core/mode/mode_controller.dart';
import '../../../core/settings/settings_service.dart';
import '../../auth/data/models/user_model.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../emergency/presentation/emergency_controller.dart';
import '../../offline_channel/presentation/offline_channel_controller.dart';
import '../../trip/data/trip_session_repository.dart';

final lockedQuickSosServiceProvider = Provider<LockedQuickSosService>((ref) {
  return LockedQuickSosService(ref);
});

class LockedQuickSosResult {
  const LockedQuickSosResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

class LockedQuickSosService {
  LockedQuickSosService(this._ref);

  final Ref _ref;

  Future<LockedQuickSosResult> triggerLockedQuickSos({
    String message = 'Need help',
  }) async {
    final user = _currentUser();
    if (user == null) {
      return const LockedQuickSosResult(
        success: false,
        message: 'Create your TrailLink profile before sending SOS.',
      );
    }

    final settings = _ref.read(settingsServiceProvider);
    final offlineSosEnabled =
        await settings.getBool('enable_offline_sos', true) &&
            await settings.getBool('offline_sos_enabled', true);
    if (!offlineSosEnabled) {
      return const LockedQuickSosResult(
        success: false,
        message: 'Offline SOS is disabled in Settings.',
      );
    }

    final trip = await _ref.read(tripSessionRepositoryProvider).getActiveTrip();
    final channel = trip?.offlineChannelId == null
        ? await _ref.read(offlineChannelRepositoryProvider).getActiveChannel()
        : await _ref
            .read(offlineChannelRepositoryProvider)
            .getChannel(trip!.offlineChannelId!);
    final groupId = trip?.cloudGroupId;
    if (channel == null && groupId == null) {
      return const LockedQuickSosResult(
        success: false,
        message:
            'No active trip or offline channel found. Unlock TrailLink to configure emergency communication.',
      );
    }

    try {
      final attachLocation =
          await settings.getBool('attach_location_to_sos', true);
      final useLastKnown =
          await settings.getBool('use_last_known_location_for_sos', true);
      await _ref.read(emergencyRepositoryProvider).triggerSos(
            user: user,
            groupId: groupId,
            channel: channel,
            mode: _ref.read(modeControllerProvider).compatibilityConnectionMode,
            message: message,
            attachLocation: attachLocation,
            useLastKnownLocation: useLastKnown,
          );
      return LockedQuickSosResult(
        success: true,
        message: attachLocation
            ? 'SOS sent or queued. TrailLink remains locked.'
            : 'SOS sent without location. TrailLink remains locked.',
      );
    } catch (error) {
      return LockedQuickSosResult(
        success: false,
        message: error.toString(),
      );
    }
  }

  UserModel? _currentUser() {
    final authUser = _ref.read(authControllerProvider).user;
    if (authUser != null) return authUser;
    try {
      return CurrentUserActor.fromAuthAccess(
        _ref.read(authAccessControllerProvider),
      ).toUserModel();
    } catch (_) {
      return null;
    }
  }
}
