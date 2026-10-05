import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/auth_models.dart';
import 'labcorp_portal_repository.dart';

class AuthRepository {
  final Dio _dio = DioClient().dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final LabcorpPortalRepository _portalRepository = LabcorpPortalRepository();

  Future<Map<String, String>> startOktaLogin() async {
    final response = await _dio.get(ApiConstants.oktaAuthorize);
    final data = response.data as Map<String, dynamic>;
    return {
      'authorization_url': data['authorization_url'] as String,
      'state': data['state'] as String,
    };
  }

  Future<AuthResponse> completeOktaLogin({
    required String code,
    required String state,
  }) async {
    final response = await _dio.post(
      ApiConstants.oktaCallback,
      data: {'code': code, 'state': state},
    );
    final authResponse = AuthResponse.fromJson(response.data as Map<String, dynamic>);
    await _persistSession(authResponse);

    if (kIsWeb && authResponse.oktaAccessToken != null && authResponse.oktaAccessToken!.isNotEmpty) {
      await _portalRepository.loginWithOktaToken(authResponse.oktaAccessToken!);
      await _storage.write(key: 'okta_access_token', value: authResponse.oktaAccessToken);
    }

    return authResponse;
  }

  Future<AuthResponse> login(LoginRequest request) async {
    final response = await _dio.post(
      ApiConstants.login,
      data: request.toJson(),
    );
    final authResponse = AuthResponse.fromJson(response.data as Map<String, dynamic>);
    await _persistSession(authResponse);
    return authResponse;
  }

  Future<AuthResponse> signup(SignupRequest request) async {
    final response = await _dio.post(
      ApiConstants.signup,
      data: request.toJson(),
    );
    final authResponse = AuthResponse.fromJson(response.data as Map<String, dynamic>);
    await _persistSession(authResponse);
    return authResponse;
  }

  Future<void> _persistSession(AuthResponse authResponse) async {
    await _storage.write(key: 'access_token', value: authResponse.tokens.accessToken);
    await _storage.write(key: 'refresh_token', value: authResponse.tokens.refreshToken);
    await _storage.write(key: 'user_id', value: authResponse.user.id.toString());
    await _storage.write(key: 'user_email', value: authResponse.user.email);
    await _storage.write(key: 'user_name', value: authResponse.user.fullName);
    await _storage.write(
      key: 'needs_lab_import',
      value: authResponse.needsLabImport ? 'true' : 'false',
    );
  }

  Future<bool> needsLabImport() async {
    return (await _storage.read(key: 'needs_lab_import')) == 'true';
  }

  Future<void> clearNeedsLabImport() async {
    await _storage.write(key: 'needs_lab_import', value: 'false');
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'access_token');
    return token != null && token.isNotEmpty;
  }

  Future<String?> getAccessToken() async {
    return _storage.read(key: 'access_token');
  }

  Future<Map<String, String>?> getUserData() async {
    final userId = await _storage.read(key: 'user_id');
    if (userId == null) return null;

    return {
      'id': userId,
      'email': await _storage.read(key: 'user_email') ?? '',
      'name': await _storage.read(key: 'user_name') ?? '',
    };
  }
}
