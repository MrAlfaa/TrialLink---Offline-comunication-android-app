import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/compact_status_chip.dart';

class ChatHeaderChip {
  const ChatHeaderChip({
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;
}

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({
    required this.title,
    required this.subtitle,
    this.chips = const [],
    this.onDetailsPressed,
    this.detailsTooltip = 'Details',
    super.key,
  });

  final String title;
  final String subtitle;
  final List<ChatHeaderChip> chips;
  final VoidCallback? onDetailsPressed;
  final String detailsTooltip;

  @override
  Size get preferredSize => Size.fromHeight(chips.isEmpty ? 70 : 104);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: NavigationToolbar.kMiddleSpacing,
      toolbarHeight: 70,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.mutedText,
                ),
          ),
        ],
      ),
      actions: [
        if (onDetailsPressed != null)
          IconButton(
            tooltip: detailsTooltip,
            onPressed: onDetailsPressed,
            icon: const Icon(Icons.info_outline_rounded),
          ),
      ],
      bottom: chips.isEmpty
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(34),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    children: [
                      for (final chip in chips) ...[
                        CompactStatusChip(
                          label: chip.label,
                          color: chip.color,
                          icon: chip.icon,
                          dense: true,
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
