import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../data/models/app_lock_status.dart';
import 'app_lock_controller.dart';
import 'widgets/app_lock_header.dart';
import 'widgets/pin_keypad.dart';

class AppLockPinScreen extends ConsumerStatefulWidget {
  const AppLockPinScreen({super.key});

  @override
  ConsumerState<AppLockPinScreen> createState() => _AppLockPinScreenState();
}

class _AppLockPinScreenState extends ConsumerState<AppLockPinScreen> {
  String _pin = '';
  bool _verifying = false;

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(appLockControllerProvider);
    final from = GoRouterState.of(context).uri.queryParameters['from'] ??
        lockState.intendedRoute ??
        '/home';
    final lockedOut = lockState.status == AppLockStatus.pinLockedOut &&
        lockState.pinLockoutUntil != null &&
        DateTime.now().isBefore(lockState.pinLockoutUntil!);

    return Scaffold(
      appBar: AppBar(title: const Text('TrailLink PIN')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const AppLockHeader(
              title: 'Enter TrailLink PIN',
              subtitle: 'Unlock private trip data with your local PIN.',
              icon: Icons.pin_rounded,
            ),
            const SizedBox(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Icon(
                    index < _pin.length
                        ? Icons.circle
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: index < _pin.length
                        ? AppColors.deepForest
                        : AppColors.disabledGrey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (lockState.message != null)
              Text(
                lockState.message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger),
              ),
            if (lockedOut)
              Text(
                'PIN locked until ${TimeOfDay.fromDateTime(lockState.pinLockoutUntil!).format(context)}.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger),
              ),
            const SizedBox(height: 22),
            PinKeypad(
              onDigit: lockedOut || _verifying
                  ? (_) {}
                  : (digit) {
                      if (_pin.length >= 4) return;
                      setState(() => _pin += digit);
                    },
              onClear: () => setState(() => _pin = ''),
              onDone: lockedOut || _verifying
                  ? () {}
                  : () async {
                      if (_pin.length != 4) return;
                      final router = GoRouter.of(context);
                      setState(() => _verifying = true);
                      final ok = await ref
                          .read(appLockControllerProvider.notifier)
                          .unlockWithPin(_pin);
                      if (!mounted) return;
                      setState(() {
                        _pin = '';
                        _verifying = false;
                      });
                      if (ok) router.go(_safeReturnRoute(from));
                    },
            ),
          ],
        ),
      ),
    );
  }
}

String _safeReturnRoute(String route) {
  if (route.isEmpty ||
      route == '/unlock' ||
      route.startsWith('/unlock?') ||
      route.startsWith('/app-lock/pin') ||
      route == '/locked/sos') {
    return '/home';
  }
  return route;
}
