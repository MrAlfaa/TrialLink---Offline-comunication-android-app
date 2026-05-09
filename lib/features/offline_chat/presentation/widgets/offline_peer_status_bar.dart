import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class OfflinePeerStatusBar extends StatelessWidget {
  const OfflinePeerStatusBar({
    required this.connectedCount,
    super.key,
  });

  final int connectedCount;

  @override
  Widget build(BuildContext context) {
    final connected = connectedCount > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: (connected ? AppColors.success : AppColors.warning)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            connected
                ? Icons.bluetooth_connected_rounded
                : Icons.bluetooth_searching_rounded,
            color: connected ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              connected
                  ? 'Connected to $connectedCount nearby peer${connectedCount == 1 ? "" : "s"}'
                  : 'No connected peers. Messages will be queued.',
              style: TextStyle(
                color: connected ? AppColors.success : AppColors.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
