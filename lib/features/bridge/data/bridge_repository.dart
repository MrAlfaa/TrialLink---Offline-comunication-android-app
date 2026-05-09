import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bridge_local_data_source.dart';
import 'models/bridge_record_model.dart';
import 'models/bridge_settings_model.dart';

final bridgeRepositoryProvider = Provider<BridgeRepository>((ref) {
  return BridgeRepository(local: BridgeLocalDataSource());
});

class BridgeRepository {
  BridgeRepository({BridgeLocalDataSource? local})
      : _local = local ?? BridgeLocalDataSource();

  final BridgeLocalDataSource _local;

  Future<BridgeSettingsModel> getSettings() => _local.getSettings();

  Future<void> saveSettings(BridgeSettingsModel settings) {
    return _local.saveSettings(settings);
  }

  Future<bool> isProcessed(String uniqueItemId) {
    return _local.processedExists(uniqueItemId);
  }

  Future<void> markProcessed({
    required String uniqueItemId,
    required String itemType,
    required String sourcePath,
  }) {
    return _local.markProcessed(
      uniqueItemId: uniqueItemId,
      itemType: itemType,
      sourcePath: sourcePath,
    );
  }

  Future<void> saveRecord(BridgeRecordModel record) {
    return _local.saveRecord(record);
  }

  Future<List<BridgeRecordModel>> lastRecords({int limit = 25}) {
    return _local.lastRecords(limit: limit);
  }

  Future<List<Map<String, Object?>>> lastProcessed({int limit = 10}) {
    return _local.lastProcessed(limit: limit);
  }

  Future<void> clearDebugRecords() => _local.clearDebugRecords();
}
