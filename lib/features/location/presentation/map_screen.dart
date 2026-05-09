import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/mode/mode_controller.dart';
import '../../../core/mode/mode_models.dart';
import '../../../core/settings/settings_service.dart';
import '../../../shared/widgets/compact_status_chip.dart';
import '../../../shared/widgets/mode_status_widgets.dart';
import '../data/models/location_freshness.dart';
import 'location_controller.dart';
import 'widgets/location_freshness_chip.dart';
import 'map_provider_config.dart';
import 'widgets/trail_map_card.dart';

final _locationSharingEnabledProvider = FutureProvider<bool>((ref) async {
  final settings = ref.read(settingsServiceProvider);
  return await settings.getBool('enable_offline_location_share', true) &&
      await settings.getBool('offline_location_share_enabled', true);
});

class MapFocus {
  const MapFocus({
    required this.latitude,
    required this.longitude,
    required this.title,
    this.subtitle,
    this.isEmergency = false,
  });

  final double latitude;
  final double longitude;
  final String title;
  final String? subtitle;
  final bool isEmergency;

  factory MapFocus.fromExtra(Object? extra) {
    if (extra is! Map) return nullFocus;
    final latitude = double.tryParse(extra['latitude']?.toString() ?? '');
    final longitude = double.tryParse(extra['longitude']?.toString() ?? '');
    if (latitude == null || longitude == null) return nullFocus;
    return MapFocus(
      latitude: latitude,
      longitude: longitude,
      title: extra['title']?.toString() ?? 'Tracked location',
      subtitle: extra['subtitle']?.toString(),
      isEmergency: extra['isEmergency'] == true,
    );
  }

  static const nullFocus = MapFocus(
    latitude: 0,
    longitude: 0,
    title: '',
  );

