import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/identity/auth_access_controller.dart';
import '../../core/settings/settings_service.dart';
import '../app_lock/presentation/app_lock_controller.dart';
import '../auth/presentation/auth_controller.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _backgroundScale;
  late final Animation<double> _pulse;
  bool _routed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.96, end: 1.03).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _backgroundScale = Tween<double>(begin: 1, end: 1.035).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _routeAfterDelay();
  }

  Future<void> _routeAfterDelay() async {
    final settings = ref.read(settingsServiceProvider);
    final seen = await settings.getBool('splash_intro_seen', false);
    await Future<void>.delayed(seen
        ? const Duration(milliseconds: 2300)
        : const Duration(seconds: 20));
    if (!seen) await settings.setBool('splash_intro_seen', true);
    await _routeNow();
  }

  Future<void> _routeNow() async {
    if (_routed) return;
    _routed = true;
    await ref.read(appLockControllerProvider.notifier).initialize();
    final route =
        await ref.read(authAccessControllerProvider.notifier).evaluateStartup();
    if (!mounted) return;
    final access = ref.read(authAccessControllerProvider);
    if (access.user != null) {
      ref
          .read(authControllerProvider.notifier)
          .setAuthenticatedUser(access.user!);
    }
    final lock = ref.read(appLockControllerProvider);
    if (lock.appLockEnabled &&
        lock.pinConfigured &&
        lock.isLocked &&
        route == '/home') {
      context.go('/unlock');
      return;
    }
    context.go(route);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _routeNow,
      child: Scaffold(
        backgroundColor: AppColors.deepForest,
        body: Stack(
          fit: StackFit.expand,
          children: [
            ScaleTransition(
              scale: _backgroundScale,
              child: Image.asset(
                'assets/branding/splash_mountains_signal.png',
                fit: BoxFit.cover,
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.deepForest.withValues(alpha: 0.06),
                    AppColors.deepForest.withValues(alpha: 0.36),
                    AppColors.deepForest.withValues(alpha: 0.86),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 176,
                        height: 176,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _pulse,
                              builder: (context, _) => CustomPaint(
                                painter: _SignalPulsePainter(
                                  progress: _pulse.value,
                                  color: AppColors.signalOrange,
                                ),
                                size: const Size.square(176),
                              ),
                            ),
                            ScaleTransition(
                              scale: _scale,
                              child: Container(
                                width: 122,
                                height: 122,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.94),
                                  borderRadius: BorderRadius.circular(34),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.82),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.signalOrange
                                          .withValues(alpha: 0.28),
                                      blurRadius: 34,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(30),
                                  child: Image.asset(
                                    'assets/branding/traillink_logo.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                      Text(
                        AppStrings.appName,
                        style:
                            Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Stay connected. Even off-grid.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 18),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: Text(
                            'Tap to skip',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalPulsePainter extends CustomPainter {
  const _SignalPulsePainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (var i = 0; i < 3; i++) {
      final phase = (progress + i / 3) % 1;
      paint.color = color.withValues(alpha: (1 - phase) * 0.28);
      canvas.drawCircle(center, 48 + phase * 44, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignalPulsePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
