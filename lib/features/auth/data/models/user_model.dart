class UserModel {
  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.publicUserId,
    this.localUserId,
    this.displayName,
    this.emergencyNote,
    this.phoneNumber,
    this.avatarUrl,
    this.role = 'user',
  });

  final String id;
  final String fullName;
  final String email;
  final String? publicUserId;
  final String? localUserId;
  final String? displayName;
  final String? emergencyNote;
  final String? phoneNumber;
  final String? avatarUrl;
  final String role;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final displayName = json['displayName']?.toString();
    final fullName = (json['fullName'] ?? displayName ?? '').toString();
    return UserModel(
      id: (json['id'] ?? json['_id']).toString(),
      fullName: fullName,
      email: json['email']?.toString() ?? '',
      publicUserId: json['publicUserId']?.toString(),
      localUserId: json['localUserId']?.toString(),
      displayName: displayName,
      emergencyNote: json['emergencyNote']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      role: json['role']?.toString() ?? 'user',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'publicUserId': publicUserId,
      'localUserId': localUserId,
      'displayName': displayName,
      'emergencyNote': emergencyNote,
      'phoneNumber': phoneNumber,
      'avatarUrl': avatarUrl,
      'role': role,
    };
  }
}
