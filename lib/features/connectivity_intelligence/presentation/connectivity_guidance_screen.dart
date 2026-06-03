import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/mode/mode_controller.dart';
import '../../../shared/widgets/compact_status_chip.dart';
import '../../../shared/widgets/mode_status_widgets.dart';
import '../../offline_channel/presentation/offline_channel_controller.dart';
import 'connectivity_controller.dart';
import 'network_compass_controller.dart';
import 'widgets/guidance_banner.dart';
import 'widgets/network_health_card.dart';
import 'widgets/peer_quality_card.dart';

class ConnectivityGuidanceScreen extends ConsumerWidget {
  const ConnectivityGuidanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectivityControllerProvider);
    final controller = ref.read(connectivityControllerProvider.notifier);
    final summary = state.summary;
    final compassState = ref.watch(networkCompassControllerProvider);
    final compassController =
        ref.read(networkCompassControllerProvider.notifier);
    final modeState = ref.watch(modeControllerProvider);
    final activeChannel =
        ref.watch(activeUsableOfflineChannelProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Compass'),
        actions: [
          IconButton(
            tooltip: 'Measure now',
            onPressed: state.isRefreshing || compassState.isMeasuring
                ? null
                : () {
                    controller.refresh();
                    compassController.measureNow();
                  },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              controller.refresh(),
              compassController.measureNow(),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
            children: [
              _NetworkCompassCard(state: compassState),
              const SizedBox(height: 12),
              _BestInternetSpotCard(state: compassState),
              const SizedBox(height: 12),
              _RecentSpeedSamplesCard(state: compassState),
              const SizedBox(height: 18),
              CompactStatusRow(
                children: [
                  ModeStatusChip(state: modeState),
                  PeerStatusChip(count: summary?.qualities.length ?? 0),
                  CompactStatusChip(
                    label: '${summary?.pendingOfflineMessages ?? 0} waiting',
                    color: (summary?.pendingOfflineMessages ?? 0) > 0
                        ? AppColors.warning
                        : AppColors.muted,
                    icon: Icons.inventory_2_rounded,
                    dense: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (activeChannel != null) ...[
                CompactStatusChip(
                  label: activeChannel.channelCode,
                  color: AppColors.offlinePurple,
                  icon: Icons.hub_rounded,
                  dense: true,
                ),
                const SizedBox(height: 12),
              ],
              if (summary == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                if (activeChannel == null) ...[
                  InlineInfoNotice(
                    message:
                        'Create or join an offline trip to compare nearby phone connection quality.',
                    icon: Icons.hub_rounded,
                    action: TextButton(
                      onPressed: () => context.go('/offline-channel'),
                      child: const Text('Open'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                GuidanceBanner(guidance: summary.guidance),
                const SizedBox(height: 12),
                NetworkHealthCard(summary: summary),
                const SizedBox(height: 16),
                Text(
                  'Phone Connection Ranking',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (summary.qualities.isEmpty)
                  InlineInfoNotice(
                    message:
                        'Connect phones to collect delivery timing and message status.',
                    icon: Icons.radar_rounded,
                    action: TextButton(
                      onPressed: () => context.go('/nearby-peers'),
                      child: const Text('Open'),
                    ),
                  )
                else
                  ...summary.qualities.map(
                    (peer) => PeerQualityCard(peer: peer),
                  ),
              ],
              if (state.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  state.errorMessage!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NetworkCompassCard extends StatelessWidget {
  const _NetworkCompassCard({required this.state});

  final NetworkCompassState state;

  @override
  Widget build(BuildContext context) {
    final sample = state.currentSample;
    final speed = state.currentMbps;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.explore_rounded, color: AppColors.deepForest),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Internet direction finder',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                if (state.isMeasuring)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 210,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(240, 190),
                    painter: _SpeedometerPainter(
                      value: speed,
                      maxValue: 20,
                      color: _qualityColor(state.qualityLabel),
                    ),
                  ),
                  Positioned(
                    top: 28,
                    child: _CompassDial(heading: state.headingDegrees),
                  ),
                  Positioned(
                    bottom: 12,
                    child: Column(
                      children: [
                        Text(
                          speed <= 0 ? '--' : speed.toStringAsFixed(1),
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppColors.deepForest,
                              ),
                        ),
                        Text(
                          'Mbps download',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                CompactStatusChip(
                  label: state.qualityLabel,
                  color: _qualityColor(state.qualityLabel),
                  icon: sample?.backendReachable == true
                      ? Icons.wifi_tethering_rounded
                      : Icons.signal_wifi_bad_rounded,
                  dense: true,
                ),
                CompactStatusChip(
                  label: sample?.pingMs == null
                      ? 'Ping --'
                      : '${sample!.pingMs} ms',
                  color: AppColors.skyBlue,
                  icon: Icons.speed_rounded,
                  dense: true,
                ),
                CompactStatusChip(
                  label: sample?.networkType == null ||
                          sample!.networkType == 'none'
                      ? 'No network'
                      : sample.networkType,
                  color: AppColors.muted,
                  icon: Icons.network_cell_rounded,
                  dense: true,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'This checks the TrailLink server only. Your exact GPS location is saved on this phone and is not sent to the speed check.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                    height: 1.35,
                  ),
            ),
            if (sample?.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                'No internet measured here. Saved spots are still available.',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BestInternetSpotCard extends StatelessWidget {
  const _BestInternetSpotCard({required this.state});

  final NetworkCompassState state;

  @override
  Widget build(BuildContext context) {
    final best = state.bestSample;
    return Card(
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.success.withValues(alpha: 0.14),
          foregroundColor: AppColors.success,
          child: const Icon(Icons.place_rounded),
        ),
        title: const Text('Best internet spot nearby'),
        subtitle: Text(_bestSpotText(best, state)),
        trailing: state.bearingToBestDegrees == null
            ? null
            : Transform.rotate(
                angle: state.bearingToBestDegrees! * math.pi / 180,
                child: const Icon(Icons.navigation_rounded),
              ),
      ),
    );
  }

  String _bestSpotText(
    dynamic best,
    NetworkCompassState state,
  ) {
    if (best == null) return 'No measured spots yet. Walk and keep this open.';
    final speed = best.downloadMbps == null
        ? 'unknown speed'
        : '${best.downloadMbps!.toStringAsFixed(1)} Mbps';
    final distance = state.distanceToBestMeters == null
        ? null
        : state.distanceToBestMeters! < 1000
            ? '${state.distanceToBestMeters!.round()} m away'
            : '${(state.distanceToBestMeters! / 1000).toStringAsFixed(1)} km away';
    return [
      speed,
      if (distance != null) distance,
      DateFormat('h:mm a').format(best.createdAt),
    ].join(' - ');
  }
}

class _RecentSpeedSamplesCard extends StatelessWidget {
  const _RecentSpeedSamplesCard({required this.state});

  final NetworkCompassState state;

  @override
  Widget build(BuildContext context) {
    final samples = state.recentSamples.take(4).toList();
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Best Internet Spots',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            if (samples.isEmpty)
              Text(
                'Recent measurements will appear here.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                    ),
              )
            else
              ...samples.map(
                (sample) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Icon(
                        sample.backendReachable
                            ? Icons.wifi_rounded
                            : Icons.wifi_off_rounded,
                        color: _qualityColor(sample.qualityLabel),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${sample.qualityLabel} - ${sample.downloadMbps?.toStringAsFixed(1) ?? '--'} Mbps',
                        ),
                      ),
                      Text(
                        DateFormat('HH:mm').format(sample.createdAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CompassDial extends StatelessWidget {
  const _CompassDial({required this.heading});

  final double heading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.deepForest.withValues(alpha: 0.25),
                width: 2,
              ),
            ),
          ),
          Transform.rotate(
            angle: heading * math.pi / 180,
            child: const Icon(
              Icons.navigation_rounded,
              color: AppColors.signalOrange,
              size: 34,
            ),
          ),
          const Positioned(
            top: 6,
            child: Text('N', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _SpeedometerPainter extends CustomPainter {
  const _SpeedometerPainter({
    required this.value,
    required this.maxValue,
    required this.color,
  });

  final double value;
  final double maxValue;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.78);
    final radius = math.min(size.width * 0.42, size.height * 0.74);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final basePaint = Paint()
      ..color = AppColors.muted.withValues(alpha: 0.18)
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final valuePaint = Paint()
      ..color = color
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const start = math.pi;
    const sweep = math.pi;
    final progress = (value / maxValue).clamp(0.0, 1.0);
    canvas.drawArc(rect, start, sweep, false, basePaint);
    canvas.drawArc(rect, start, sweep * progress, false, valuePaint);

    final needleAngle = start + sweep * progress;
    final needleEnd = Offset(
      center.dx + math.cos(needleAngle) * (radius - 10),
      center.dy + math.sin(needleAngle) * (radius - 10),
    );
    final needlePaint = Paint()
      ..color = AppColors.charcoal
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleEnd, needlePaint);
    canvas.drawCircle(center, 7, Paint()..color = AppColors.charcoal);
  }

  @override
  bool shouldRepaint(_SpeedometerPainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.color != color;
  }
}

Color _qualityColor(String label) {
  return switch (label) {
    'Strong' => AppColors.success,
    'Good' => AppColors.skyBlue,
    'Usable' => AppColors.offlinePurple,
    'Weak' => AppColors.warning,
    _ => AppColors.danger,
  };
}
