import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/bridge_settings_model.dart';

class BridgeStatusCard extends StatelessWidget {
  const BridgeStatusCard({
    required this.settings,
    required this.backendReachable,
    required this.connectedPeerCount,
    required this.channelCode,
    super.key,
  });

  final BridgeSettingsModel settings;
  final bool backendReachable;
  final int connectedPeerCount;
  final String? channelCode;

  @override
  Widget build(BuildContext context) {
    final active = settings.bridgeEnabled && channelCode != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.offlinePurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.cable_rounded,
                    color: AppColors.offlinePurple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bridge Mode',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(active ? 'Status: Active' : 'Status: Not ready'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _row('Channel', channelCode ?? 'No active channel'),
            _row('Nearby offline peers', '$connectedPeerCount'),
            _row('Backend', backendReachable ? 'Online' : 'Unavailable'),
            _row('Text bridge', settings.bridgeText ? 'ON' : 'OFF'),
            _row('SOS bridge', settings.bridgeSos ? 'ON' : 'OFF'),
            _row('Location bridge', settings.bridgeLocation ? 'ON' : 'OFF'),
            _row(
              'Voice bridge',
              settings.bridgeNormalVoice
                  ? 'Normal and emergency'
                  : settings.bridgeEmergencyVoice
                      ? 'Emergency only'
                      : 'OFF',
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
