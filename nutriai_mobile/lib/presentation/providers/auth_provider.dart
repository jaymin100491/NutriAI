import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/auth_models.dart';
import '../../data/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider));
});

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final UserData? user;
  final String? error;
  final bool needsLabImport;
  /// Live status during cold-start retries (e.g. "Waking up server…").
  final String? statusMessage;

  AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.user,
    this.error,
    this.needsLabImport = false,
    this.statusMessage,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    UserData? user,
    String? error,
    bool? needsLabImport,
    Object? statusMessage = _authUnset,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      error: error,
      needsLabImport: needsLabImport ?? this.needsLabImport,
      statusMessage: identical(statusMessage, _authUnset)
          ? this.statusMessage
          : statusMessage as String?,
    );
  }
}

const Object _authUnset = Object();

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;

  AuthNotifier(this._authRepository) : super(AuthState()) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final isLoggedIn = await _authRepository.isLoggedIn();
    if (isLoggedIn) {
      final userData = await _authRepository.getUserData();
      if (userData != null) {
        final nameParts = userData['name']!.split(' ');
        final needsLabs = await _authRepository.needsLabImport();
        state = state.copyWith(
          isAuthenticated: true,
          needsLabImport: needsLabs,
          user: UserData(
            id: int.parse(userData['id']!),
            email: userData['email']!,
            firstName: nameParts.isNotEmpty ? nameParts.first : 'Patient',
            lastName: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
            subscriptionTier: 'premium',
            role: userData['role'] ?? 'user',
          ),
        );
      }
    }
  }

  Future<String> startOktaLogin() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _authRepository.startOktaLogin();
      state = state.copyWith(isLoading: false);
      return result['authorization_url']!;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> completeOktaLogin({required String code, required String state}) async {
    this.state = this.state.copyWith(isLoading: true, error: null);
    try {
      final response = await _authRepository.completeOktaLogin(code: code, state: state);
      this.state = this.state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        user: response.user,
        error: null,
      );
    } catch (e) {
      this.state = this.state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      statusMessage: 'Connecting…',
    );
    try {
      final response = await _authRepository.login(
        LoginRequest(email: email, password: password),
        onStatus: (msg) {
          state = state.copyWith(isLoading: true, statusMessage: msg);
        },
      );
      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        user: response.user,
        needsLabImport: response.needsLabImport,
        error: null,
        statusMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
        statusMessage: null,
      );
    }
  }

  Future<void> signup({
    required String email,
    required String password,
    required String firstName,
    String lastName = '',
  }) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      statusMessage: 'Creating account…',
    );
    try {
      final response = await _authRepository.signup(
        SignupRequest(
          email: email,
          password: password,
          firstName: firstName,
          lastName: lastName,
        ),
        onStatus: (msg) {
          state = state.copyWith(isLoading: true, statusMessage: msg);
        },
      );
      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        user: response.user,
        needsLabImport: response.needsLabImport,
        error: null,
        statusMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
        statusMessage: null,
      );
    }
  }

  Future<void> markLabsImported() async {
    await _authRepository.clearNeedsLabImport();
    state = state.copyWith(needsLabImport: false);
  }

  Future<void> logout() async {
    await _authRepository.logout();
    state = AuthState();
  }

  void resetLoading() {
    if (state.isLoading) {
      state = state.copyWith(isLoading: false);
    }
  }
}
