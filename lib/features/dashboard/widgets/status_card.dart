import 'package:flutter/material.dart';

import '../../../core/services/system_status_service.dart';
import '../../../shared/widgets/animated_status_card.dart';

class StatusCard extends StatelessWidget {
  const StatusCard({
    required this.result,
    required this.icon,
    this.delay = Duration.zero,
    super.key,
  });

  final SystemCheckResult result;
  final IconData icon;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return AnimatedStatusCard(
      title: result.title,
      message: result.message,
      detail: result.detail,
      state: result.state,
      icon: icon,
      delay: delay,
    );
  }
}
