import 'nearby_connection_status.dart';

class NearbyPeerModel {
  const NearbyPeerModel({
    required this.endpointId,
    required this.userId,
    required this.displayName,
    required this.deviceName,
    required this.activeChannelId,
    required this.activeChannelCode,
    required this.status,
    required this.discoveredAt,
    required this.lastSeenAt,
    this.rssi,
    this.isSameChannel = true,
    this.tripId,
    this.publicUserId,
    this.appDeviceId,
    this.verificationStatus = 'unknown_same_channel',
  });

  final String endpointId;
  final String userId;
  final String displayName;
  final String deviceName;
  final String activeChannelId;
  final String activeChannelCode;
  final PeerConnectionStatus status;
  final DateTime discoveredAt;
  final DateTime lastSeenAt;
  final int? rssi;
  final bool isSameChannel;
  final String? tripId;
  final String? publicUserId;
  final String? appDeviceId;
  final String verificationStatus;

  String get identityKey {
    final aliases = identityAliases;
    if (aliases.isNotEmpty) return aliases.first;
    return 'endpoint:$activeChannelCode:$endpointId';
  }

  List<String> get identityAliases {
    final aliases = <String>[];
    final publicId = publicUserId?.trim();
    if (publicId != null && publicId.isNotEmpty) {
      aliases.add('public:$publicId');
    }
    final deviceId = appDeviceId?.trim();
    if (deviceId != null && deviceId.isNotEmpty) {
      aliases.add('device:$deviceId');
    }
    final localId = userId.trim();
    if (localId.isNotEmpty) {
      aliases.add('local:$activeChannelCode:$localId');
    }
    final display = displayName.trim().toLowerCase();
    final device = deviceName.trim().toLowerCase();
    if (display.isNotEmpty || device.isNotEmpty) {
      aliases.add('name:$activeChannelCode:$display:$device');
    }
    // Older rows may only have a display name because they were persisted
    // before the peer_hello/appDeviceId metadata arrived. Keep this as the
    // weakest alias so stale endpoint rows collapse into the newer live card.
    if (_isSpecificDisplayName(display)) {
      aliases.add('display:$activeChannelCode:$display');
    }
    return aliases;
  }

  bool hasSamePhoneIdentity(NearbyPeerModel other) {
    return identityAliases
        .toSet()
        .intersection(other.identityAliases.toSet())
        .isNotEmpty;
  }

  bool matchesLocalIdentity({
    required String localUserId,
    String? actorId,
    String? backendUserId,
    String? publicUserId,
    String? appDeviceId,
    String? displayName,
  }) {
    final localIds = {
      localUserId,
      if (actorId != null) actorId,
      if (backendUserId != null) backendUserId,
    }.map((value) => value.trim()).where((value) => value.isNotEmpty).toSet();
    final peerUserId = userId.trim();
    if (peerUserId.isNotEmpty && localIds.contains(peerUserId)) return true;

    final publicIds = {
      if (publicUserId != null) publicUserId,
    }.map((value) => value.trim()).where((value) => value.isNotEmpty).toSet();
    final peerPublicId = this.publicUserId?.trim();
    if (peerPublicId != null &&
        peerPublicId.isNotEmpty &&
        publicIds.contains(peerPublicId)) {
      return true;
    }

    final deviceIds = {
      if (appDeviceId != null) appDeviceId,
    }.map((value) => value.trim()).where((value) => value.isNotEmpty).toSet();
    final peerDeviceId = this.appDeviceId?.trim();
    if (peerDeviceId != null &&
        peerDeviceId.isNotEmpty &&
        deviceIds.contains(peerDeviceId)) {
      return true;
    }

    final localDisplayName = displayName?.trim().toLowerCase();
    final peerDisplayName = this.displayName.trim().toLowerCase();
    if (_hasWeakIdentity &&
        _isSpecificDisplayName(localDisplayName) &&
        localDisplayName == peerDisplayName) {
      return true;
    }
    return false;
  }

  static List<NearbyPeerModel> collapseDuplicates(
    Iterable<NearbyPeerModel> peers,
  ) {
    final grouped = <String, NearbyPeerModel>{};
    final aliasToKey = <String, String>{};
    for (final peer in peers) {
      final aliases = peer.identityAliases;
      var key = aliases
          .map((alias) => aliasToKey[alias])
          .whereType<String>()
          .firstOrNull;
      key ??= peer.identityKey;
      final current = grouped[key];
      final next = current == null
          ? peer
          : _mergePeers(
              _isBetterPeer(peer, current) ? peer : current,
              _isBetterPeer(peer, current) ? current : peer,
            );
      grouped[key] = next;
      for (final alias in {...aliases, ...next.identityAliases}) {
        final oldKey = aliasToKey[alias];
        if (oldKey != null && oldKey != key && grouped.containsKey(oldKey)) {
          grouped[key] = _mergePeers(grouped[key]!, grouped.remove(oldKey)!);
        }
        aliasToKey[alias] = key;
      }
    }
    final collapsed = grouped.values.toList(growable: false)
      ..sort((a, b) {
        final rankCompare = _statusRank(b.status).compareTo(
          _statusRank(a.status),
        );
        if (rankCompare != 0) return rankCompare;
        return b.lastSeenAt.compareTo(a.lastSeenAt);
      });
    return collapsed;
  }

