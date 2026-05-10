import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/demo/frontend_demo_bootstrap.dart';
import 'core/config/env_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.load();
  if (EnvConfig.frontendOnlyDemo) {
    await FrontendDemoBootstrap.ensureReady();
  }
  runApp(const ProviderScope(child: TrailLinkApp()));
}
