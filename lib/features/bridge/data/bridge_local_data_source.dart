import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database.dart';
import '../../nearby/data/models/nearby_connection_status.dart';
import '../../nearby/data/models/nearby_peer_model.dart';
import 'models/bridge_record_model.dart';
import 'models/bridge_settings_model.dart';

class BridgeLocalDataSource {
  BridgeLocalDataSource({LocalDatabase? database})
      : _database = database ?? LocalDatabase.instance;

  final LocalDatabase _database;

  Future<BridgeSettingsModel> getSettings() async {
    final db = await _database.database;
    final rows = await db.query('bridge_settings', limit: 1);
    if (rows.isNotEmpty) return BridgeSettingsModel.fromDb(rows.first);

    final defaults = BridgeSettingsModel.defaults();
    await db.insert('bridge_settings', defaults.toDbMap());
    return defaults;
  }

  Future<void> saveSettings(BridgeSettingsModel settings) async {
    final db = await _database.database;
    final existing = await db.query('bridge_settings', limit: 1);
    if (existing.isEmpty) {
      await db.insert('bridge_settings', settings.toDbMap());
      return;
    }
    await db.update(
      'bridge_settings',
      settings.toDbMap(),
      where: 'id = ?',
      whereArgs: [existing.first['id']],
    );
  }

  Future<bool> processedExists(String uniqueItemId) async {
    final db = await _database.database;
    final rows = await db.query(
      'processed_bridge_items',
      where: 'unique_item_id = ?',
      whereArgs: [uniqueItemId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> markProcessed({
    required String uniqueItemId,
    required String itemType,
    required String sourcePath,
  }) async {
    final db = await _database.database;
    await db.insert(
      'processed_bridge_items',
      {
        'unique_item_id': uniqueItemId,
        'item_type': itemType,
        'source_path': sourcePath,
        'processed_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> saveRecord(BridgeRecordModel record) async {
    final db = await _database.database;
    await db.insert(
      'bridged_messages',
      record.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<BridgeRecordModel>> lastRecords({int limit = 25}) async {
    final db = await _database.database;
    final rows = await db.query(
      'bridged_messages',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(BridgeRecordModel.fromDb).toList();
  }

  Future<List<Map<String, Object?>>> lastProcessed({int limit = 10}) async {
    final db = await _database.database;
    return db.query(
      'processed_bridge_items',
      orderBy: 'processed_at DESC',
      limit: limit,
    );
  }

  Future<List<NearbyPeerModel>> connectedPeers(String channelCode) async {
    final db = await _database.database;
    final rows = await db.query(
      'nearby_peers',
      where:
          'active_channel_code = ? AND connection_status = ? AND is_same_channel = 1',
      whereArgs: [channelCode, PeerConnectionStatus.connected.name],
      orderBy: 'last_seen_at DESC',
    );
    return rows.map(NearbyPeerModel.fromDb).toList();
  }

  Future<void> clearDebugRecords() async {
    final db = await _database.database;
    await db.delete('bridged_messages');
    await db.delete('processed_bridge_items');
  }
}
