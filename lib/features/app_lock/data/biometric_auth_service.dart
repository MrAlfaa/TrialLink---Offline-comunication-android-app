import 'package:local_auth/local_auth.dart';

class BiometricAuthResult {
  const BiometricAuthResult({
    required this.success,
    this.message,
  });

  final bool success;
  final String? message;
}

class BiometricAuthService {
  BiometricAuthService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<BiometricAuthResult> authenticate() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) {
        return const BiometricAuthResult(
          success: false,
          message: 'Biometric unlock is unavailable on this device.',
        );
      }
      final authenticated = await _auth.authenticate(
        localizedReason: 'Unlock TrailLink to view private trip data.',
      );
      return BiometricAuthResult(
        success: authenticated,
        message: authenticated
            ? null
            : 'Authentication failed. Try again or use TrailLink PIN.',
      );
    } catch (_) {
      return const BiometricAuthResult(
        success: false,
        message: 'Biometric unlock is unavailable on this device.',
      );
    }
  }
}
