import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/bridge_record_model.dart';

class BridgeActivityTile extends StatelessWidget {
  const BridgeActivityTile({required this.record, super.key});

  final BridgeRecordModel record;

  @override
  Widget build(BuildContext context) {
    final failed = record.status == 'failed';
    final duplicate = record.status == 'duplicate_ignored';
    final color = failed
        ? AppColors.danger
        : duplicate
            ? AppColors.warning
            : AppColors.success;
    final icon = record.direction == 'online_to_offline'
        ? Icons.cloud_download_rounded
        : Icons.cloud_upload_rounded;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(_title),
        subtitle: Text(_subtitle),
        trailing: Text(
          record.status.replaceAll('_', ' '),
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  String get _title {
    final arrow = record.direction == 'online_to_offline'
        ? 'online -> offline'
        : 'offline -> online';
    return '${record.originDisplayName ?? 'Unknown origin'} · $arrow';
  }

  String get _subtitle {
    final details = [
      'Channel ${record.channelCode}',
      if (record.bridgedByName != null) 'via ${record.bridgedByName}',
      if (record.errorMessage != null) record.errorMessage!,
    ];
    return details.join(' · ');
  }
}
