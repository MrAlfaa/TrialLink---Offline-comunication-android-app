import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/identity/local_identity_model.dart';

class LocalIdentityCard extends StatelessWidget {
  const LocalIdentityCard({
    super.key,
    required this.identity,
    this.onCreateCloudProfile,
  });

  final LocalIdentityModel identity;
  final VoidCallback? onCreateCloudProfile;

  @override
  Widget build(BuildContext context) {
    final isCloudReady = identity.isCloudReady;
    final publicUserId = identity.publicUserId;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isCloudReady
                      ? AppColors.deepForest
                      : AppColors.signalOrange,
                  foregroundColor: Colors.white,
                  child: Text(_initials(identity.displayName)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCloudReady
                            ? 'TrailLink Cloud Profile'
                            : 'Local TrailLink Profile',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        isCloudReady ? 'Cloud synced' : 'Local only',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Name: ${identity.displayName}'),
            if ((identity.email ?? '').isNotEmpty)
              Text('Email: ${identity.email}'),
            if (isCloudReady && publicUserId != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text('TrailLink ID: $publicUserId')),
                  IconButton(
                    tooltip: 'Copy TrailLink ID',
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: publicUserId)),
                    icon: const Icon(Icons.copy_rounded),
                  ),
                ],
              ),
            ],
            if (!isCloudReady && onCreateCloudProfile != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onCreateCloudProfile,
                icon: const Icon(Icons.cloud_upload_rounded),
                label: const Text('Create Cloud Profile'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'T';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
