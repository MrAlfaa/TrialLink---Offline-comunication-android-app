class GroupModel {
  const GroupModel({
    required this.id,
    required this.groupName,
    required this.groupCode,
    required this.createdBy,
    this.description = '',
    this.status = 'active',
    this.memberRole,
    this.joinedAt,
    this.memberCount = 0,
    this.source = 'backend',
    this.syncState = 'synced',
    this.lastSyncedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String groupName;
  final String description;
  final String groupCode;
  final String createdBy;
  final String status;
  final String? memberRole;
  final String? joinedAt;
  final int memberCount;
  final String source;
  final String syncState;
  final DateTime? lastSyncedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isLatestKnown => lastSyncedAt != null || syncState == 'synced';
  bool get isArchived => status == 'archived';

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: (json['id'] ?? json['_id']).toString(),
      groupName: json['groupName']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      groupCode: json['groupCode']?.toString() ?? '',
      createdBy: json['createdBy']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      memberRole: json['memberRole']?.toString(),
      joinedAt: json['joinedAt']?.toString(),
      memberCount: int.tryParse(json['memberCount']?.toString() ?? '') ?? 0,
      source: json['source']?.toString() ?? 'backend',
      syncState: _normalizeSyncState(json['syncState']?.toString()),
      lastSyncedAt: DateTime.tryParse(
        json['lastSyncedAt']?.toString() ??
            json['last_synced_at']?.toString() ??
            '',
      ),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }

  factory GroupModel.fromDb(Map<String, Object?> row) {
    return GroupModel(
      id: row['group_id']?.toString() ?? row['groupId'].toString(),
      groupName:
          row['group_name']?.toString() ?? row['groupName']?.toString() ?? '',
      groupCode:
          row['group_code']?.toString() ?? row['groupCode']?.toString() ?? '',
      description: row['description']?.toString() ?? '',
      createdBy:
          row['created_by']?.toString() ?? row['createdBy']?.toString() ?? '',
      status: row['status']?.toString() ?? 'active',
      memberRole:
          row['member_role']?.toString() ?? row['memberRole']?.toString(),
      joinedAt: row['joined_at']?.toString() ?? row['joinedAt']?.toString(),
      memberCount: int.tryParse(row['member_count']?.toString() ?? '') ?? 0,
      source: row['source']?.toString() ?? 'backend',
      syncState: _normalizeSyncState(row['sync_state']?.toString()),
      lastSyncedAt: DateTime.tryParse(row['last_synced_at']?.toString() ?? ''),
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
    );
  }

  Map<String, Object?> toLocalDbMap() {
    final now = DateTime.now();
    return {
      'group_id': id,
      'group_name': groupName,
      'group_code': groupCode.isEmpty ? null : groupCode,
      'description': description.isEmpty ? null : description,
      'member_role': memberRole,
      'member_count': memberCount,
      'status': status,
      'source': source,
      'sync_state': syncState,
      'last_synced_at':
          lastSyncedAt?.toIso8601String() ?? now.toIso8601String(),
      'created_at': createdAt?.toIso8601String() ?? now.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String() ?? now.toIso8601String(),
    };
  }

  static String _normalizeSyncState(String? value) {
    return switch (value) {
      'server_synced' => 'synced',
      'completed' => 'synced',
      'pending' => 'needs_sync',
      'error' => 'failed',
      'failed' => 'failed',
      'local_only' => 'local_only',
      'needs_sync' => 'needs_sync',
      'synced' => 'synced',
      _ => 'synced',
    };
  }
}
