import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database.dart';
import 'models/connectivity_guidance_model.dart';
import 'models/peer_metric_sample_model.dart';
import 'models/peer_quality_model.dart';

class ConnectivityMetricsLocalDataSource {
  ConnectivityMetricsLocalDataSource({LocalDatabase? database})
      : _database = database ?? LocalDatabase.instance;

  final LocalDatabase _database;

  Future<void> insertSample(PeerMetricSampleModel sample) async {
    final db = await _database.database;
    await db.insert('peer_metric_samples', sample.toDbMap());
  }

  Future<List<PeerMetricSampleModel>> samplesForEndpoint(
    String endpointId, {
    int limit = 10,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'peer_metric_samples',
      where: 'endpoint_id = ?',
      whereArgs: [endpointId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.reversed.map(PeerMetricSampleModel.fromDb).toList();
  }

  Future<List<PeerMetricSampleModel>> latestSamplesForChannel(
    String channelCode,
  ) async {
    final db = await _database.database;
    final rows = await db.query(
      'peer_metric_samples',
      where: 'channel_code = ?',
      whereArgs: [channelCode],
      orderBy: 'created_at DESC',
      limit: 100,
    );
    return rows.map(PeerMetricSampleModel.fromDb).toList();
  }

  Future<void> upsertQuality(PeerQualityModel quality) async {
    final db = await _database.database;
    await db.insert(
      'peer_quality_scores',
      quality.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PeerQualityModel>> qualityScores(String channelCode) async {
    final db = await _database.database;
    final rows = await db.query(
      'peer_quality_scores',
      where: 'channel_code = ?',
      whereArgs: [channelCode],
      orderBy: 'quality_score DESC, last_calculated_at DESC',
    );
    return rows.map(PeerQualityModel.fromDb).toList();
  }

  Future<void> saveGuidance(ConnectivityGuidanceModel guidance) async {
    final db = await _database.database;
    await db.insert('connectivity_guidance_logs', guidance.toDbMap());
  }

  Future<ConnectivityGuidanceModel?> latestGuidance(String channelCode) async {
    final db = await _database.database;
    final rows = await db.query(
      'connectivity_guidance_logs',
      where: 'channel_code = ?',
      whereArgs: [channelCode],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : ConnectivityGuidanceModel.fromDb(rows.first);
  }

  Future<int> pendingOfflinePacketCount(String channelId) async {
    final db = await _database.database;
    final offlineRows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM offline_packet_queue WHERE channel_id = ? AND queue_status IN (?, ?)',
      [channelId, 'pending', 'failed'],
    );
    final voiceRows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM voice_packet_queue WHERE offline_channel_id = ? AND queue_status IN (?, ?)',
      [channelId, 'pending', 'failed'],
    );
    return _count(offlineRows) + _count(voiceRows);
  }

  int _count(List<Map<String, Object?>> rows) {
    if (rows.isEmpty) return 0;
    return int.tryParse(rows.first['count']?.toString() ?? '') ?? 0;
  }
}
