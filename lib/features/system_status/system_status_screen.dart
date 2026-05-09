import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/system_status_service.dart';
import '../../shared/widgets/animated_status_card.dart';
import '../../shared/widgets/connection_mode_banner.dart';
import '../../shared/widgets/primary_button.dart';
import 'system_status_controller.dart';

class SystemStatusScreen extends ConsumerWidget {
  const SystemStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(systemStatusControllerProvider);
    final controller = ref.read(systemStatusControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Status'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const ConnectionModeBanner(),
            const SizedBox(height: 18),
            Text(
              'Run Phase 01 health checks',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Use these checks during demos to confirm the app, backend, MongoDB Atlas, local SQLite, environment config, and local session are working.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Run All Checks',
              icon: Icons.play_circle_rounded,
              onPressed: controller.runAll,
            ),
            const SizedBox(height: 14),
            _CheckButton(
              label: 'Test Backend Connection',
              icon: Icons.api_rounded,
              onPressed: () => controller.runCheck(SystemCheckType.backend),
            ),
            _CheckButton(
              label: 'Test MongoDB Connection',
              icon: Icons.cloud_done_rounded,
              onPressed: () => controller.runCheck(SystemCheckType.mongo),
            ),
            _CheckButton(
              label: 'Test Local SQLite',
              icon: Icons.storage_rounded,
              onPressed: () => controller.runCheck(SystemCheckType.sqlite),
            ),
            _CheckButton(
              label: 'Test Environment Config',
              icon: Icons.tune_rounded,
              onPressed: () => controller.runCheck(SystemCheckType.environment),
            ),
            _CheckButton(
              label: 'Test Local Session',
              icon: Icons.person_pin_circle_rounded,
              onPressed: () => controller.runCheck(SystemCheckType.session),
            ),
            const SizedBox(height: 18),
            ...SystemCheckType.values.map(
              (type) => _ResultCard(type: type, value: state[type]),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckButton extends StatelessWidget {
  const _CheckButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.type,
    required this.value,
  });

  final SystemCheckType type;
  final AsyncValue<SystemCheckResult>? value;

  @override
  Widget build(BuildContext context) {
    final result = value?.when(
          data: (result) => result,
          loading: () => SystemCheckResult(
            title: _title(type),
            message: 'Checking...',
            state: SystemCheckState.loading,
          ),
          error: (error, stackTrace) => SystemCheckResult(
            title: _title(type),
            message: 'Check failed.',
            detail: error.toString(),
            state: SystemCheckState.error,
          ),
        ) ??
        SystemCheckResult(
          title: _title(type),
          message: 'Not tested yet.',
          state: SystemCheckState.idle,
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedStatusCard(
        title: result.title,
        message: result.message,
        detail: result.detail,
        state: result.state,
        icon: _icon(type),
      ),
    );
  }

  String _title(SystemCheckType type) {
    return switch (type) {
      SystemCheckType.backend => 'Backend API',
      SystemCheckType.mongo => 'MongoDB Atlas',
      SystemCheckType.sqlite => 'Local SQLite',
      SystemCheckType.environment => 'Environment Config',
      SystemCheckType.session => 'Local Session',
    };
  }

  IconData _icon(SystemCheckType type) {
    return switch (type) {
      SystemCheckType.backend => Icons.api_rounded,
      SystemCheckType.mongo => Icons.cloud_done_rounded,
      SystemCheckType.sqlite => Icons.storage_rounded,
      SystemCheckType.environment => Icons.tune_rounded,
      SystemCheckType.session => Icons.person_pin_circle_rounded,
    };
  }
}
