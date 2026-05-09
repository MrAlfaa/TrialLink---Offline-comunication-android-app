import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/connectivity_intelligence_repository.dart';

class NetworkHealthCard extends StatelessWidget {
  const NetworkHealthCard({required this.summary, super.key});

  final ConnectivityIntelligenceSummary summary;

  @override
  Widget build(BuildContext context) {
    final bestPeer = summary.qualities.isEmpty
        ? 'No peer'
        : summary.qualities.first.displayName ?? 'Nearby peer';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.network_check_rounded,
                    color: AppColors.deepForest),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Network ${summary.overallLabel}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Best peer: $bestPeer'),
            Text('Queued offline packets: ${summary.pendingOfflineMessages}'),
            Text('Updated ${DateFormat.jm().format(summary.lastUpdatedAt)}'),
          ],
        ),
      ),
    );
  }
}
