import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/offline_channel_member_model.dart';

class LocalMemberTile extends StatelessWidget {
  const LocalMemberTile({
    required this.member,
    super.key,
  });

  final OfflineChannelMemberModel member;

  @override
  Widget build(BuildContext context) {
    final lastSeen = _lastSeenLabel(member.lastSeenAt);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.skyBlue.withValues(alpha: 0.14),
        child: Text(
          _initials(member.displayName),
          style: const TextStyle(
            color: AppColors.skyBlue,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      title: Text(member.displayName),
      subtitle: Text(
        '${member.identityTypeLabel} - ${member.presenceDescription}'
        '${lastSeen == null ? '' : ' - $lastSeen'}',
      ),
      trailing: Chip(
        label: Text(member.presenceStatusLabel),
        backgroundColor: member.presenceColor.withValues(alpha: 0.12),
        labelStyle: TextStyle(
          color: member.presenceColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String? _lastSeenLabel(DateTime? lastSeenAt) {
    if (lastSeenAt == null) return null;
    final diff = DateTime.now().difference(lastSeenAt);
    if (diff.inSeconds < 60) return 'last seen now';
    if (diff.inMinutes < 60) return 'last seen ${diff.inMinutes} min ago';
    if (diff.inHours < 24) return 'last seen ${diff.inHours} hr ago';
    return 'last seen ${diff.inDays} d ago';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'TL';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

extension OfflineMemberPresentation on OfflineChannelMemberModel {
  String get presenceStatusLabel {
    return switch (presenceStatus) {
      'connected' => 'Connected',
      'nearby' => 'Nearby',
      'recently_seen' => 'Recent',
      'disconnected' => 'Disconnected',
      _ => 'Unknown',
    };
  }

  String get presenceDescription {
    return switch (presenceStatus) {
      'connected' => 'Connected nearby',
      'nearby' => 'Nearby',
      'recently_seen' => 'Recently seen',
      'disconnected' => 'Disconnected',
      _ => 'Unknown presence',
    };
  }

  Color get presenceColor {
    return switch (presenceStatus) {
      'connected' => AppColors.success,
      'nearby' => AppColors.skyBlue,
      'recently_seen' => AppColors.warning,
      'disconnected' => AppColors.mutedText,
      _ => AppColors.mutedText,
    };
  }

  String get identityTypeLabel {
    return switch (identityType) {
      'authenticated_cached' => 'Cached User',
      'local_only' => 'Local User',
      'guest' => 'Offline Guest',
      _ => 'Offline Member',
    };
  }
}
