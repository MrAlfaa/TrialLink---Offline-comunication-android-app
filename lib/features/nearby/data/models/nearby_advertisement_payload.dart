import 'dart:convert';

class NearbyAdvertisementPayload {
  const NearbyAdvertisementPayload({
    required this.userId,
    required this.displayName,
    required this.activeChannelId,
    required this.activeChannelCode,
    required this.deviceName,
    required this.timestamp,
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

  factory NearbyAdvertisementPayload.fromEndpointName(String value) {
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
    );
  }

  String toEndpointName() {
    final shortName = _compact(displayName, 12);
    final shortDevice = _compact(deviceName, 10);
    final encodedName =
        base64Url.encode(utf8.encode(shortName)).replaceAll('=', '');
    final encodedDevice =
        base64Url.encode(utf8.encode(shortDevice)).replaceAll('=', '');
    final shortUserId = _compactId(userId);
    final shortChannelId = _compactId(activeChannelId);
    return 'TL2|$activeChannelCode|$shortUserId|$encodedName|$shortChannelId|$encodedDevice';
  }

  bool isCompatibleWith(String channelCode) {
    return appId == 'TrailLink' &&
        (protocolVersion.startsWith('1.') ||
            protocolVersion.startsWith('2.')) &&
        activeChannelCode == channelCode;
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
