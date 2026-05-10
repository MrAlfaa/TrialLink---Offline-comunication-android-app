import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:traillink/features/auth/data/models/user_model.dart';
import 'package:traillink/features/offline_channel/data/models/offline_channel_model.dart';
import 'package:traillink/features/ptt/data/models/live_radio_session_model.dart';
import 'package:traillink/features/ptt/data/ptt_packet_service.dart';

void main() {
  group('Live Radio Experimental contracts', () {
    test('live radio packets serialize offline-only stream metadata', () {
      final service = PttPacketService();
      final channel = _channel();
      const user = UserModel(
        id: 'local_1',
        fullName: 'Dhananjaya',
        email: '',
      );
      final startedAt = DateTime.utc(2026, 8, 5, 10);

      final start = service.createLiveStartPacket(
        channel: channel,
        user: user,
        streamId: 'stream-1',
        startedAt: startedAt,
      );
      final chunk = service.createLiveChunkPacket(
        channel: channel,
        user: user,
        streamId: 'stream-1',
        sequence: 7,
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        createdAt: startedAt.add(const Duration(milliseconds: 200)),
      );
      final end = service.createLiveEndPacket(
        channel: channel,
        user: user,
        streamId: 'stream-1',
        endedAt: startedAt.add(const Duration(seconds: 2)),
      );

      expect(start.packetType, 'live_audio_start');
      expect(chunk.packetType, 'live_audio_chunk');
      expect(end.packetType, 'live_audio_end');
      expect(chunk.priority, 'high');
      expect(chunk.payload['codec'], 'pcm16');
      expect(chunk.payload['sampleRate'], 16000);
      expect(chunk.payload['chunkDurationMs'], 200);
      expect(chunk.payload['sequence'], 7);
      expect(chunk.payload['audioChunkBase64'], isNotEmpty);
      expect(chunk.toJson().containsKey('token'), isFalse);
      expect(chunk.toJson().containsKey('jwt'), isFalse);
    });

    test('live radio session model stores summary only', () {
      final session = LiveRadioSessionModel.fromDb({
        'stream_id': 'stream-1',
        'offline_channel_id': 'channel-1',
        'channel_code': 'TL-OFF-8K2P',
        'sender_local_id': 'local_1',
        'sender_name': 'Dhananjaya',
        'started_at': DateTime.utc(2026).toIso8601String(),
        'ended_at': DateTime.utc(2026)
            .add(const Duration(seconds: 3))
            .toIso8601String(),
        'duration_ms': 3000,
        'chunk_count': 15,
        'status': 'ended',
      });

      final row = session.toDbMap();
      expect(row['stream_id'], 'stream-1');
      expect(row['chunk_count'], 15);
      expect(row.containsKey('audioChunkBase64'), isFalse);
      expect(row.containsKey('raw_audio'), isFalse);
    });

    test('source keeps live radio offline-only and behind safety gates', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final db =
          File('lib/core/database/local_database.dart').readAsStringSync();
      final router = File('lib/core/offline/offline_packet_router.dart')
          .readAsStringSync();
      final eligibility = File(
        'lib/features/ptt/data/live_radio_eligibility_service.dart',
      ).readAsStringSync();
      final controller =
          File('lib/features/ptt/presentation/ptt_controller.dart')
              .readAsStringSync();
      final screen = File('lib/features/ptt/presentation/ptt_screen.dart')
          .readAsStringSync();

      expect(pubspec, contains('flutter_sound:'));
      expect(db, contains('version: 20'));
      expect(db, contains('live_radio_sessions'));
      expect(router, contains("case 'live_audio_start':"));
      expect(router, contains("case 'live_audio_chunk':"));
      expect(router, contains("case 'live_audio_end':"));
      expect(router, contains("!packet.packetType.startsWith('live_audio_')"));
      expect(eligibility, contains("effectiveMode != EffectiveMode.offline"));
      expect(eligibility, contains("'live_radio_enabled'"));
      expect(eligibility, contains('SignalQualityLabel.good'));
      expect(eligibility, contains('SignalQualityLabel.excellent'));
      expect(screen, contains('Voice-note PTT'));
      expect(screen, contains('Live Radio Exp.'));
      expect(controller, contains('Live Radio is offline-only'));
    });
  });
}

OfflineChannelModel _channel() {
  return OfflineChannelModel(
    channelId: 'channel-1',
    channelCode: 'TL-OFF-8K2P',
    channelName: 'Demo Channel',
    createdByUserId: 'local_1',
    createdAt: DateTime.utc(2026),
  );
}
