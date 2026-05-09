import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/mode/mode_controller.dart';
import '../../../core/settings/settings_service.dart';
import '../../../shared/widgets/compact_status_chip.dart';
import '../../../shared/widgets/mode_status_widgets.dart';
import 'emergency_controller.dart';
import 'widgets/emergency_alert_card.dart';

final _sosPolicyProvider = FutureProvider<_SosPolicy>((ref) async {
  final settings = ref.read(settingsServiceProvider);
  final enabled = await settings.getBool('enable_offline_sos', true) &&
      await settings.getBool('offline_sos_enabled', true);
  final attachLocation = await settings.getBool('attach_location_to_sos', true);
  return _SosPolicy(enabled: enabled, attachLocation: attachLocation);
});

class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({
    this.groupId,
    this.offlineChannelId,
    super.key,
  });

  final String? groupId;
  final String? offlineChannelId;

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> {
  final _messageController = TextEditingController(text: 'Need help');

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = EmergencyContextArgs(
      groupId: widget.groupId,
      offlineChannelId: widget.offlineChannelId,
    );
    final state = ref.watch(emergencyControllerProvider(args));
    final controller = ref.read(emergencyControllerProvider(args).notifier);
    final modeState = ref.watch(modeControllerProvider);
    final policy = ref.watch(_sosPolicyProvider).asData?.value ??
        const _SosPolicy(enabled: true, attachLocation: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        actions: [
          IconButton(
            tooltip: 'Emergency History',
            onPressed: () => context.go('/emergency-history'),
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
            children: [
              CompactStatusRow(
                children: [
                  ModeStatusChip(state: modeState),
                  CompactStatusChip(
                    label: policy.attachLocation
                        ? 'Location attached'
                        : 'No location',
                    color: policy.attachLocation
                        ? AppColors.success
                        : AppColors.warning,
                    icon: policy.attachLocation
                        ? Icons.location_on_rounded
                        : Icons.location_off_rounded,
                    dense: true,
                  ),
                  const CompactStatusChip(
                    label: 'Retry on',
                    color: AppColors.skyBlue,
                    icon: Icons.sync_rounded,
                    dense: true,
                  ),
                ],
              ),
              if (!policy.enabled) ...[
                const SizedBox(height: 12),
                const SmallWarningStrip(
                  message: 'Offline SOS is disabled in Settings.',
                  icon: Icons.block_rounded,
                  color: AppColors.danger,
                ),
              ] else if (!policy.attachLocation) ...[
                const SizedBox(height: 12),
                const SmallWarningStrip(
                  message: 'SOS will be sent without location.',
                  icon: Icons.location_off_rounded,
                  color: AppColors.warning,
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: state.isSending || !policy.enabled
                          ? null
                          : () async {
                              final confirmed = await _confirmSos(context);
                              if (confirmed == true) {
                                await controller
                                    .triggerSos(_messageController.text);
                              }
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 156,
                        height: 156,
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.danger.withValues(alpha: 0.35),
                              blurRadius: 28,
                              spreadRadius: 6,
                            ),
                          ],
                        ),
                        child: Center(
                          child: state.isSending
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  'SOS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Use SOS only when you need urgent assistance. TrailLink will send the alert through backend and nearby peers when available.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _messageController,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Emergency message',
                        prefixIcon: Icon(Icons.warning_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              if (state.infoMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  state.infoMessage!,
                  style: const TextStyle(color: AppColors.success),
                ),
              ],
              if (state.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  state.errorMessage!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                'Latest Emergency',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (state.latestEvent == null)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No emergency alerts yet.'),
                  ),
                )
              else
                EmergencyAlertCard(
                  event: state.latestEvent!,
                  onAcknowledge: () =>
                      controller.acknowledge(state.latestEvent!),
                  onViewMap: () => context.go('/map'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmSos(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send emergency alert?'),
        content: const Text(
          'This will broadcast a high-priority SOS alert to available group members and nearby offline peers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send Now'),
          ),
        ],
      ),
    );
  }
}

class _SosPolicy {
  const _SosPolicy({
    required this.enabled,
    required this.attachLocation,
  });

  final bool enabled;
  final bool attachLocation;
}
