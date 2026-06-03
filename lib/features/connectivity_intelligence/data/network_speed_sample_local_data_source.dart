import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database.dart';
import 'models/network_speed_sample_model.dart';

class NetworkSpeedSampleLocalDataSource {
  NetworkSpeedSampleLocalDataSource({LocalDatabase? database})
      : _database = database ?? LocalDatabase.instance;

  final LocalDatabase _database;

  Future<void> insert(NetworkSpeedSampleModel sample) async {
    final db = await _database.database;
    await db.insert(
      'network_speed_samples',
      sample.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<NetworkSpeedSampleModel>> recent({int limit = 20}) async {
    final db = await _database.database;
    final rows = await db.query(
      'network_speed_samples',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(NetworkSpeedSampleModel.fromDb).toList();
  }

  Future<NetworkSpeedSampleModel?> bestRecent({
    Duration window = const Duration(hours: 24),
  }) async {
    final db = await _database.database;
    final since = DateTime.now().subtract(window).toIso8601String();
    final rows = await db.query(
      'network_speed_samples',
      where:
          'created_at >= ? AND backend_reachable = 1 AND download_mbps IS NOT NULL',
      whereArgs: [since],
      orderBy: 'download_mbps DESC, ping_ms ASC, created_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : NetworkSpeedSampleModel.fromDb(rows.first);
  }
}
