import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/models/user_model.dart';
import '../../../core/identity/current_user_actor.dart';
import '../../../core/identity/local_identity_repository.dart';
import '../../../core/identity/local_identity_model.dart';
import '../../nearby/presentation/nearby_controller.dart';
import '../../trip_context/data/trip_context_service.dart';
import '../data/active_offline_channel_resolver.dart';
import '../data/models/offline_channel_member_model.dart';
import '../data/models/offline_channel_model.dart';
import '../data/offline_channel_repository.dart';

final offlineChannelRepositoryProvider =
    Provider<OfflineChannelRepository>((ref) {
  return OfflineChannelRepository(
    nearbyRepository: ref.watch(nearbyRepositoryProvider),
  );
});

final activeOfflineChannelResolverProvider =
    Provider<ActiveOfflineChannelResolver>((ref) {
  return ActiveOfflineChannelResolver(
    channelRepository: ref.read(offlineChannelRepositoryProvider),
    identityRepository: ref.read(localIdentityRepositoryProvider),
  );
});

final offlineChannelListProvider =
    FutureProvider<List<OfflineChannelModel>>((ref) async {
  await ref
      .read(activeOfflineChannelResolverProvider)
      .repairActiveChannelFromActiveTripIfNeeded();
  return ref.read(offlineChannelRepositoryProvider).getChannels();
});

final rawOfflineChannelListProvider =
    FutureProvider<List<OfflineChannelModel>>((ref) {
  return ref.read(offlineChannelRepositoryProvider).getChannels();
});

final activeOfflineChannelProvider =
    FutureProvider<OfflineChannelModel?>((ref) {
  return ref.watch(activeTripContextProvider.future).then(
        (context) => context?.activeChannel,
      );
});

final activeUsableOfflineChannelProvider =
    FutureProvider<OfflineChannelModel?>((ref) {
  return ref.watch(activeTripContextProvider.future).then((context) {
    final channel = context?.activeChannel;
    return channel?.isUsable == true ? channel : null;
  });
});

final activeTripChannelProvider = FutureProvider<OfflineChannelModel?>((ref) {
  return ref.watch(activeTripContextProvider.future).then(
        (context) => context?.activeChannel,
      );
});

final offlineChannelDetailsProvider =
    FutureProvider.family<OfflineChannelModel?, String>((ref, channelId) {
  return ref.read(offlineChannelRepositoryProvider).getChannel(channelId);
});

final offlineChannelMembersProvider =
    FutureProvider.family<List<OfflineChannelMemberModel>, String>(
        (ref, channelId) {
  return ref.read(offlineChannelRepositoryProvider).getMembers(channelId);
});

class OfflineChannelMutationState {
  const OfflineChannelMutationState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.packetFilterResults = const [],
  });

  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final List<String> packetFilterResults;
}

