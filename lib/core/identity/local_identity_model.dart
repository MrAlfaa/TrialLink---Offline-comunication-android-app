class LocalIdentityModel {
  const LocalIdentityModel({
    this.id,
    required this.localUserId,
    this.backendUserId,
    this.publicUserId,
    this.cloudUserId,
    required this.displayName,
    this.email,
    this.phoneNumber,
    this.emergencyNote,
    required this.identityType,
    required this.createdOffline,
    this.cloudStatus = 'local_only',
    this.syncState = 'needs_cloud_create',
    this.lastCloudSyncAt,
    this.cloudErrorMessage,
    this.lastVerifiedAt,
    required this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String localUserId;
  final String? backendUserId;
  final String? publicUserId;
  final String? cloudUserId;
  final String displayName;
  final String? email;
  final String? phoneNumber;
  final String? emergencyNote;
  final String identityType;
  final bool createdOffline;
  final String cloudStatus;
  final String syncState;
  final DateTime? lastCloudSyncAt;
  final String? cloudErrorMessage;
  final DateTime? lastVerifiedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get isGuest => identityType == 'guest';
  bool get isLocalOnly => identityType == 'local_only';
  bool get isAuthenticatedCached => identityType == 'authenticated_cached';
  bool get isCloudReady =>
      cloudStatus == 'cloud_ready' &&
      (cloudUserId ?? backendUserId)?.isNotEmpty == true &&
      publicUserId?.isNotEmpty == true;
  bool get needsCloudCreate => !isCloudReady;

  LocalIdentityModel copyWith({
    int? id,
    String? localUserId,
    String? backendUserId,
    String? publicUserId,
    bool clearPublicUserId = false,
    String? cloudUserId,
    bool clearCloudUserId = false,
    String? displayName,
    String? email,
    bool clearEmail = false,
    String? phoneNumber,
    bool clearPhoneNumber = false,
    String? emergencyNote,
    bool clearEmergencyNote = false,
    String? identityType,
    bool? createdOffline,
    String? cloudStatus,
    String? syncState,
    DateTime? lastCloudSyncAt,
    bool clearLastCloudSyncAt = false,
    String? cloudErrorMessage,
    bool clearCloudErrorMessage = false,
    DateTime? lastVerifiedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LocalIdentityModel(
      id: id ?? this.id,
      localUserId: localUserId ?? this.localUserId,
      backendUserId: backendUserId ?? this.backendUserId,
      publicUserId:
          clearPublicUserId ? null : publicUserId ?? this.publicUserId,
      cloudUserId: clearCloudUserId ? null : cloudUserId ?? this.cloudUserId,
      displayName: displayName ?? this.displayName,
      email: clearEmail ? null : email ?? this.email,
      phoneNumber: clearPhoneNumber ? null : phoneNumber ?? this.phoneNumber,
      emergencyNote:
          clearEmergencyNote ? null : emergencyNote ?? this.emergencyNote,
      identityType: identityType ?? this.identityType,
      createdOffline: createdOffline ?? this.createdOffline,
      cloudStatus: cloudStatus ?? this.cloudStatus,
      syncState: syncState ?? this.syncState,
      lastCloudSyncAt:
          clearLastCloudSyncAt ? null : lastCloudSyncAt ?? this.lastCloudSyncAt,
      cloudErrorMessage: clearCloudErrorMessage
          ? null
          : cloudErrorMessage ?? this.cloudErrorMessage,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory LocalIdentityModel.fromDb(Map<String, Object?> row) {
    return LocalIdentityModel(
      id: row['id'] as int?,
      localUserId: row['local_user_id'].toString(),
      backendUserId: row['backend_user_id']?.toString(),
      publicUserId: row['public_user_id']?.toString(),
      cloudUserId: row['cloud_user_id']?.toString() ??
          row['backend_user_id']?.toString(),
      displayName: row['display_name'].toString(),
      email: row['email']?.toString(),
      phoneNumber: row['phone_number']?.toString(),
      emergencyNote: row['emergency_note']?.toString(),
      identityType: row['identity_type'].toString(),
      createdOffline: row['created_offline'] == 1,
      cloudStatus: row['cloud_status']?.toString() ??
          (row['backend_user_id'] == null ? 'local_only' : 'cloud_ready'),
      syncState: row['sync_state']?.toString() ??
          (row['backend_user_id'] == null ? 'needs_cloud_create' : 'synced'),
      lastCloudSyncAt:
          DateTime.tryParse(row['last_cloud_sync_at']?.toString() ?? ''),
      cloudErrorMessage: row['cloud_error_message']?.toString(),
      lastVerifiedAt:
          DateTime.tryParse(row['last_verified_at']?.toString() ?? ''),
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      if (id != null) 'id': id,
      'local_user_id': localUserId,
      'backend_user_id': backendUserId,
      'public_user_id': publicUserId,
      'cloud_user_id': cloudUserId,
      'display_name': displayName,
      'email': email,
      'phone_number': phoneNumber,
      'emergency_note': emergencyNote,
      'identity_type': identityType,
      'created_offline': createdOffline ? 1 : 0,
      'cloud_status': cloudStatus,
      'sync_state': syncState,
      'last_cloud_sync_at': lastCloudSyncAt?.toIso8601String(),
      'cloud_error_message': cloudErrorMessage,
      'last_verified_at': lastVerifiedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