  static bool _isBetterPeer(
      NearbyPeerModel candidate, NearbyPeerModel current) {
    final candidateRank = _statusRank(candidate.status);
    final currentRank = _statusRank(current.status);
    if (candidateRank != currentRank) return candidateRank > currentRank;
    return candidate.lastSeenAt.isAfter(current.lastSeenAt);
  }

  static int _statusRank(PeerConnectionStatus status) {
    return switch (status) {
      PeerConnectionStatus.connected => 60,
      PeerConnectionStatus.connecting => 50,
      PeerConnectionStatus.discovered => 40,
      PeerConnectionStatus.disconnected => 20,
      PeerConnectionStatus.lost => 10,
      PeerConnectionStatus.failed => 0,
    };
  }

  static NearbyPeerModel _mergePeers(
    NearbyPeerModel preferred,
    NearbyPeerModel fallback,
  ) {
    return preferred.copyWith(
      publicUserId:
          _firstNonEmpty(preferred.publicUserId, fallback.publicUserId),
      appDeviceId: _firstNonEmpty(preferred.appDeviceId, fallback.appDeviceId),
      tripId: _firstNonEmpty(preferred.tripId, fallback.tripId),
      userId: _firstNonEmpty(preferred.userId, fallback.userId),
      displayName: _firstNonEmpty(preferred.displayName, fallback.displayName),
      deviceName: _firstNonEmpty(preferred.deviceName, fallback.deviceName),
      verificationStatus: preferred.verificationStatus == 'unknown_same_channel'
          ? fallback.verificationStatus
          : preferred.verificationStatus,
    );
  }

  static String? _firstNonEmpty(String? first, String? second) {
    final firstTrimmed = first?.trim();
    if (firstTrimmed != null && firstTrimmed.isNotEmpty) return first;
    final secondTrimmed = second?.trim();
    if (secondTrimmed != null && secondTrimmed.isNotEmpty) return second;
    return first;
  }

  bool get _hasWeakIdentity {
    final publicId = publicUserId?.trim();
    final deviceId = appDeviceId?.trim();
    if (publicId != null && publicId.isNotEmpty) return false;
    if (deviceId != null && deviceId.isNotEmpty) return false;
    final trimmedUserId = userId.trim();
    return trimmedUserId.isEmpty || trimmedUserId == endpointId;
  }

  static bool _isSpecificDisplayName(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return false;
    return normalized != 'nearby phone' &&
        normalized != 'traillink user' &&
        normalized != 'android device';
  }

  NearbyPeerModel copyWith({
    String? endpointId,
    String? userId,
    String? displayName,
    String? deviceName,
    String? activeChannelId,
    String? activeChannelCode,
    PeerConnectionStatus? status,
    DateTime? discoveredAt,
    DateTime? lastSeenAt,
    int? rssi,
    bool? isSameChannel,
    String? tripId,
    String? publicUserId,
    String? appDeviceId,
    String? verificationStatus,
  }) {
    return NearbyPeerModel(
      endpointId: endpointId ?? this.endpointId,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      deviceName: deviceName ?? this.deviceName,
      activeChannelId: activeChannelId ?? this.activeChannelId,
      activeChannelCode: activeChannelCode ?? this.activeChannelCode,
      status: status ?? this.status,
      discoveredAt: discoveredAt ?? this.discoveredAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      rssi: rssi ?? this.rssi,
      isSameChannel: isSameChannel ?? this.isSameChannel,
      tripId: tripId ?? this.tripId,
      publicUserId: publicUserId ?? this.publicUserId,
      appDeviceId: appDeviceId ?? this.appDeviceId,
      verificationStatus: verificationStatus ?? this.verificationStatus,
    );
  }

  factory NearbyPeerModel.fromDb(Map<String, Object?> row) {
    return NearbyPeerModel(
      endpointId: row['endpoint_id'].toString(),
      userId: row['user_id'].toString(),
      displayName: row['display_name'].toString(),
      deviceName: row['device_name']?.toString() ?? 'Android Device',
      activeChannelId: row['active_channel_id'].toString(),
      activeChannelCode: row['active_channel_code'].toString(),
      status: PeerConnectionStatusX.fromString(
        row['connection_status']?.toString() ?? 'discovered',
      ),
      discoveredAt: DateTime.tryParse(
            row['discovered_at']?.toString() ?? '',
          ) ??
          DateTime.now(),
      lastSeenAt: DateTime.tryParse(row['last_seen_at']?.toString() ?? '') ??
          DateTime.now(),
      rssi: row['rssi'] is int ? row['rssi'] as int : null,
      isSameChannel: row['is_same_channel'] == 1,
      tripId: row['trip_id']?.toString(),
      publicUserId: row['public_user_id']?.toString(),
      appDeviceId: row['app_device_id']?.toString(),
      verificationStatus:
          row['verification_status']?.toString() ?? 'unknown_same_channel',
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'endpoint_id': endpointId,
      'user_id': userId,
      'display_name': displayName,
      'device_name': deviceName,
      'active_channel_id': activeChannelId,
      'active_channel_code': activeChannelCode,
      'connection_status': status.name,
      'discovered_at': discoveredAt.toIso8601String(),
      'last_seen_at': lastSeenAt.toIso8601String(),
      'rssi': rssi,
      'is_same_channel': isSameChannel ? 1 : 0,
      'trip_id': tripId,
      'public_user_id': publicUserId,
      'app_device_id': appDeviceId,
      'verification_status': verificationStatus,
    };
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
