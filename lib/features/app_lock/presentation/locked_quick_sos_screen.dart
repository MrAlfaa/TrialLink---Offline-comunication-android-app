import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/settings/settings_service.dart';
import '../../../shared/widgets/settings_info_box.dart';
import '../data/app_lock_service.dart';

class LockedQuickSosScreen extends ConsumerStatefulWidget {
  const LockedQuickSosScreen({super.key});

  @override
  ConsumerState<LockedQuickSosScreen> createState() =>
      _LockedQuickSosScreenState();
}

class _LockedQuickSosScreenState extends ConsumerState<LockedQuickSosScreen> {
  bool _sending = false;
  String? _status;
  bool _attachLocation = true;

  @override
  void initState() {
    super.initState();
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    final attach = await ref
        .read(settingsServiceProvider)
        .getBool('attach_location_to_sos', true);
    if (mounted) setState(() => _attachLocation = attach);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency SOS')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SettingsInfoBox(
              message:
                  'Send emergency alert using the current active trip/channel. TrailLink will remain locked.',
              icon: Icons.emergency_share_rounded,
              color: AppColors.danger,
            ),
            if (!_attachLocation) ...[
              const SizedBox(height: 12),
              const SettingsInfoBox(
                message: 'SOS will be sent without location.',
                icon: Icons.location_off_rounded,
                color: AppColors.warning,
              ),
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(24),
                border:
                    Border.all(color: AppColors.danger.withValues(alpha: 0.22)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.emergency_share_rounded,
                    color: AppColors.danger,
                    size: 72,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Emergency SOS',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Location will be attached only if allowed in Safety Settings and permission exists.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            if (_status != null) ...[
              const SizedBox(height: 14),
              Text(
                _status!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _status!.toLowerCase().contains('failed')
                      ? AppColors.danger
                      : AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _sending ? null : () => context.go('/unlock'),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                    ),
                    onPressed: _sending ? null : _send,
                    child: _sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send SOS'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Send emergency SOS?'),
            content: const Text(
              'This sends or queues an emergency alert without unlocking private TrailLink data.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Send SOS'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    setState(() {
      _sending = true;
      _status = null;
    });
    final result =
        await ref.read(lockedQuickSosServiceProvider).triggerLockedQuickSos();
    if (!mounted) return;
    setState(() {
      _sending = false;
      _status = result.message;
    });
  }
}
