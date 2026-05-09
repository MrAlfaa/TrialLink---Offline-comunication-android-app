enum AuthAccessState {
  authenticatedOnline,
  authenticatedOfflineCached,
  guestOffline,
  unauthenticated,
}

extension AuthAccessStateX on AuthAccessState {
  bool get canOpenAppShell {
    return this != AuthAccessState.unauthenticated;
  }

  bool get canUseBackendFeatures {
    return this == AuthAccessState.authenticatedOnline;
  }

  bool get isOfflineCapable {
    return this == AuthAccessState.authenticatedOfflineCached ||
        this == AuthAccessState.guestOffline ||
        this == AuthAccessState.authenticatedOnline;
  }

  String get label {
    return switch (this) {
      AuthAccessState.authenticatedOnline => 'Cloud account active',
      AuthAccessState.authenticatedOfflineCached => 'Offline cached session',
      AuthAccessState.guestOffline => 'Offline guest mode',
      AuthAccessState.unauthenticated => 'Not signed in',
    };
  }
}
