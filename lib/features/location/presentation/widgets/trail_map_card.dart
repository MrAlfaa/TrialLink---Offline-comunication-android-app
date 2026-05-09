import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' as osm;
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../../../core/constants/app_colors.dart';
import '../../data/models/location_freshness.dart';
import '../../data/models/location_update_model.dart';
import '../../data/models/teammate_location_model.dart';
import '../map_provider_config.dart';

class TrailMapViewport {
  const TrailMapViewport({
    required this.latitude,
    required this.longitude,
    required this.zoom,
  });

  final double latitude;
  final double longitude;
  final double zoom;
}

class TrailMapMarker {
  const TrailMapMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.title,
    required this.color,
    required this.icon,
    this.subtitle,
  });

  final String id;
  final double latitude;
  final double longitude;
  final String title;
  final String? subtitle;
  final Color color;
  final IconData icon;
}

class TrailMapCard extends StatefulWidget {
  const TrailMapCard({
    required this.providerType,
    required this.viewport,
    required this.markers,
    required this.showCoordinateView,
    required this.onRetry,
    required this.onUseCoordinateView,
    super.key,
  });

  final MapProviderType providerType;
  final TrailMapViewport viewport;
  final List<TrailMapMarker> markers;
  final bool showCoordinateView;
  final VoidCallback onRetry;
  final VoidCallback onUseCoordinateView;

  @override
  State<TrailMapCard> createState() => _TrailMapCardState();
}

class _TrailMapCardState extends State<TrailMapCard> {
  final _osmController = osm.MapController();
  google.GoogleMapController? _googleController;
  bool _mapUnavailable = false;

  @override
  void didUpdateWidget(covariant TrailMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewport.latitude == widget.viewport.latitude &&
        oldWidget.viewport.longitude == widget.viewport.longitude &&
        oldWidget.viewport.zoom == widget.viewport.zoom) {
      return;
    }
    if (widget.providerType == MapProviderType.openStreetMap &&
        !widget.showCoordinateView) {
      final osmTarget = latlong.LatLng(
        widget.viewport.latitude,
        widget.viewport.longitude,
      );
      try {
        _osmController.move(osmTarget, widget.viewport.zoom);
      } catch (_) {
        // The controller can be unattached during the first provider switch.
      }
    }
    _googleController?.animateCamera(
      google.CameraUpdate.newCameraPosition(
        google.CameraPosition(
          target: google.LatLng(
            widget.viewport.latitude,
            widget.viewport.longitude,
          ),
          zoom: widget.viewport.zoom,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(18);
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: 330,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.borderSoft),
            borderRadius: borderRadius,
          ),
          child: _buildMapBody(context),
        ),
      ),
    );
  }

  Widget _buildMapBody(BuildContext context) {
    if (widget.showCoordinateView ||
        widget.providerType == MapProviderType.fallbackListOnly ||
        _mapUnavailable) {
      return MapUnavailablePanel(
        onRetry: () {
          setState(() => _mapUnavailable = false);
          widget.onRetry();
        },
        onUseCoordinateView: widget.onUseCoordinateView,
      );
    }

    return switch (widget.providerType) {
      MapProviderType.googleMaps => _GoogleTrailMap(
          viewport: widget.viewport,
          markers: widget.markers,
          onMapCreated: (controller) => _googleController = controller,
        ),
      MapProviderType.openStreetMap => _OpenStreetTrailMap(
          controller: _osmController,
          viewport: widget.viewport,
          markers: widget.markers,
          onTileError: () {
            if (mounted) setState(() => _mapUnavailable = true);
          },
        ),
      MapProviderType.fallbackListOnly => MapUnavailablePanel(
          onRetry: widget.onRetry,
          onUseCoordinateView: widget.onUseCoordinateView,
        ),
    };
  }
}

class _GoogleTrailMap extends StatelessWidget {
  const _GoogleTrailMap({
    required this.viewport,
    required this.markers,
    required this.onMapCreated,
  });

  final TrailMapViewport viewport;
  final List<TrailMapMarker> markers;
  final void Function(google.GoogleMapController controller) onMapCreated;

  @override
  Widget build(BuildContext context) {
    return google.GoogleMap(
      initialCameraPosition: google.CameraPosition(
        target: google.LatLng(viewport.latitude, viewport.longitude),
        zoom: viewport.zoom,
      ),
      markers: markers
          .map(
            (marker) => google.Marker(
              markerId: google.MarkerId(marker.id),
              position: google.LatLng(marker.latitude, marker.longitude),
              infoWindow: google.InfoWindow(
                title: marker.title,
                snippet: marker.subtitle,
              ),
              icon: google.BitmapDescriptor.defaultMarkerWithHue(
                _googleHueFor(marker.color),
              ),
            ),
          )
          .toSet(),
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
      mapToolbarEnabled: true,
      onMapCreated: onMapCreated,
    );
  }

