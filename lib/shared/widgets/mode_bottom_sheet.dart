import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/mode/mode_controller.dart';
import '../../core/mode/mode_models.dart';
import '../../features/offline_channel/presentation/offline_channel_controller.dart';
import 'settings_info_box.dart';

class ModeBottomSheet extends ConsumerStatefulWidget {
  const ModeBottomSheet({super.key});

  @override
  ConsumerState<ModeBottomSheet> createState() => _ModeBottomSheetState();
}

class _ModeBottomSheetState extends ConsumerState<ModeBottomSheet> {
  late ManualCommunicationMode _draftMode;

  @override
  void initState() {
    super.initState();
    _draftMode = ref.read(modeControllerProvider).manualCommunicationMode;
  }

  @override
  Widget build(BuildContext context) {
    final modeState = ref.watch(modeControllerProvider);
    final activeChannel = ref.watch(activeUsableOfflineChannelProvider);
    final backendOnline = modeState.backendReachable;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: 20 + MediaQuery.paddingOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.disabledGrey,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Communication Mode',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              const Text('Manual Mode lets you choose the active path.'),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.skyBlueSoft,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                      color: AppColors.skyBlue.withValues(alpha: 0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detected Connection',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    _InfoLine(
                      label: 'Backend',
                      value: backendOnline ? 'Online' : 'Not reachable',
                    ),
                    _InfoLine(
                      label: 'Network',
                      value: modeState.hasNetworkInterface
                          ? modeState.connectionState.label
                          : 'No network interface',
                    ),
                    activeChannel.when(
                      data: (channel) => _InfoLine(
                        label: 'Offline Channel',
                        value: channel == null
                            ? 'No active channel'
                            : channel.channelCode,
                      ),
                      loading: () => const _InfoLine(
                        label: 'Offline Channel',
                        value: 'Checking...',
                      ),
                      error: (_, __) => const _InfoLine(
                        label: 'Offline Channel',
                        value: 'Unavailable',
                      ),
                    ),
                    _InfoLine(
                      label: 'Effective Preview',
                      value: _effectivePreview(modeState),
                    ),
                    _InfoLine(
                      label: 'Nearby Peers',
                      value: '${modeState.connectedPeerCount} connected',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...ManualCommunicationMode.values.map(_modeOption),
              if (_draftMode == ManualCommunicationMode.offline &&
                  backendOnline) ...[
                const SizedBox(height: 10),
                const SettingsInfoBox(
                  message:
                      'Offline Mode active. Internet is available, but cloud sync is paused.',
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.warning,
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () async {
                  await ref
                      .read(modeControllerProvider.notifier)
                      .setManualCommunicationMode(_draftMode);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_applyMessage(_draftMode))),
                    );
                  }
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('Apply Mode'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeOption(ManualCommunicationMode mode) {
    final selected = _draftMode == mode;
    final userMode = mode.userMode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _draftMode = mode),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? userMode.color.withValues(alpha: 0.12)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? userMode.color.withValues(alpha: 0.32)
                  : AppColors.borderSoft,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? userMode.color : AppColors.disabledGrey,
                    width: 2,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: userMode.color,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Icon(userMode.icon, color: userMode.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${mode.label} Mode',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(userMode.description),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _effectivePreview(ModeState current) {
    return switch (_draftMode) {
      ManualCommunicationMode.online => 'Online',
      ManualCommunicationMode.offline => 'Offline',
    };
  }

  String _applyMessage(ManualCommunicationMode mode) {
    return switch (mode) {
      ManualCommunicationMode.online =>
        'Online Mode selected. TrailLink will prefer cloud communication.',
      ManualCommunicationMode.offline =>
        'Offline Mode selected. TrailLink will use nearby and local communication.',
    };
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
