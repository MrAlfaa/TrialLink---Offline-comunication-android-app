import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/system_status_service.dart';

final systemStatusServiceProvider = Provider<SystemStatusService>((ref) {
  return SystemStatusService();
});

final backendStatusProvider = FutureProvider<SystemCheckResult>((ref) {
  return ref.read(systemStatusServiceProvider).checkBackend();
});

final mongoStatusProvider = FutureProvider<SystemCheckResult>((ref) {
  return ref.read(systemStatusServiceProvider).checkMongoDb();
});

final sqliteStatusProvider = FutureProvider<SystemCheckResult>((ref) {
  return ref.read(systemStatusServiceProvider).checkSQLite();
});

final environmentStatusProvider = FutureProvider<SystemCheckResult>((ref) {
  return ref.read(systemStatusServiceProvider).checkEnvironment();
});

final sessionStatusProvider = FutureProvider<SystemCheckResult>((ref) {
  return ref.read(systemStatusServiceProvider).checkSession();
});
