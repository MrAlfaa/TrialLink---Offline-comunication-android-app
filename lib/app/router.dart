import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/env_config.dart';
import '../core/config/offline_text_only_flags.dart';
import '../core/identity/auth_access_controller.dart';
import '../core/identity/auth_access_state.dart';
import '../core/mode/mode_controller.dart';
import '../core/mode/mode_models.dart';
import '../features/account_link/link_offline_data_screen.dart';
import '../features/app_lock/data/models/app_lock_status.dart';
import '../features/app_lock/presentation/app_lock_controller.dart';
import '../features/app_lock/presentation/app_lock_pin_screen.dart';
import '../features/app_lock/presentation/app_lock_setup_screen.dart';
import '../features/app_lock/presentation/app_unlock_screen.dart';
import '../features/app_lock/presentation/locked_quick_sos_screen.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/bridge/presentation/bridge_activity_screen.dart';
import '../features/bridge/presentation/bridge_debug_screen.dart';
import '../features/bridge/presentation/bridge_settings_screen.dart';
import '../features/chat/presentation/chat_hub_screen.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/connectivity_intelligence/presentation/connectivity_guidance_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/emergency/presentation/emergency_history_screen.dart';
import '../features/emergency/presentation/sos_screen.dart';
import '../features/groups/presentation/create_group_screen.dart';
import '../features/groups/presentation/group_details_screen.dart';
import '../features/groups/presentation/group_members_screen.dart';
import '../features/groups/presentation/groups_dashboard_screen.dart';
import '../features/help/how_traillink_works_screen.dart';
import '../features/help/manual_test_guide_screen.dart';
import '../features/location/presentation/map_screen.dart';
import '../features/groups/presentation/join_group_screen.dart';
import '../features/offline_channel/presentation/create_offline_channel_screen.dart';
import '../features/offline_channel/presentation/active_channel_debug_screen.dart';
import '../features/offline_channel/presentation/join_offline_channel_screen.dart';
import '../features/offline_channel/presentation/offline_channel_details_screen.dart';
import '../features/offline_channel/presentation/offline_channel_list_screen.dart';
import '../features/offline_chat/presentation/offline_chat_screen.dart';
import '../features/nearby/presentation/nearby_peers_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/placeholders/offline_feature_disabled_screen.dart';
import '../features/ptt/presentation/ptt_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/setup/presentation/setup_screens.dart';
import '../features/splash/splash_screen.dart';
import '../features/trip/presentation/trip_setup_screen.dart';
import '../features/trip/presentation/trip_setup_wizard_screen.dart';
import '../features/trip_context/presentation/trip_management_screen.dart';
import '../shared/widgets/trail_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ref.watch(_appRouterRefreshProvider);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final authAccess = ref.read(authAccessControllerProvider);
      final location = state.matchedLocation;
      final setupAndAuthRoutes = {
        '/splash',
        '/onboarding',
        '/setup/welcome',
        '/setup/agreement',
        '/setup/identity',
        '/setup/mode',
        '/setup/features',
        '/setup/security',
        '/setup/trip',
        '/setup/permissions',
        '/login',
        '/register',
      };
      final lockRoutes = {
        '/unlock',
        '/app-lock/pin',
        '/locked/sos',
      };

      if (authAccess.isChecking && location == '/splash') return null;
      if (authState.status == AuthStatus.checking && location == '/splash') {
        return null;
      }

      if (setupAndAuthRoutes.contains(location)) return null;

      final appLock = ref.read(appLockControllerProvider);
      if (lockRoutes.contains(location)) return null;
      if (location == '/settings/app-lock/setup' &&
          (appLock.status == AppLockStatus.setupRequired ||
              !authAccess.accessState.canOpenAppShell)) {
        return null;
      }

      if (!authAccess.accessState.canOpenAppShell) {
        return '/setup/identity';
      }

      if (appLock.isInitialized &&
          appLock.appLockEnabled &&
          appLock.isLocked &&
          !_isLockAllowedRoute(location)) {
        final from = Uri.encodeComponent(state.uri.toString());
        return '/unlock?from=$from';
      }

      if (isOnlineOnlyRoute(location) &&
          !authAccess.accessState.canUseBackendFeatures) {
        return '/account/link-offline-data';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/unlock',
        pageBuilder: (context, state) => _fadePage(
          state,
          const AppUnlockScreen(),
        ),
      ),
      GoRoute(
        path: '/app-lock/pin',
        pageBuilder: (context, state) => _slidePage(
          state,
          const AppLockPinScreen(),
        ),
      ),
      GoRoute(
        path: '/locked/sos',
        pageBuilder: (context, state) => _slidePage(
          state,
          const LockedQuickSosScreen(),
        ),
      ),
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => _fadePage(
          state,
          const SplashScreen(),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => _slidePage(
          state,
          const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: '/setup/welcome',
        pageBuilder: (context, state) => _slidePage(
          state,
          const SetupWelcomeScreen(),
        ),
      ),
      GoRoute(
        path: '/setup/agreement',
        pageBuilder: (context, state) => _slidePage(
          state,
          const SetupAgreementScreen(),
        ),
      ),
      GoRoute(
        path: '/setup/identity',
        pageBuilder: (context, state) => _slidePage(
          state,
          const SetupIdentityScreen(),
        ),
      ),
      GoRoute(
        path: '/setup/mode',
        pageBuilder: (context, state) => _slidePage(
          state,
          const SetupModePreferenceScreen(),
        ),
      ),
      GoRoute(
        path: '/setup/features',
        pageBuilder: (context, state) => _slidePage(
          state,
          const SetupFeaturePreferenceScreen(),
        ),
      ),
      GoRoute(
        path: '/setup/security',
        pageBuilder: (context, state) => _slidePage(
          state,
          const SetupSecurityPreferenceScreen(),
        ),
      ),
      GoRoute(
        path: '/setup/trip',
        pageBuilder: (context, state) => _slidePage(
          state,
          const TripSetupScreen(),
        ),
      ),
      GoRoute(
        path: '/setup/permissions',
        pageBuilder: (context, state) => _slidePage(
          state,
          const SetupPermissionScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _slidePage(
          state,
          const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => _slidePage(
          state,
          const RegisterScreen(),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => TrailScaffold(child: child),
        routes: [
          GoRoute(
            path: '/trips/:tripId/channels/:channelId/chats/:chatId',
            pageBuilder: (context, state) => _slidePage(
              state,
              OfflineChatScreen(
                tripId: state.pathParameters['tripId']!,
                channelId: state.pathParameters['channelId']!,
                chatId: state.pathParameters['chatId']!,
              ),
            ),
          ),
          GoRoute(
            path: '/trips/:tripId/channels/:channelId/chats',
            pageBuilder: (context, state) => _slidePage(
              state,
              OfflineChatScreen(
                tripId: state.pathParameters['tripId']!,
                channelId: state.pathParameters['channelId']!,
              ),
            ),
          ),
          GoRoute(
            path: '/offline-channel/:channelId/chat',
            pageBuilder: (context, state) => _slidePage(
              state,
              OfflineChatRouteResolverScreen(
                channelId: state.pathParameters['channelId']!,
              ),
            ),
          ),
          GoRoute(
            path: '/offline-channels/:channelId/chat',
            pageBuilder: (context, state) => _slidePage(
              state,
              OfflineChatRouteResolverScreen(
                channelId: state.pathParameters['channelId']!,
              ),
            ),
          ),
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => _fadePage(
              state,
              const DashboardScreen(),
            ),
            routes: [
              GoRoute(
                path: 'status',
                redirect: (context, state) => '/home',
              ),
            ],
          ),
          GoRoute(
            path: '/trip/create',
            pageBuilder: (context, state) => _slidePage(
              state,
              const TripSetupWizardScreen(),
            ),
          ),
          GoRoute(
            path: '/trip/setup-wizard',
            pageBuilder: (context, state) => _slidePage(
              state,
              TripSetupWizardScreen(
                initialIntent: state.uri.queryParameters['intent'],
              ),
            ),
          ),
          GoRoute(
            path: '/trips',
            pageBuilder: (context, state) => _slidePage(
              state,
              const TripManagementScreen(),
            ),
          ),
          GoRoute(
            path: '/help/how-it-works',
            pageBuilder: (context, state) => _slidePage(
              state,
              const HowTrailLinkWorksScreen(),
            ),
          ),
          GoRoute(
            path: '/help/manual-test',
            pageBuilder: (context, state) => _slidePage(
              state,
              const ManualTestGuideScreen(),
            ),
          ),
          GoRoute(
            path: '/groups',
            pageBuilder: (context, state) => _fadePage(
              state,
              const GroupsDashboardScreen(),
            ),
            routes: [
              GoRoute(
                path: 'create',
                pageBuilder: (context, state) => _slidePage(
                  state,
                  const CreateGroupScreen(),
                ),
              ),
              GoRoute(
                path: 'join',
                pageBuilder: (context, state) => _slidePage(
                  state,
                  const JoinGroupScreen(),
                ),
              ),
              GoRoute(
                path: ':groupId',
                pageBuilder: (context, state) => _slidePage(
                  state,
                  GroupDetailsScreen(
                    groupId: state.pathParameters['groupId']!,
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'members',
                    pageBuilder: (context, state) => _slidePage(
                      state,
                      GroupMembersScreen(
                        groupId: state.pathParameters['groupId']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'chat',
                    pageBuilder: (context, state) {
                      final extra = state.extra;
                      final groupName = extra is Map<String, dynamic>
                          ? extra['groupName']?.toString() ?? 'Group Chat'
                          : 'Group Chat';
                      return _slidePage(
                        state,
                        ChatScreen(
                          groupId: state.pathParameters['groupId']!,
                          groupName: groupName,
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'sos',
                    pageBuilder: (context, state) => _slidePage(
                      state,
                      SosScreen(groupId: state.pathParameters['groupId']!),
                    ),
                  ),
                  GoRoute(
                    path: 'map',
                    pageBuilder: (context, state) => _slidePage(
                      state,
                      MapScreen(
                        groupId: state.pathParameters['groupId']!,
                        focus: MapFocus.fromExtra(state.extra),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'ptt',
                    pageBuilder: (context, state) => _slidePage(
                      state,
                      PttScreen(groupId: state.pathParameters['groupId']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/chat',
            pageBuilder: (context, state) => _fadePage(
              state,
              ChatHubScreen(initialTab: state.uri.queryParameters['tab']),
            ),
          ),
          GoRoute(
            path: '/offline-channel',
            pageBuilder: (context, state) => _fadePage(
              state,
              const OfflineChannelListScreen(),
            ),
            routes: [
              GoRoute(
                path: 'create',
                pageBuilder: (context, state) => _slidePage(
                  state,
                  const CreateOfflineChannelScreen(),
                ),
              ),
              GoRoute(
                path: 'join',
                pageBuilder: (context, state) => _slidePage(
                  state,
                  const JoinOfflineChannelScreen(),
                ),
              ),
              GoRoute(
                path: ':channelId',
                pageBuilder: (context, state) => _slidePage(
                  state,
                  OfflineChannelDetailsScreen(
                    channelId: state.pathParameters['channelId']!,
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'sos',
                    pageBuilder: (context, state) => _slidePage(
                      state,
                      const OfflineFeatureDisabledScreen(
                        featureName: 'Offline SOS',
                        icon: Icons.sos_rounded,
                        message: OfflineTextOnlyFlags.disabledMessage,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'map',
                    pageBuilder: (context, state) => _slidePage(
                      state,
                      const OfflineFeatureDisabledScreen(
                        featureName: 'Offline Location',
                        icon: Icons.location_on_rounded,
                        message: OfflineTextOnlyFlags.disabledMessage,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'ptt',
                    pageBuilder: (context, state) => _slidePage(
                      state,
                      const OfflineFeatureDisabledScreen(
                        featureName: 'Offline PTT',
                        icon: Icons.record_voice_over_rounded,
                        message: OfflineTextOnlyFlags.disabledMessage,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/bridge',
            pageBuilder: (context, state) => _fadePage(
              state,
              const BridgeActivityScreen(),
            ),
          ),
          GoRoute(
            path: '/debug/bridge',
            pageBuilder: (context, state) => _fadePage(
              state,
              const BridgeDebugScreen(),
            ),
          ),
          GoRoute(
            path: '/debug/active-channel',
            redirect: (context, state) =>
                EnvConfig.appEnv == 'production' ? '/home' : null,
            pageBuilder: (context, state) => _fadePage(
              state,
              const ActiveChannelDebugScreen(),
            ),
          ),
          GoRoute(
            path: '/nearby-peers',
            pageBuilder: (context, state) => _fadePage(
              state,
              const NearbyPeersScreen(),
            ),
          ),
          GoRoute(
            path: '/sos',
            pageBuilder: (context, state) {
              if (_offlineTextOnlyActive(ref)) {
                return _fadePage(
                  state,
                  const OfflineFeatureDisabledScreen(
                    featureName: 'Offline SOS',
                    icon: Icons.sos_rounded,
                  ),
                );
              }
              return _fadePage(
                state,
                const SosScreen(),
              );
            },
          ),
          GoRoute(
            path: '/map',
            pageBuilder: (context, state) {
              if (_offlineTextOnlyActive(ref)) {
                return _fadePage(
                  state,
                  const OfflineFeatureDisabledScreen(
                    featureName: 'Offline Location',
                    icon: Icons.location_on_rounded,
                  ),
                );
              }
              return _fadePage(
                state,
                MapScreen(focus: MapFocus.fromExtra(state.extra)),
              );
            },
          ),
          GoRoute(
            path: '/emergency-history',
            pageBuilder: (context, state) => _fadePage(
              state,
              const EmergencyHistoryScreen(),
            ),
          ),
          GoRoute(
            path: '/connectivity',
            pageBuilder: (context, state) => _fadePage(
              state,
              const ConnectivityGuidanceScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => _fadePage(
              state,
              const SettingsScreen(),
            ),
            routes: [
              GoRoute(
                path: 'profile',
                pageBuilder: (context, state) => _slidePage(
                  state,
                  const ProfileSettingsScreen(),
                ),
              ),
              GoRoute(
                path: 'mode',
                pageBuilder: (context, state) => _slidePage(
                  state,
                  const ModeSettingsScreen(),
                ),
              ),
              GoRoute(
                path: 'features',
                pageBuilder: (context, state) => _slidePage(
                  state,
                  const FeatureControlsSettingsScreen(),
                ),
              ),
              GoRoute(
                path: 'safety',
                pageBuilder: (context, state) => _slidePage(
                  state,
                  const SafetyEmergencySettingsScreen(),
                ),
              ),
              GoRoute(
                path: 'app-lock',
                pageBuilder: (context, state) => _slidePage(
                  state,
                  const AppLockPrivacySettingsScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'setup',
                    pageBuilder: (context, state) => _slidePage(
                      state,
                      const AppLockSetupScreen(),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'voice',
                pageBuilder: (context, state) => _slidePage(
                  state,
                  const VoicePttSettingsScreen(),
                ),
              ),
              GoRoute(
                path: 'data-sync',
                pageBuilder: (context, state) => _slidePage(
                  state,
                  const DataSyncSettingsScreen(),
                ),
              ),
              GoRoute(
                path: 'bridge',
                pageBuilder: (context, state) => _slidePage(
                  state,
                  const BridgeSettingsScreen(),
                ),
              ),
              GoRoute(
                path: 'agreement',
                pageBuilder: (context, state) => _slidePage(
                  state,
                  const AgreementPrivacySettingsScreen(),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/account/link-offline-data',
            pageBuilder: (context, state) => _slidePage(
              state,
              const LinkOfflineDataScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});

final _appRouterRefreshProvider = Provider<Listenable>((ref) {
  final notifier = _RouterRefreshNotifier();
  ref
    ..listen(authControllerProvider, (_, __) => notifier.refresh())
    ..listen(authAccessControllerProvider, (_, __) => notifier.refresh())
    ..listen(appLockControllerProvider, (_, __) => notifier.refresh())
    ..listen(modeControllerProvider, (_, __) => notifier.refresh());
  ref.onDispose(notifier.dispose);
  return notifier;
});

class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

bool _offlineTextOnlyActive(Ref ref) {
  return OfflineTextOnlyFlags.enabled &&
      ref.read(modeControllerProvider).effectiveMode == EffectiveMode.offline;
}

bool isOnlineOnlyRoute(String location) {
  return location == '/groups/create' ||
      location == '/groups/join' ||
      location.startsWith('/groups/create/') ||
      location.startsWith('/groups/join/') ||
      RegExp(r'^/groups/[^/]+/chat$').hasMatch(location);
}

bool _isLockAllowedRoute(String location) {
  return location == '/unlock' ||
      location == '/app-lock/pin' ||
      location == '/locked/sos' ||
      location == '/settings/app-lock/setup' ||
      location.startsWith('/setup/') ||
      location == '/splash' ||
      location == '/login' ||
      location == '/register';
}

CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

CustomTransitionPage<void> _slidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