class OfflineChannelController
    extends StateNotifier<OfflineChannelMutationState> {
  OfflineChannelController(
    this._repository,
    this._identityRepository,
    this._tripContextService,
  ) : super(const OfflineChannelMutationState());

  final OfflineChannelRepository _repository;
  final LocalIdentityRepository _identityRepository;
  final TripContextService _tripContextService;

  Future<OfflineChannelModel?> createChannel({
    required UserModel? user,
    required String channelName,
    required String description,
    String? customCode,
  }) async {
    state = const OfflineChannelMutationState(isLoading: true);
    try {
      final channel = user == null
          ? await _repository.createChannelForIdentity(
              identity: await _requireLocalIdentity(),
              channelName: channelName,
              description: description,
              customCode: customCode,
            )
          : await _repository.createChannel(
              user: user,
              channelName: channelName,
              description: description,
              customCode: customCode,
            );
      state = const OfflineChannelMutationState(
        successMessage: 'Offline channel created.',
      );
      return channel;
    } catch (error) {
      state = OfflineChannelMutationState(errorMessage: error.toString());
      return null;
    }
  }

  Future<OfflineChannelModel?> joinChannel({
    required UserModel? user,
    required String channelCode,
  }) async {
    state = const OfflineChannelMutationState(isLoading: true);
    try {
      final context =
          await _tripContextService.joinOfflineChannelAsActiveTrip(channelCode);
      final channel = context.activeChannel;
      if (channel == null) throw StateError('Joined channel not found.');
      state = const OfflineChannelMutationState(
        successMessage: 'Offline channel joined and trip activated.',
      );
      return channel;
    } catch (error) {
      state = OfflineChannelMutationState(errorMessage: error.toString());
      return null;
    }
  }

  Future<void> setActiveChannel(String channelId) async {
    state = const OfflineChannelMutationState(isLoading: true);
    try {
      await _tripContextService.switchActiveChannel(channelId);
      state = const OfflineChannelMutationState(
        successMessage: 'Active offline channel updated.',
      );
    } catch (error) {
      state = OfflineChannelMutationState(errorMessage: error.toString());
    }
  }

  Future<void> setInactiveChannel(String channelId) async {
    state = const OfflineChannelMutationState(isLoading: true);
    try {
      await _repository.setInactiveChannel(channelId);
      state = const OfflineChannelMutationState(
        successMessage: 'Offline channel set inactive.',
      );
    } catch (error) {
      state = OfflineChannelMutationState(errorMessage: error.toString());
    }
  }

  Future<void> endChannel({
    required OfflineChannelModel channel,
    required UserModel? user,
    String reason = 'Channel ended by owner.',
  }) async {
    state = const OfflineChannelMutationState(isLoading: true);
    try {
      final actor = user == null
          ? CurrentUserActor.fromLocalIdentity(await _requireLocalIdentity())
          : CurrentUserActor.fromUserModel(user);
      await _repository.endChannel(
        channel: channel,
        actor: actor,
        reason: reason,
      );
      state = const OfflineChannelMutationState(
        successMessage:
            'Channel ended. Chat history remains available read-only.',
      );
    } catch (error) {
      state = OfflineChannelMutationState(errorMessage: error.toString());
    }
  }

  Future<void> leaveChannel(String channelId) async {
    state = const OfflineChannelMutationState(isLoading: true);
    try {
      final identity = await _requireLocalIdentity();
      await _repository.leaveChannel(
        channelId: channelId,
        localUserId: identity.localUserId,
      );
      state = const OfflineChannelMutationState(
        successMessage: 'Offline channel left. Messages remain on this device.',
      );
    } catch (error) {
      state = OfflineChannelMutationState(errorMessage: error.toString());
    }
  }

  Future<void> runPacketFilterTest({
    required OfflineChannelModel channel,
    required UserModel? user,
  }) async {
    state = const OfflineChannelMutationState(isLoading: true);
    try {
      final effectiveUser =
          user ?? _actorFromIdentity(await _requireLocalIdentity());
      final results =
          await _repository.runPacketFilterTest(channel, effectiveUser);
      state = OfflineChannelMutationState(
        successMessage: 'Packet filter test completed.',
        packetFilterResults: results,
      );
    } catch (error) {
      state = OfflineChannelMutationState(errorMessage: error.toString());
    }
  }

  Future<LocalIdentityModel> _requireLocalIdentity() async {
    final identity = await _identityRepository.getCurrentIdentity();
    if (identity == null) {
      throw StateError('Create an offline identity before using channels.');
    }
    return identity;
  }

  UserModel _actorFromIdentity(LocalIdentityModel identity) {
    return UserModel(
      id: identity.localUserId,
      fullName: identity.displayName,
      email: identity.email ?? '',
      phoneNumber: identity.phoneNumber,
    );
  }
}

final offlineChannelControllerProvider = StateNotifierProvider<
    OfflineChannelController, OfflineChannelMutationState>((ref) {
  return OfflineChannelController(
    ref.read(offlineChannelRepositoryProvider),
    ref.read(localIdentityRepositoryProvider),
    ref.read(tripContextServiceProvider),
  );
});
