import '../../features/auth/data/models/user_model.dart';
import 'auth_access_controller.dart';
import 'local_identity_model.dart';
import 'local_identity_repository.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final currentUserActorProvider = FutureProvider<CurrentUserActor?>((ref) async {
  final access = ref.watch(authAccessControllerProvider);
  if (access.user != null || access.identity != null) {
    return CurrentUserActor.fromAuthAccess(access);
  }
  final identity =
      await ref.read(localIdentityRepositoryProvider).getCurrentIdentity();
  return identity == null ? null : CurrentUserActor.fromLocalIdentity(identity);
});

class CurrentUserActor {
  const CurrentUserActor({
    required this.id,
    required this.localUserId,
    required this.displayName,
    this.email = '',
    this.identityType = 'authenticated',
    this.backendUserId,
  });

  factory CurrentUserActor.fromAuthAccess(AuthAccessStatus access) {
    final user = access.user;
    if (user != null) {
      final identity = access.identity;
      return CurrentUserActor(
        id: user.id,
        localUserId: identity?.localUserId ?? user.id,
        backendUserId: user.id,
        displayName: user.fullName,
        email: user.email,
        identityType: identity?.identityType ?? 'authenticated_cached',
      );
    }
    final identity = access.identity;
    if (identity != null) return CurrentUserActor.fromLocalIdentity(identity);
    throw StateError('Create your TrailLink profile before continuing.');
  }

  factory CurrentUserActor.fromLocalIdentity(LocalIdentityModel identity) {
    return CurrentUserActor(
      id: identity.backendUserId ?? identity.localUserId,
      localUserId: identity.localUserId,
      backendUserId: identity.backendUserId,
      displayName: identity.displayName,
      email: identity.email ?? '',
      identityType: identity.identityType,
    );
  }

  factory CurrentUserActor.fromUserModel(UserModel user) {
    return CurrentUserActor(
      id: user.id,
      localUserId: user.id,
      backendUserId: user.id,
      displayName: user.fullName,
      email: user.email,
      identityType: 'verified',
    );
  }

  final String id;
  final String localUserId;
  final String? backendUserId;
  final String displayName;
  final String email;
  final String identityType;

  UserModel toUserModel() {
    return UserModel(id: id, fullName: displayName, email: email);
  }
}
