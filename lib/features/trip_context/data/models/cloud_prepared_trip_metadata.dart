class CloudPreparedTripMetadata {
  const CloudPreparedTripMetadata({
    required this.trip,
    required this.channel,
    required this.chatRoom,
    required this.group,
    required this.roster,
    this.offlineBackupReady = true,
  });

  final PreparedTripMetadata trip;
  final PreparedChannelMetadata channel;
  final PreparedChatRoomMetadata chatRoom;
  final PreparedGroupMetadata group;
  final List<MemberDeviceProfileMetadata> roster;
  final bool offlineBackupReady;

  factory CloudPreparedTripMetadata.fromJson(Map<String, dynamic> json) {
    return CloudPreparedTripMetadata(
      trip: PreparedTripMetadata.fromJson(
        json['trip'] as Map<String, dynamic>,
      ),
      channel: PreparedChannelMetadata.fromJson(
        json['channel'] as Map<String, dynamic>,
      ),
      chatRoom: PreparedChatRoomMetadata.fromJson(
        json['chatRoom'] as Map<String, dynamic>,
      ),
      group: PreparedGroupMetadata.fromJson(
        json['group'] as Map<String, dynamic>,
      ),
      roster: (json['roster'] as List<dynamic>? ?? const [])
          .map(
            (item) => MemberDeviceProfileMetadata.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      offlineBackupReady: json['offlineBackupReady'] != false,
    );
  }
}

class PreparedTripMetadata {
  const PreparedTripMetadata({
    required this.tripId,
    required this.tripName,
    required this.status,
    required this.mode,
    required this.activeChannelId,
    required this.primaryChannelId,
    required this.cloudGroupId,
    this.ownerUserId,
    this.cloudPreparedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String tripId;
  final String tripName;
  final String status;
  final String mode;
  final String activeChannelId;
  final String primaryChannelId;
  final String cloudGroupId;
  final String? ownerUserId;
  final DateTime? cloudPreparedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory PreparedTripMetadata.fromJson(Map<String, dynamic> json) {
    final channelId = json['primaryChannelId']?.toString() ??
        json['activeChannelId']?.toString() ??
        '';
    return PreparedTripMetadata(
      tripId: json['tripId'].toString(),
      tripName: json['tripName']?.toString() ?? 'TrailLink Trip',
      status: json['status']?.toString() ?? 'active',
      mode: json['mode']?.toString() ?? 'hybrid',
      activeChannelId: json['activeChannelId']?.toString() ?? channelId,
      primaryChannelId: channelId,
      cloudGroupId: json['cloudGroupId']?.toString() ?? '',
      ownerUserId: json['ownerUserId']?.toString(),
      cloudPreparedAt:
          DateTime.tryParse(json['cloudPreparedAt']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }
}

class PreparedChannelMetadata {
  const PreparedChannelMetadata({
    required this.channelId,
    required this.tripId,
    required this.channelName,
    required this.channelCode,
    this.channelKeyHash,
    this.isPrimary = true,
    this.isActive = true,
    this.channelStatus = 'active',
    this.createdAt,
    this.updatedAt,
  });

  final String channelId;
  final String tripId;
  final String channelName;
  final String channelCode;
  final String? channelKeyHash;
  final bool isPrimary;
  final bool isActive;
  final String channelStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory PreparedChannelMetadata.fromJson(Map<String, dynamic> json) {
    return PreparedChannelMetadata(
      channelId: json['channelId'].toString(),
      tripId: json['tripId'].toString(),
      channelName: json['channelName']?.toString() ?? 'Main Team Channel',
      channelCode: json['channelCode'].toString(),
      channelKeyHash: json['channelKeyHash']?.toString(),
      isPrimary: json['isPrimary'] != false,
      isActive: json['isActive'] != false,
      channelStatus: json['channelStatus']?.toString() ?? 'active',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }
}

class PreparedChatRoomMetadata {
  const PreparedChatRoomMetadata({
    required this.chatId,
    required this.tripId,
    required this.channelId,
    required this.cloudGroupId,
    this.chatName = 'General',
    this.chatType = 'offline_channel',
    this.isDefault = true,
    this.isActive = true,
    this.chatStatus = 'active',
    this.createdAt,
    this.updatedAt,
  });

  final String chatId;
  final String tripId;
  final String channelId;
  final String cloudGroupId;
  final String chatName;
  final String chatType;
  final bool isDefault;
  final bool isActive;
  final String chatStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory PreparedChatRoomMetadata.fromJson(Map<String, dynamic> json) {
    return PreparedChatRoomMetadata(
      chatId: json['chatId'].toString(),
      tripId: json['tripId'].toString(),
      channelId: json['channelId'].toString(),
      cloudGroupId: json['cloudGroupId']?.toString() ?? '',
      chatName: json['chatName']?.toString() ?? 'General',
      chatType: json['chatType']?.toString() ?? 'offline_channel',
      isDefault: json['isDefault'] != false,
      isActive: json['isActive'] != false,
      chatStatus: json['chatStatus']?.toString() ?? 'active',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }
}

class PreparedGroupMetadata {
  const PreparedGroupMetadata({
    required this.id,
    required this.groupName,
    required this.groupCode,
    this.status = 'active',
    this.createdBy,
  });

  final String id;
  final String groupName;
  final String groupCode;
  final String status;
  final String? createdBy;

  factory PreparedGroupMetadata.fromJson(Map<String, dynamic> json) {
    return PreparedGroupMetadata(
      id: json['id'].toString(),
      groupName: json['groupName']?.toString() ?? 'TrailLink Trip',
      groupCode: json['groupCode']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      createdBy: json['createdBy']?.toString(),
    );
  }
}

class MemberDeviceProfileMetadata {
  const MemberDeviceProfileMetadata({
    this.userId,
    this.publicUserId,
    this.localUserId,
    this.phoneNumber,
    required this.appDeviceId,
    required this.displayName,
    this.capabilities = const {},
    this.lastSeenAt,
    required this.tripId,
    required this.channelId,
    required this.cloudGroupId,
  });

  final String? userId;
  final String? publicUserId;
  final String? localUserId;
  final String? phoneNumber;
  final String appDeviceId;
  final String displayName;
  final Map<String, dynamic> capabilities;
  final DateTime? lastSeenAt;
  final String tripId;
  final String channelId;
  final String cloudGroupId;

  factory MemberDeviceProfileMetadata.fromJson(Map<String, dynamic> json) {
    return MemberDeviceProfileMetadata(
      userId: json['userId']?.toString(),
      publicUserId: json['publicUserId']?.toString(),
      localUserId: json['localUserId']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      appDeviceId: json['appDeviceId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? 'TrailLink User',
      capabilities: Map<String, dynamic>.from(
        json['capabilities'] as Map? ?? const {},
      ),
      lastSeenAt: DateTime.tryParse(json['lastSeenAt']?.toString() ?? ''),
      tripId: json['tripId']?.toString() ?? '',
      channelId: json['channelId']?.toString() ?? '',
      cloudGroupId: json['cloudGroupId']?.toString() ?? '',
    );
  }
}
