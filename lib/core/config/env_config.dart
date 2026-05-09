import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  const EnvConfig._();

  static bool _loaded = false;
  static String? _loadError;

  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
      _loaded = true;
      _loadError = null;
    } catch (error) {
      _loaded = false;
      _loadError = error.toString();
    }
  }

  static bool get isLoaded => _loaded;

  static String? get loadError => _loadError;

  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? '';

  static String get socketBaseUrl {
    final value = apiBaseUrl.trim();
    if (value.endsWith('/api')) {
      return value.substring(0, value.length - 4);
    }
    if (value.endsWith('/api/')) {
      return value.substring(0, value.length - 5);
    }
    return value;
  }

  static String get appEnv => dotenv.env['APP_ENV'] ?? 'development';

  static bool get isConfigured => apiBaseUrl.trim().isNotEmpty;
}
