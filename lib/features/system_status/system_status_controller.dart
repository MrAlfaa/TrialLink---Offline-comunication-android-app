import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/system_status_providers.dart';
import '../../core/services/system_status_service.dart';

enum SystemCheckType {
  backend,
  mongo,
  sqlite,
  environment,
  session,
}

class SystemStatusController
    extends StateNotifier<Map<SystemCheckType, AsyncValue<SystemCheckResult>>> {
  SystemStatusController(this._service) : super(const {});

  final SystemStatusService _service;

  Future<void> runCheck(SystemCheckType type) async {
    state = {...state, type: const AsyncValue.loading()};

    try {
      final result = switch (type) {
        SystemCheckType.backend => await _service.checkBackend(),
        SystemCheckType.mongo => await _service.checkMongoDb(),
        SystemCheckType.sqlite => await _service.checkSQLite(),
        SystemCheckType.environment => await _service.checkEnvironment(),
        SystemCheckType.session => await _service.checkSession(),
      };
      state = {...state, type: AsyncValue.data(result)};
    } catch (error, stackTrace) {
      state = {
        ...state,
        type: AsyncValue.error(error, stackTrace),
      };
    }
  }

  Future<void> runAll() async {
    for (final type in SystemCheckType.values) {
      await runCheck(type);
    }
  }
}

final systemStatusControllerProvider = StateNotifierProvider<
    SystemStatusController,
    Map<SystemCheckType, AsyncValue<SystemCheckResult>>>((ref) {
  return SystemStatusController(ref.read(systemStatusServiceProvider));
});
