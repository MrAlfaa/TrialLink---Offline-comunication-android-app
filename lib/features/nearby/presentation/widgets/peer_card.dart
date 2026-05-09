import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/nearby_connection_status.dart';
import '../../data/models/nearby_peer_model.dart';
import 'peer_status_chip.dart';

class PeerCard extends StatelessWidget {
  const PeerCard({
    required this.peer,
    required this.onConnect,
    required this.onDisconnect,
    super.key,
  });

  final NearbyPeerModel peer;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final connected = peer.status == PeerConnectionStatus.connected;
    final connecting = peer.status == PeerConnectionStatus.connecting;
    final canConnect = peer.status == PeerConnectionStatus.discovered ||
        peer.status == PeerConnectionStatus.disconnected ||
        peer.status == PeerConnectionStatus.failed;
    final actionLabel = connected
        ? 'Disconnect'
        : connecting
            ? 'Connecting...'
            : peer.status == PeerConnectionStatus.lost
                ? 'Rediscover peer'
                : 'Connect';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.deepForest.withValues(alpha: 0.1),
                  foregroundColor: AppColors.deepForest,
                  child: const Icon(Icons.person_pin_circle_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        peer.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        peer.deviceName,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                PeerStatusChip(status: peer.status),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoPill(
                  icon: Icons.tag_rounded,
                  label: peer.activeChannelCode,
                ),
                _InfoPill(
                  icon: Icons.schedule_rounded,
                  label: 'Seen ${DateFormat('HH:mm').format(peer.lastSeenAt)}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: connected
                    ? onDisconnect
                    : canConnect
                        ? onConnect
                        : null,
                icon: Icon(
                  connected
                      ? Icons.link_off_rounded
                      : connecting
                          ? Icons.hourglass_top_rounded
                          : Icons.add_link_rounded,
                ),
                label: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.softSand,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.muted),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
