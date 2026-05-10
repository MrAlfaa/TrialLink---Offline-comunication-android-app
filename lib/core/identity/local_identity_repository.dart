import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../features/auth/data/models/user_model.dart';
import '../database/local_database.dart';
import 'local_identity_model.dart';

final localIdentityRepositoryProvider =
    Provider<LocalIdentityRepository>((ref) {
  return LocalIdentityRepository();
});

class LocalIdentityRepository {
  LocalIdentityRepository({
    LocalDatabase? database,
    Uuid? uuid,
  })  : _database = database ?? LocalDatabase.instance,
        _uuid = uuid ?? const Uuid();

  final LocalDatabase _database;
  final Uuid _uuid;

  static void validateProfileInput({
    required String displayName,
    String? email,
    String? emergencyNote,
  }) {
    _validateDisplayNameValue(displayName);
    _validateEmailValue(email);
    _validateEmergencyNoteValue(emergencyNote);
  }

  Future<LocalIdentityModel?> getCurrentIdentity() async {
    final db = await _database.database;
    final rows = await db.query(
      'local_identity',
      orderBy: 'updated_at DESC, created_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : LocalIdentityModel.fromDb(rows.first);
  }

  Future<LocalIdentityModel> createGuestIdentity({
    required String displayName,
    String? email,
    String? phoneNumber,
    String? emergencyNote,
  }) {
    return createLocalIdentity(
      displayName: displayName,
      email: email,
      phoneNumber: phoneNumber,
      emergencyNote: emergencyNote,
    );
  }

  Future<LocalIdentityModel> createLocalIdentity({
    required String displayName,
    String? email,
    String? phoneNumber,
    String? emergencyNote,
  }) async {
    validateProfileInput(
      displayName: displayName,
      email: email,
      emergencyNote: emergencyNote,
    );
    final now = DateTime.now();
    final identity = LocalIdentityModel(
      localUserId: 'local_${_uuid.v4()}',
      displayName: displayName.trim(),
      email: _blankToNull(email),
      phoneNumber: _blankToNull(phoneNumber),
      emergencyNote: _blankToNull(emergencyNote),
      identityType: 'local_only',
      createdOffline: true,
      cloudStatus: 'local_only',
      syncState: 'needs_cloud_create',
      createdAt: now,
      updatedAt: now,
    );
    await _replaceCurrentIdentity(identity);
    return (await getCurrentIdentity()) ?? identity;
  }

  Future<LocalIdentityModel> saveAuthenticatedIdentity(UserModel user) async {
    final existing = await getCurrentIdentity();
    final now = DateTime.now();
    final stableLocalId = existing?.localUserId ?? 'local_${_uuid.v4()}';
    final identity = LocalIdentityModel(
      id: existing?.id,
      localUserId: stableLocalId,
      backendUserId: user.id,
      publicUserId: user.publicUserId,
      cloudUserId: user.id,
      displayName:
          user.fullName.trim().isEmpty ? 'TrailLink User' : user.fullName,
      email: _blankToNull(user.email),
      phoneNumber: user.phoneNumber,
      emergencyNote: user.emergencyNote ?? existing?.emergencyNote,
      identityType: 'authenticated_cached',
      createdOffline: existing?.createdOffline ?? false,
      cloudStatus: 'cloud_ready',
      syncState: 'synced',
      lastCloudSyncAt: now,
      lastVerifiedAt: now,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    final db = await _database.database;
    await db.insert(
      'local_identity',
      identity.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return (await getCurrentIdentity()) ?? identity;
  }

  Future<void> updateIdentity(LocalIdentityModel identity) async {
    validateProfileInput(
      displayName: identity.displayName,
      email: identity.email,
      emergencyNote: identity.emergencyNote,
    );
    final db = await _database.database;
    final email = _blankToNull(identity.email);
    final phone = _blankToNull(identity.phoneNumber);
    final note = _blankToNull(identity.emergencyNote);
    final updated = identity.copyWith(
      displayName: identity.displayName.trim(),
      email: email,
      clearEmail: email == null,
      phoneNumber: phone,
      clearPhoneNumber: phone == null,
      emergencyNote: note,
      clearEmergencyNote: note == null,
      updatedAt: DateTime.now(),
    );
    await db.update(
      'local_identity',
      updated.toDbMap(),
      where: 'local_user_id = ?',
      whereArgs: [identity.localUserId],
    );
  }

  Future<LocalIdentityModel?> markCloudCreating() async {
    final identity = await getCurrentIdentity();
    if (identity == null) return null;
    final updated = identity.copyWith(
      cloudStatus: 'creating_cloud',
      syncState: 'needs_cloud_create',
      clearCloudErrorMessage: true,
    );
    await updateIdentity(updated);
    return getCurrentIdentity();
  }

  Future<LocalIdentityModel?> markCloudFailure(String message) async {
    final identity = await getCurrentIdentity();
    if (identity == null) return null;
    final updated = identity.copyWith(
      cloudStatus: 'sync_failed',
      syncState: 'needs_cloud_create',
      cloudErrorMessage: message,
    );
    await updateIdentity(updated);
    return getCurrentIdentity();
  }

  Future<void> clearIdentity() async {
    final db = await _database.database;
    await db.delete('local_identity');
  }

  Future<bool> hasLocalIdentity() async {
    return getCurrentIdentity().then((identity) => identity != null);
  }

  Future<bool> isGuestIdentity() async {
    return getCurrentIdentity().then((identity) => identity?.isGuest ?? false);
  }

  Future<void> _replaceCurrentIdentity(LocalIdentityModel identity) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.delete('local_identity');
      await txn.insert('local_identity', identity.toDbMap());
    });
  }

  static void _validateDisplayNameValue(String value) {
    final trimmed = value.trim();
    if (trimmed.length < 2 || trimmed.length > 50) {
      throw StateError('Display name must be 2-50 characters.');
    }
  }

  static void _validateEmergencyNoteValue(String? value) {
    if ((value ?? '').trim().length > 200) {
      throw StateError('Emergency note must be 200 characters or less.');
    }
  }

  static void _validateEmailValue(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed)) {
      throw StateError('Enter a valid email address or leave it blank.');
    }
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