  static double _googleHueFor(Color color) {
    if (color == AppColors.success) return google.BitmapDescriptor.hueGreen;
    if (color == AppColors.warning) return google.BitmapDescriptor.hueOrange;
    if (color == AppColors.danger) return google.BitmapDescriptor.hueRed;
    if (color == AppColors.skyBlue) return google.BitmapDescriptor.hueAzure;
    return google.BitmapDescriptor.hueViolet;
  }
}

class _OpenStreetTrailMap extends StatelessWidget {
  const _OpenStreetTrailMap({
    required this.controller,
    required this.viewport,
    required this.markers,
    required this.onTileError,
  });

  final osm.MapController controller;
  final TrailMapViewport viewport;
  final List<TrailMapMarker> markers;
  final VoidCallback onTileError;

  @override
  Widget build(BuildContext context) {
    return osm.FlutterMap(
      mapController: controller,
      options: osm.MapOptions(
        initialCenter: latlong.LatLng(viewport.latitude, viewport.longitude),
        initialZoom: viewport.zoom,
        minZoom: 3,
        maxZoom: 18,
        backgroundColor: AppColors.softSand,
      ),
      children: [
        osm.TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.traillink',
          errorTileCallback: (_, __, ___) => onTileError(),
        ),
        osm.MarkerLayer(
          markers: markers
              .map(
                (marker) => osm.Marker(
                  point: latlong.LatLng(marker.latitude, marker.longitude),
                  width: 42,
                  height: 42,
                  child: _MapPin(marker: marker),
                ),
              )
              .toList(),
        ),
        osm.SimpleAttributionWidget(
          source: Text(
            'OpenStreetMap contributors',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.deepForest,
                  fontWeight: FontWeight.w800,
                ),
          ),
          backgroundColor: AppColors.surface.withValues(alpha: 0.86),
        ),
      ],
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.marker});

  final TrailMapMarker marker;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: marker.color, width: 2),
      ),
      child: Icon(marker.icon, color: marker.color, size: 22),
    );
  }
}

class MapUnavailablePanel extends StatelessWidget {
  const MapUnavailablePanel({
    required this.onRetry,
    required this.onUseCoordinateView,
    super.key,
  });

  final VoidCallback onRetry;
  final VoidCallback onUseCoordinateView;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.softSand,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.map_outlined,
            color: AppColors.deepForest,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            'Map unavailable',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.charcoal,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Map tiles unavailable. Saved coordinates are still available.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry Map'),
              ),
              FilledButton.tonalIcon(
                onPressed: onUseCoordinateView,
                icon: const Icon(Icons.pin_drop_rounded),
                label: const Text('Use Coordinate View'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CoordinateLocationCard extends StatelessWidget {
  const CoordinateLocationCard({
    required this.title,
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    this.accuracy,
    this.subtitle,
    this.icon = Icons.my_location_rounded,
    super.key,
  });

  final String title;
  final String? subtitle;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime capturedAt;
  final IconData icon;

  factory CoordinateLocationCard.fromOwnLocation(
    LocationUpdateModel location,
  ) {
    return CoordinateLocationCard(
      title: 'My location',
      subtitle: location.shareStatus,
      latitude: location.latitude,
      longitude: location.longitude,
      accuracy: location.accuracy,
      capturedAt: location.capturedAt,
    );
  }

  factory CoordinateLocationCard.fromTeammate(
    TeammateLocationModel location,
  ) {
    return CoordinateLocationCard(
      title: location.userName,
      subtitle: '${location.freshness.label} - ${location.source}',
      latitude: location.latitude,
      longitude: location.longitude,
      accuracy: location.accuracy,
      capturedAt: location.capturedAt,
      icon: Icons.person_pin_circle_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final coordinates =
        '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.deepForest),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  if ((subtitle ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedText,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    coordinates,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (accuracy != null)
                        'Accuracy ${accuracy!.toStringAsFixed(0)} m',
                      'Captured ${DateFormat.jm().format(capturedAt)}',
                    ].join(' - '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedText,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Copy coordinates',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: coordinates));
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(content: Text('Coordinates copied.')),
                );
              },
              icon: const Icon(Icons.copy_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
