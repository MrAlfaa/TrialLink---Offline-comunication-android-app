import 'package:flutter/material.dart';

import '../../core/config/offline_text_only_flags.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/animated_status_card.dart';
import '../../core/services/system_status_service.dart';

class OfflineFeatureDisabledScreen extends StatelessWidget {
  const OfflineFeatureDisabledScreen({
    required this.featureName,
    required this.icon,
    this.message = OfflineTextOnlyFlags.disabledMessage,
    super.key,
  });

  final String featureName;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(featureName)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: AppColors.deepForest,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(icon, color: Colors.white, size: 48),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    featureName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  AnimatedStatusCard(
                    title: OfflineTextOnlyFlags.disabledTitle,
                    message: message,
                    state: SystemCheckState.warning,
                    icon: Icons.chat_bubble_outline_rounded,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
