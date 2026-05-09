import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import 'emergency_controller.dart';

class EmergencyHistoryScreen extends ConsumerWidget {
  const EmergencyHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const args = EmergencyContextArgs();
    final state = ref.watch(emergencyControllerProvider(args));
    final controller = ref.read(emergencyControllerProvider(args).notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency History')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (state.events.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('No emergency history saved on this device.'),
                  ),
                )
              else
                ...state.events.map(
                  (event) => Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.emergency_share_rounded,
                        color: AppColors.danger,
                      ),
                      title: Text(event.message ?? 'Emergency alert'),
                      subtitle: Text(
                        '${event.deliveryMode} - ${DateFormat.yMMMd().add_jm().format(event.createdAt)}',
                      ),
                      trailing: Chip(label: Text(event.status)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