  bool get hasValue => title.isNotEmpty;
}

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({
    this.groupId,
    this.offlineChannelId,
    this.focus = MapFocus.nullFocus,
    super.key,
  });

  final String? groupId;
  final String? offlineChannelId;
  final MapFocus focus;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  bool _coordinateViewOnly = false;
  int _mapRefreshToken = 0;
  TrailMapViewport? _manualViewport;

  @override
  Widget build(BuildContext context) {
    final args = LocationContextArgs(
      groupId: widget.groupId,
      offlineChannelId: widget.offlineChannelId,
    );
    final state = ref.watch(locationControllerProvider(args));
    final controller = ref.read(locationControllerProvider(args).notifier);
    final modeState = ref.watch(modeControllerProvider);
    final sharingEnabled =
        ref.watch(_locationSharingEnabledProvider).asData?.value ?? true;
    final own = state.currentLocation;
    final viewport = _manualViewport ?? _viewportFor(own);
    final markers = <TrailMapMarker>[
      if (own != null)
        TrailMapMarker(
          id: 'me',
          latitude: own.latitude,
          longitude: own.longitude,
          title: 'My location',
          subtitle: own.shareStatus,
          color: AppColors.skyBlue,
          icon: Icons.my_location_rounded,
        ),
      ...state.teammates.map(
        (location) => TrailMapMarker(
          id: 'teammate-${location.userId}',
          latitude: location.latitude,
          longitude: location.longitude,
          title: location.userName,
          subtitle: '${location.freshness.label} - ${location.source}',
          color: _colorFor(location.freshness),
          icon: Icons.person_pin_circle_rounded,
        ),
      ),
      if (widget.focus.hasValue)
        TrailMapMarker(
          id: 'focus-location',
          latitude: widget.focus.latitude,
          longitude: widget.focus.longitude,
          title: widget.focus.title,
          subtitle: widget.focus.subtitle,
          color: widget.focus.isEmergency
              ? AppColors.danger
              : AppColors.signalOrange,
          icon: widget.focus.isEmergency
              ? Icons.emergency_share_rounded
              : Icons.location_on_rounded,
        ),
    ];
    final mapNotice = modeState.effectiveMode == EffectiveMode.online
        ? 'Map tiles are loaded online. Saved teammate locations remain available offline.'
        : 'Offline mode: map tiles may be unavailable, but saved coordinates and teammate cards remain available.';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map & Locations'),
        actions: [
          IconButton(
            tooltip: 'Emergency History',
            onPressed: () => context.go('/emergency-history'),
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
            children: [
              CompactStatusRow(
                children: [
                  ModeStatusChip(state: modeState),
                  CompactStatusChip(
                    label: own == null ? 'GPS pending' : 'GPS ready',
                    color: own == null ? AppColors.warning : AppColors.success,
                    icon: own == null
                        ? Icons.gps_not_fixed_rounded
                        : Icons.gps_fixed_rounded,
                    dense: true,
                  ),
                  CompactStatusChip(
                    label:
                        '${state.teammates.length} ${state.teammates.length == 1 ? 'teammate' : 'teammates'}',
                    color: state.teammates.isEmpty
                        ? AppColors.muted
                        : AppColors.skyBlue,
                    icon: Icons.group_rounded,
                    dense: true,
                  ),
                ],
              ),
              if (!sharingEnabled) ...[
                const SizedBox(height: 12),
                const SmallWarningStrip(
                  message:
                      'Location sharing is disabled. Cached locations may still be visible.',
                  icon: Icons.location_off_rounded,
                  color: AppColors.warning,
                ),
              ],
              const SizedBox(height: 12),
              TrailMapCard(
                key: ValueKey(_mapRefreshToken),
                providerType: MapProviderConfig.current,
                viewport: viewport,
                markers: markers,
                showCoordinateView: _coordinateViewOnly,
                onRetry: _retryMap,
                onUseCoordinateView: () {
                  setState(() => _coordinateViewOnly = true);
                },
              ),
              const SizedBox(height: 10),
              InlineInfoNotice(
                message: mapNotice,
                icon: Icons.map_outlined,
              ),
              if (widget.focus.hasValue) ...[
                const SizedBox(height: 12),
                _FocusLocationCard(focus: widget.focus),
              ],
              if (own != null) ...[
                const SizedBox(height: 12),
                CoordinateLocationCard.fromOwnLocation(own),
              ],
              const SizedBox(height: 14),
              _MapControls(
                isBusy: state.isSharing,
                sharingEnabled: sharingEnabled,
                onGetGps: controller.getCurrentLocation,
                onShareLocation: controller.shareLocation,
                onCenterOnMe: () => _centerOnMe(own),
                onRefresh: () async {
                  _retryMap();
                  await controller.refresh();
                },
              ),
              if (state.infoMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  state.infoMessage!,
                  style: const TextStyle(color: AppColors.success),
                ),
              ],
              if (state.errorMessage != null) ...[
                const SizedBox(height: 10),
                if (_isPermissionError(state.errorMessage!))
                  const SmallWarningStrip(
                    message: 'Location permission is needed to center on you.',
                    icon: Icons.location_disabled_rounded,
                    color: AppColors.warning,
                  )
                else
                  Text(
                    state.errorMessage!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
              ],
              const SizedBox(height: 18),
              Text(
                'Last Known Teammates',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (state.teammates.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No teammates found yet.'),
                  ),
                )
              else
                ...state.teammates.map(
                  (location) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.person_pin_circle_rounded),
                      title: Text(location.userName),
                      subtitle: Text(
                        '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}\n'
                        '${DateFormat.jm().format(location.capturedAt)} - ${location.source}',
                      ),
                      trailing:
                          LocationFreshnessChip(freshness: location.freshness),
                      onTap: () {
                        setState(() {
                          _coordinateViewOnly = false;
                          _manualViewport = TrailMapViewport(
                            latitude: location.latitude,
                            longitude: location.longitude,
                            zoom: TrailMapDefaults.detailZoom,
                          );
                        });
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  TrailMapViewport _viewportFor(own) {
    if (widget.focus.hasValue) {
      return TrailMapViewport(
        latitude: widget.focus.latitude,
        longitude: widget.focus.longitude,
        zoom: TrailMapDefaults.detailZoom,
      );
    }
    if (own != null) {
      return TrailMapViewport(
        latitude: own.latitude,
        longitude: own.longitude,
        zoom: TrailMapDefaults.detailZoom,
      );
    }
    return const TrailMapViewport(
      latitude: TrailMapDefaults.sriLankaLatitude,
      longitude: TrailMapDefaults.sriLankaLongitude,
      zoom: TrailMapDefaults.countryZoom,
    );
  }

  void _retryMap() {
    setState(() {
      _coordinateViewOnly = false;
      _mapRefreshToken += 1;
    });
  }

  void _centerOnMe(own) {
    if (own == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Get GPS first to center on you.')),
      );
      return;
    }
    setState(() {
      _coordinateViewOnly = false;
      _manualViewport = TrailMapViewport(
        latitude: own.latitude,
        longitude: own.longitude,
        zoom: TrailMapDefaults.detailZoom,
      );
    });
  }

  bool _isPermissionError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('permission') ||
        normalized.contains('location services');
  }

  Color _colorFor(LocationFreshness freshness) {
    return switch (freshness) {
      LocationFreshness.fresh => AppColors.success,
      LocationFreshness.old => AppColors.warning,
      LocationFreshness.stale => AppColors.danger,
    };
  }
}

class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.isBusy,
    required this.sharingEnabled,
    required this.onGetGps,
    required this.onShareLocation,
    required this.onCenterOnMe,
    required this.onRefresh,
  });

  final bool isBusy;
  final bool sharingEnabled;
  final VoidCallback onGetGps;
  final VoidCallback onShareLocation;
  final VoidCallback onCenterOnMe;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: itemWidth,
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : onGetGps,
                icon: const Icon(Icons.gps_fixed_rounded),
                label: const Text('Get GPS'),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: FilledButton.icon(
                onPressed: isBusy || !sharingEnabled ? null : onShareLocation,
                icon: const Icon(Icons.share_location_rounded),
                label: const Text('Share Location'),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : onCenterOnMe,
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Center on Me'),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FocusLocationCard extends StatelessWidget {
  const _FocusLocationCard({required this.focus});

  final MapFocus focus;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: focus.isEmergency
          ? AppColors.danger.withValues(alpha: 0.08)
          : AppColors.skyBlue.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              focus.isEmergency
                  ? Icons.emergency_share_rounded
                  : Icons.location_on_rounded,
              color: focus.isEmergency ? AppColors.danger : AppColors.skyBlue,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    focus.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if ((focus.subtitle ?? '').isNotEmpty) Text(focus.subtitle!),
                  Text(
                    '${focus.latitude.toStringAsFixed(6)}, ${focus.longitude.toStringAsFixed(6)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
