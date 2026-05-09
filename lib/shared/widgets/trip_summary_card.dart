import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'animated_badge.dart';

class TripSummaryCard extends StatelessWidget {
  const TripSummaryCard({
    required this.title,
    required this.rows,
    this.badge,
    this.icon = Icons.hiking_rounded,
    this.color = AppColors.deepForest,
    super.key,
  });

  final String title;
  final List<TripSummaryRow> rows;
  final String? badge;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                if (badge != null) AnimatedBadge(label: badge!, color: color),
              ],
            ),
            const SizedBox(height: 14),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(row.label)),
                    Text(
                      row.value,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.right,
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

class TripSummaryRow {
  const TripSummaryRow(this.label, this.value);

  final String label;
  final String value;
}
