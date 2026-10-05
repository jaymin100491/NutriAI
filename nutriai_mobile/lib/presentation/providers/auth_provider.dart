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

  AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.user,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    UserData? user,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      error: error,
    );
  }
}

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
        state = state.copyWith(
          isAuthenticated: true,
          user: UserData(
            id: int.parse(userData['id']!),
            email: userData['email']!,
            firstName: nameParts.isNotEmpty ? nameParts.first : 'Patient',
            lastName: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
            subscriptionTier: 'premium',
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
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _authRepository.login(
        LoginRequest(email: email, password: password),
      );
      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        user: response.user,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        error: e.toString(),
      );
    }
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
