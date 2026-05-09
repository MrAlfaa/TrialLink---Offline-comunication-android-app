import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppLockSecureStorage {
  AppLockSecureStorage({
    FlutterSecureStorage storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  }) : _storage = storage;

  static const pinHashKey = 'trail_pin_hash';
  static const pinSaltKey = 'trail_pin_salt';
  static const secretVersionKey = 'app_lock_secret_version';

  final FlutterSecureStorage _storage;

  Future<String?> readPinHash() => _storage.read(key: pinHashKey);

  Future<String?> readPinSalt() => _storage.read(key: pinSaltKey);

  Future<void> writePin({
    required String hash,
    required String salt,
  }) async {
    await _storage.write(key: pinHashKey, value: hash);
    await _storage.write(key: pinSaltKey, value: salt);
    await _storage.write(key: secretVersionKey, value: '1');
  }

  Future<void> clearPin() async {
    await _storage.delete(key: pinHashKey);
    await _storage.delete(key: pinSaltKey);
  }

  Future<bool> hasPin() async {
    final hash = await readPinHash();
    final salt = await readPinSalt();
    return hash != null && hash.isNotEmpty && salt != null && salt.isNotEmpty;
  }
}
