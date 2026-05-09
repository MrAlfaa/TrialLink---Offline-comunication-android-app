import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/models/user_model.dart';
import '../connectivity/backend_reachability_service.dart';
import '../setup/setup_progress_service.dart';
import '../storage/secure_storage_service.dart';
import 'auth_access_state.dart';
import 'local_identity_model.dart';
import 'local_identity_repository.dart';

final authAccessControllerProvider =
    StateNotifierProvider<AuthAccessController, AuthAccessStatus>((ref) {
  return AuthAccessController(
    authRepository: AuthRepository(),
    identityRepository: ref.read(localIdentityRepositoryProvider),
    setupProgressService: ref.read(setupProgressServiceProvider),
    reachabilityService: BackendReachabilityService(),
    storage: SecureStorageService.instance,
  );
});

class AuthAccessStatus {
  const AuthAccessStatus({
    required this.accessState,
    this.isChecking = false,
    this.identity,
    this.user,
    this.startupRoute,
    this.message,
  });

  factory AuthAccessStatus.initial() {
    return const AuthAccessStatus(
      accessState: AuthAccessState.unauthenticated,
      isChecking: true,
      startupRoute: '/splash',
    );
  }

  final AuthAccessState accessState;
  final bool isChecking;
  final LocalIdentityModel? identity;
  final UserModel? user;
  final String? startupRoute;
  final String? message;

  AuthAccessStatus copyWith({
    AuthAccessState? accessState,
    bool? isChecking,
    LocalIdentityModel? identity,
    bool clearIdentity = false,
    UserModel? user,
    bool clearUser = false,
    String? startupRoute,
    String? message,
  }) {
    return AuthAccessStatus(
      accessState: accessState ?? this.accessState,
      isChecking: isChecking ?? this.isChecking,
      identity: clearIdentity ? null : identity ?? this.identity,
      user: clearUser ? null : user ?? this.user,
      startupRoute: startupRoute ?? this.startupRoute,
      message: message ?? this.message,
    );
  }
}

class AuthAccessController extends StateNotifier<AuthAccessStatus> {
  AuthAccessController({
    required AuthRepository authRepository,
    required LocalIdentityRepository identityRepository,
    required SetupProgressService setupProgressService,
    required BackendReachabilityService reachabilityService,
    required SecureStorageService storage,
  })  : _authRepository = authRepository,
        _identityRepository = identityRepository,
        _setupProgressService = setupProgressService,
        _reachabilityService = reachabilityService,
        _storage = storage,
        super(AuthAccessStatus.initial());

  final AuthRepository _authRepository;
  final LocalIdentityRepository _identityRepository;
  final SetupProgressService _setupProgressService;
  final BackendReachabilityService _reachabilityService;
  final SecureStorageService _storage;

  Future<String> evaluateStartup() async {
    state = state.copyWith(isChecking: true);

    if (!await _setupProgressService.isSetupCompleted()) {
      final route = await _setupProgressService.getNextSetupRoute();
      state = AuthAccessStatus(
        accessState: AuthAccessState.unauthenticated,
        startupRoute: route,
        message: 'Setup is not complete.',
      );
      return route;
    }

    final identity = await _identityRepository.getCurrentIdentity();
    final token = await _storage.readToken();
    final backendReachable = await _reachabilityService.checkBackendReachable();

    if (backendReachable && token != null && token.isNotEmpty) {
      final user = await _authRepository.restoreSession(clearOnFailure: false);
      if (user != null) {
        final savedIdentity =
            await _identityRepository.saveAuthenticatedIdentity(user);
        state = AuthAccessStatus(
          accessState: AuthAccessState.authenticatedOnline,
          identity: savedIdentity,
          user: user,
          startupRoute: '/home',
          message: 'Cloud account active. Online sync available.',
        );
        return '/home';
      }

      final fallbackIdentity =
          identity ?? await _identityRepository.getCurrentIdentity();
      if (fallbackIdentity != null) {
        return _routeForLocalIdentity(fallbackIdentity);
      }

      state = const AuthAccessStatus(
        accessState: AuthAccessState.unauthenticated,
        startupRoute: '/setup/identity',
        message: 'Create your TrailLink profile to continue.',
      );
      return '/setup/identity';
    }

    if (identity != null) {
      return _routeForLocalIdentity(identity);
    }

    state = const AuthAccessStatus(
      accessState: AuthAccessState.unauthenticated,
      startupRoute: '/setup/identity',
      message: 'No local identity found.',
    );
    return '/setup/identity';
  }

  Future<void> refreshFromIdentity() async {
    final identity = await _identityRepository.getCurrentIdentity();
    if (identity == null) {
      state = const AuthAccessStatus(
        accessState: AuthAccessState.unauthenticated,
        startupRoute: '/setup/identity',
      );
      return;
    }
    await _routeForLocalIdentity(identity);
  }

  void setAuthenticatedOnline({
    required LocalIdentityModel identity,
    required UserModel user,
  }) {
    state = AuthAccessStatus(
      accessState: AuthAccessState.authenticatedOnline,
      identity: identity,
      user: user,
      startupRoute: '/home',
      message: 'Cloud account active. Online sync available.',
    );
  }

  Future<String> _routeForLocalIdentity(LocalIdentityModel identity) async {
    final accessState = identity.isGuest
        ? AuthAccessState.guestOffline
        : AuthAccessState.authenticatedOfflineCached;
    state = AuthAccessStatus(
      accessState: accessState,
      identity: identity,
      startupRoute: '/home',
      message: accessState == AuthAccessState.guestOffline
          ? 'Offline guest mode. Login later to sync your trip data.'
          : 'Offline cached session. Cloud sync is paused.',
    );
    return '/home';
  }
}
