import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/cold_start.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/auth_models.dart';
import 'labcorp_portal_repository.dart';

typedef AuthStatusCallback = void Function(String message);

class AuthRepository {
  final Dio _dio = DioClient().dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final LabcorpPortalRepository _portalRepository = LabcorpPortalRepository();

  Options get _authOptions => Options(
        sendTimeout: const Duration(milliseconds: ApiConstants.authConnectionTimeout),
        receiveTimeout: const Duration(milliseconds: ApiConstants.authReceiveTimeout),
      );

  /// Ping API root to wake a sleeping free-tier Render instance.
  Future<void> warmUpServer({AuthStatusCallback? onStatus}) async {
    onStatus?.call('Waking up server…');
    try {
      await _dio.get(
        '/',
        options: Options(
          sendTimeout: const Duration(milliseconds: ApiConstants.authConnectionTimeout),
          receiveTimeout: const Duration(milliseconds: ApiConstants.authReceiveTimeout),
          validateStatus: (_) => true,
        ),
      );
    } catch (_) {
      // Ignore — login retries will keep trying.
    }
  }

  Future<T> _withColdStartRetry<T>(
    Future<T> Function() action, {
    AuthStatusCallback? onStatus,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= ApiConstants.authMaxAttempts; attempt++) {
      try {
        if (attempt == 1) {
          await warmUpServer(onStatus: onStatus);
          onStatus?.call('Signing in…');
        } else {
          onStatus?.call(
            'Server waking up (attempt $attempt of ${ApiConstants.authMaxAttempts})…',
          );
          await Future<void>.delayed(
            const Duration(milliseconds: ApiConstants.authRetryDelayMs),
          );
        }
        return await action();
      } catch (e) {
        lastError = e;
        if (!isTransientNetworkError(e) || attempt == ApiConstants.authMaxAttempts) {
          throw Exception(friendlyAuthError(e));
        }
      }
    }
    throw Exception(friendlyAuthError(lastError ?? 'Unknown auth error'));
  }

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

  Future<AuthResponse> login(
    LoginRequest request, {
    AuthStatusCallback? onStatus,
  }) async {
    return _withColdStartRetry(
      () async {
        final response = await _dio.post(
          ApiConstants.login,
          data: request.toJson(),
          options: _authOptions,
        );
        final authResponse =
            AuthResponse.fromJson(response.data as Map<String, dynamic>);
        await _persistSession(authResponse);
        return authResponse;
      },
      onStatus: onStatus,
    );
  }

  Future<AuthResponse> signup(
    SignupRequest request, {
    AuthStatusCallback? onStatus,
  }) async {
    return _withColdStartRetry(
      () async {
        final response = await _dio.post(
          ApiConstants.signup,
          data: request.toJson(),
          options: _authOptions,
        );
        final authResponse =
            AuthResponse.fromJson(response.data as Map<String, dynamic>);
        await _persistSession(authResponse);
        return authResponse;
      },
      onStatus: onStatus,
    );
  }

  Future<void> _persistSession(AuthResponse authResponse) async {
    await _storage.write(key: 'access_token', value: authResponse.tokens.accessToken);
    await _storage.write(key: 'refresh_token', value: authResponse.tokens.refreshToken);
    await _storage.write(key: 'user_id', value: authResponse.user.id.toString());
    await _storage.write(key: 'user_email', value: authResponse.user.email);
    await _storage.write(key: 'user_name', value: authResponse.user.fullName);
    await _storage.write(key: 'user_role', value: authResponse.user.role);
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
      'role': await _storage.read(key: 'user_role') ?? 'user',
    };
  }
}
