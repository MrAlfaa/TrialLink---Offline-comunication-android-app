import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'core/config/env_config.dart';
import 'core/notifications/trail_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await EnvConfig.load();
  await TrailNotificationService.instance.initialize();
  runApp(const ProviderScope(child: TrailLinkApp()));
}
