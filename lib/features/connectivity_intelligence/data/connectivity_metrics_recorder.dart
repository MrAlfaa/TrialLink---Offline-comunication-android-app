import '../../nearby/data/models/nearby_peer_model.dart';
import 'connectivity_intelligence_repository.dart';

class ConnectivityMetricsRecorder {
  ConnectivityMetricsRecorder({
    ConnectivityIntelligenceRepository? repository,
  }) : _repository = repository ?? connectivityIntelligenceRepository;

  final ConnectivityIntelligenceRepository _repository;

  Future<void> recordPeerEvent(
    NearbyPeerModel peer, {
    required String source,
  }) {
    return _repository.recordPeerSample(
      peer: peer,
      sampleSource: source,
      disconnectCount:
          peer.status.name == 'lost' || peer.status.name == 'disconnected'
              ? 1
              : 0,
    );
  }

  Future<void> recordPacketResult({
    required String endpointId,
    required String channelId,
    required String channelCode,
    required bool success,
    String? userId,
    String? displayName,
    int retryCount = 0,
  }) {
    return _repository.recordSyntheticSample(
      endpointId: endpointId,
      userId: userId,
      displayName: displayName,
      channelId: channelId,
      channelCode: channelCode,
      connectionStatus: success ? 'connected' : 'unstable',
      sampleSource: 'packet_result',
      packetSuccessRate: success ? 1 : 0,
      retryCount: retryCount,
    );
  }

  Future<void> recordAck({
    required String endpointId,
    required String channelId,
    required String channelCode,
    required int ackRttMs,
    String? userId,
    String? displayName,
  }) {
    return _repository.recordSyntheticSample(
      endpointId: endpointId,
      userId: userId,
      displayName: displayName,
      channelId: channelId,
      channelCode: channelCode,
      connectionStatus: 'connected',
      sampleSource: 'ack',
      ackRttMs: ackRttMs,
      packetSuccessRate: 1,
    );
  }

  Future<void> recordHeartbeat({
    required String endpointId,
    required String channelId,
    required String channelCode,
    required String displayName,
    String? userId,
  }) {
    return _repository.recordSyntheticSample(
      endpointId: endpointId,
      userId: userId,
      displayName: displayName,
      channelId: channelId,
      channelCode: channelCode,
      connectionStatus: 'connected',
      sampleSource: 'heartbeat',
    );
  }
}
