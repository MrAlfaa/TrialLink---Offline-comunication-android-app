import 'dart:convert';

class NearbyAdvertisementPayload {
  const NearbyAdvertisementPayload({
    required this.userId,
    required this.displayName,
    required this.activeChannelId,
    required this.activeChannelCode,
    required this.deviceName,
    required this.timestamp,
    this.tripId,
    this.tripName,
    this.ownerLocalId,
    this.ownerName,
    this.memberRole = 'member',
    this.publicUserId,
    this.appDeviceId,
    this.capabilities = const ['text'],
    this.appId = 'TrailLink',
    this.protocolVersion = '1.0',
  });

  final String appId;
  final String protocolVersion;
  final String userId;
  final String displayName;
  final String activeChannelId;
  final String activeChannelCode;
  final String deviceName;
  final DateTime timestamp;
  final String? tripId;
  final String? tripName;
  final String? ownerLocalId;
  final String? ownerName;
  final String memberRole;
  final String? publicUserId;
  final String? appDeviceId;
  final List<String> capabilities;

  factory NearbyAdvertisementPayload.fromEndpointName(String value) {
    if (value.startsWith('TL3|')) {
      final parts = value.split('|');
      if (parts.length < 10) throw const FormatException('Invalid payload');
      return NearbyAdvertisementPayload(
        protocolVersion: '3.0',
        tripId: parts[2],
        activeChannelId: parts[3],
        userId: parts[4],
        publicUserId: parts[5].isEmpty ? null : parts[5],
        appDeviceId: parts[6].isEmpty ? null : parts[6],
        displayName: utf8.decode(base64Url.decode(_pad(parts[7]))),
        activeChannelCode: parts[1],
        deviceName: utf8.decode(base64Url.decode(_pad(parts[8]))),
        capabilities: parts[9].isEmpty ? const ['text'] : parts[9].split(','),
        timestamp: DateTime.now(),
      );
    }
    if (value.startsWith('TL2|')) {
      final parts = value.split('|');
      if (parts.length < 6) throw const FormatException('Invalid payload');
      return NearbyAdvertisementPayload(
        protocolVersion: '2.0',
        userId: parts[2],
        displayName: utf8.decode(base64Url.decode(_pad(parts[3]))),
        activeChannelId: parts[4],
        activeChannelCode: parts[1],
        deviceName: utf8.decode(base64Url.decode(_pad(parts[5]))),
        timestamp: DateTime.now(),
      );
    }
    if (value.startsWith('TL1|')) {
      final parts = value.split('|');
      if (parts.length < 6) throw const FormatException('Invalid payload');
      return NearbyAdvertisementPayload(
        userId: parts[2],
        displayName: utf8.decode(base64Url.decode(_pad(parts[3]))),
        activeChannelId: parts[4],
        activeChannelCode: parts[1],
        deviceName: utf8.decode(base64Url.decode(_pad(parts[5]))),
        timestamp: DateTime.now(),
      );
    }
    final data = jsonDecode(value) as Map<String, dynamic>;
    return NearbyAdvertisementPayload(
      appId: data['appId']?.toString() ?? '',
      protocolVersion: data['protocolVersion']?.toString() ?? '',
      userId: data['userId']?.toString() ?? '',
      displayName: data['displayName']?.toString() ?? 'TrailLink User',
      activeChannelId: data['activeChannelId']?.toString() ?? '',
      activeChannelCode: data['activeChannelCode']?.toString() ?? '',
      deviceName: data['deviceName']?.toString() ?? 'Android Device',
      timestamp: DateTime.tryParse(data['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      tripId: data['tripId']?.toString(),
      publicUserId: data['senderPublicUserId']?.toString() ??
          data['publicUserId']?.toString(),
      appDeviceId: data['appDeviceId']?.toString(),
      tripName: data['tripName']?.toString(),
      ownerLocalId: data['ownerLocalId']?.toString(),
      ownerName: data['ownerName']?.toString(),
      memberRole: data['memberRole']?.toString() ?? 'member',
      capabilities: (data['capabilities'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList(growable: false) ??
          const ['text'],
    );
  }

  String toEndpointName() {
    final shortName = _compact(displayName, 12);
    final shortDevice = _compact(deviceName, 10);
    final encodedName =
        base64Url.encode(utf8.encode(shortName)).replaceAll('=', '');
    final encodedDevice =
        base64Url.encode(utf8.encode(shortDevice)).replaceAll('=', '');
    final shortTripId = _compactId(tripId ?? '');
    final shortUserId = _compactId(userId);
    final shortPublicUserId = _compact(publicUserId?.trim() ?? '', 18);
    final shortDeviceId = _compactId(appDeviceId ?? '');
    final shortChannelId = _compactId(activeChannelId);
    final caps = capabilities
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(5)
        .join(',');
    return 'TL3|$activeChannelCode|$shortTripId|$shortChannelId|$shortUserId|$shortPublicUserId|$shortDeviceId|$encodedName|$encodedDevice|$caps';
  }

  bool isCompatibleWith(String channelCode) {
    return appId == 'TrailLink' &&
        (protocolVersion.startsWith('1.') ||
            protocolVersion.startsWith('2.') ||
            protocolVersion.startsWith('3.')) &&
        activeChannelCode == channelCode;
  }

  Map<String, Object?> toPeerHelloJson() {
    return {
      'appId': appId,
      'protocolVersion': protocolVersion,
      'tripId': tripId,
      'tripName': tripName,
      'ownerLocalId': ownerLocalId,
      'ownerName': ownerName,
      'memberRole': memberRole,
      'channelId': activeChannelId,
      'channelCode': activeChannelCode,
      'senderLocalId': userId,
      'senderPublicUserId': publicUserId,
      'appDeviceId': appDeviceId,
      'displayName': displayName,
      'deviceName': deviceName,
      'capabilities': capabilities,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  static String _compact(String value, int maxLength) {
    final trimmed = value.trim();
    if (trimmed.length <= maxLength) return trimmed;
    return trimmed.substring(0, maxLength);
  }

  static String _compactId(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'local';
    final firstSegment = trimmed.split('-').first;
    return _compact(firstSegment, 8);
  }

  static String _pad(String value) {
    final remainder = value.length % 4;
    if (remainder == 0) return value;
    return value.padRight(value.length + 4 - remainder, '=');
  }
}
