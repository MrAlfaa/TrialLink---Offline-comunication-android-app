import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../shared/widgets/animated_status_card.dart';
import '../../core/services/system_status_service.dart';

class PlaceholderModuleScreen extends StatelessWidget {
  const PlaceholderModuleScreen({
    required this.title,
    required this.phase,
    required this.icon,
    required this.description,
    super.key,
  });

  final String title;
  final String phase;
  final IconData icon;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppColors.deepForest,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Icon(icon, color: Colors.white, size: 50),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 22),
                  AnimatedStatusCard(
                    title: 'Coming in $phase',
                    message:
                        'This screen is intentionally a polished placeholder in Phase 01.',
                    state: SystemCheckState.warning,
                    icon: Icons.construction_rounded,
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
