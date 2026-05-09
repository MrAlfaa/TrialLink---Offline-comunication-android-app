import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'app_lock_secure_storage.dart';

class TrailPinService {
  TrailPinService({
    AppLockSecureStorage? storage,
    Random? random,
  })  : _storage = storage ?? AppLockSecureStorage(),
        _random = random ?? Random.secure();

  static const maxFailedAttempts = 5;
  static const lockoutDuration = Duration(minutes: 2);

  final AppLockSecureStorage _storage;
  final Random _random;

  static bool isValidPin(String pin) {
    return RegExp(r'^\d{4}$').hasMatch(pin);
  }

  static String hashPin({
    required String pin,
    required String salt,
  }) {
    final hmac = Hmac(sha256, utf8.encode(salt));
    return hmac.convert(utf8.encode(pin)).toString();
  }

  static bool constantTimeEquals(String left, String right) {
    final leftBytes = utf8.encode(left);
    final rightBytes = utf8.encode(right);
    var diff = leftBytes.length ^ rightBytes.length;
    final maxLength = max(leftBytes.length, rightBytes.length);
    for (var index = 0; index < maxLength; index++) {
      final leftByte = index < leftBytes.length ? leftBytes[index] : 0;
      final rightByte = index < rightBytes.length ? rightBytes[index] : 0;
      diff |= leftByte ^ rightByte;
    }
    return diff == 0;
  }

  String generateSalt() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  Future<void> configurePin(String pin) async {
    if (!isValidPin(pin)) {
      throw StateError('TrailLink PIN must be exactly 4 digits.');
    }
    final salt = generateSalt();
    final hash = hashPin(pin: pin, salt: salt);
    await _storage.writePin(hash: hash, salt: salt);
  }

  Future<bool> verifyPin(String pin) async {
    if (!isValidPin(pin)) return false;
    final hash = await _storage.readPinHash();
    final salt = await _storage.readPinSalt();
    if (hash == null || salt == null || hash.isEmpty || salt.isEmpty) {
      return false;
    }
    final candidate = hashPin(pin: pin, salt: salt);
    return constantTimeEquals(candidate, hash);
  }

  Future<bool> hasPin() => _storage.hasPin();

  Future<void> clearPin() => _storage.clearPin();
}
