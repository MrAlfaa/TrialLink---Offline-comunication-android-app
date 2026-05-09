class GroupMemberModel {
  const GroupMemberModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.memberRole,
    required this.joinedAt,
    this.avatarUrl,
    this.groupId,
    this.localUserId,
    this.phoneNumber,
    this.membershipStatus = 'active',
    this.presenceStatus = 'unknown',
    this.lastSeenAt,
    this.source = 'backend',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? groupId;
  final String userId;
  final String? localUserId;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final String memberRole;
  final String joinedAt;
  final String? avatarUrl;
  final String membershipStatus;
  final String presenceStatus;
  final DateTime? lastSeenAt;
  final String source;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    return GroupMemberModel(
      id: (json['id'] ?? json['_id']).toString(),
      userId: json['userId']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      memberRole: json['memberRole']?.toString() ?? 'member',
      joinedAt: json['joinedAt']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString(),
      groupId: json['groupId']?.toString(),
      localUserId: json['localUserId']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      membershipStatus: json['membershipStatus']?.toString() ?? 'active',
      presenceStatus: json['presenceStatus']?.toString() ?? 'unknown',
      lastSeenAt: DateTime.tryParse(json['lastSeenAt']?.toString() ?? ''),
      source: json['source']?.toString() ?? 'backend',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }

  factory GroupMemberModel.fromDb(Map<String, Object?> row) {
    final userId = row['user_id']?.toString();
    final localUserId = row['local_user_id']?.toString();
    return GroupMemberModel(
      id: '${row['group_id']}:${userId ?? localUserId ?? row['display_name']}',
      groupId: row['group_id']?.toString(),
      userId: userId ?? '',
      localUserId: localUserId,
      fullName: row['display_name']?.toString() ?? 'TrailLink User',
      email: row['email']?.toString() ?? '',
      phoneNumber: row['phone_number']?.toString(),
      memberRole: row['role']?.toString() ?? 'member',
      joinedAt: row['created_at']?.toString() ?? '',
      avatarUrl: row['avatar_url']?.toString(),
      membershipStatus: row['membership_status']?.toString() ?? 'active',
      presenceStatus: row['presence_status']?.toString() ?? 'unknown',
      lastSeenAt: DateTime.tryParse(row['last_seen_at']?.toString() ?? ''),
      source: row['source']?.toString() ?? 'backend',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
    );
  }

  Map<String, Object?> toLocalDbMap({String? fallbackGroupId}) {
    final now = DateTime.now();
    return {
      'group_id': groupId ?? fallbackGroupId,
      'user_id': userId.isEmpty ? null : userId,
      'local_user_id': localUserId,
      'display_name': fullName,
      'email': email.isEmpty ? null : email,
      'phone_number': phoneNumber,
      'role': memberRole,
      'membership_status': membershipStatus,
      'presence_status': presenceStatus,
      'last_seen_at': lastSeenAt?.toIso8601String(),
      'source': source,
      'created_at': createdAt?.toIso8601String() ?? now.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String() ?? now.toIso8601String(),
    };
  }
}
