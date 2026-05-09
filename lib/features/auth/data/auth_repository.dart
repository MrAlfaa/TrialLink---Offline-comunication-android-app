import 'package:dio/dio.dart';

import '../../../core/database/local_database.dart';
import '../../../core/identity/local_identity_repository.dart';
import '../../../core/storage/secure_storage_service.dart';
import 'auth_api.dart';
import 'models/user_model.dart';

class AuthRepository {
  AuthRepository({
    AuthApi? api,
    SecureStorageService? storage,
  })  : _api = api ?? AuthApi(),
        _storage = storage ?? SecureStorageService.instance;

  final AuthApi _api;
  final SecureStorageService _storage;

  Future<UserModel> register({
    required String fullName,
    required String email,
    required String password,
    String? phoneNumber,
  }) async {
    final response = await _api.register(
      fullName: fullName,
      email: email,
      password: password,
      phoneNumber: phoneNumber,
    );
    await _persistSession(response.token, response.user);
    return response.user;
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.login(email: email, password: password);
    await _persistSession(response.token, response.user);
    return response.user;
  }

  Future<UserModel?> restoreSession({
    bool clearOnFailure = true,
  }) async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) return null;

    try {
      final user = await _api.me();
      await _cacheUser(user);
      await LocalIdentityRepository().saveAuthenticatedIdentity(user);
      return user;
    } on DioException {
      if (clearOnFailure) await logout();
      return null;
    }
  }

  Future<UserModel> bootstrapIdentity({
    required String displayName,
    required String email,
    String? phoneNumber,
    String? localUserId,
  }) async {
    final response = await _api.bootstrapIdentity(
      displayName: displayName,
      email: email,
      phoneNumber: phoneNumber,
      localUserId: localUserId,
    );
    await _persistSession(response.token, response.user);
    return response.user;
  }

  Future<void> logout() async {
    await _storage.clearToken();
    await LocalDatabase.instance.clearUserCache();
  }

  Future<void> _persistSession(String token, UserModel user) async {
    await _storage.saveToken(token);
    await _cacheUser(user);
    await LocalIdentityRepository().saveAuthenticatedIdentity(user);
  }

  Future<void> _cacheUser(UserModel user) {
    return LocalDatabase.instance.cacheUser(
      userId: user.id,
      fullName: user.fullName,
      email: user.email,
    );
  }
}
