import 'package:equatable/equatable.dart';

class LoginRequest extends Equatable {
  final String email;
  final String password;

  const LoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };

  @override
  List<Object?> get props => [email, password];
}

class SignupRequest extends Equatable {
  final String email;
  final String password;
  final String firstName;
  final String lastName;

  const SignupRequest({
    required this.email,
    required this.password,
    required this.firstName,
    this.lastName = '',
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
      };

  @override
  List<Object?> get props => [email, password, firstName, lastName];
}

class AuthResponse extends Equatable {
  final UserData user;
  final TokenData tokens;
  final String? oktaAccessToken;
  final bool needsLabImport;

  const AuthResponse({
    required this.user,
    required this.tokens,
    this.oktaAccessToken,
    this.needsLabImport = false,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: UserData.fromJson(json['user'] as Map<String, dynamic>),
      tokens: TokenData.fromJson(json['tokens'] as Map<String, dynamic>),
      oktaAccessToken: json['okta_access_token'] as String?,
      needsLabImport: json['needs_lab_import'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [user, tokens, oktaAccessToken, needsLabImport];
}

class UserData extends Equatable {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String subscriptionTier;

  const UserData({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.subscriptionTier,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'] as int,
      email: (json['email'] as String?) ?? '',
      firstName: (json['first_name'] as String?) ?? 'Patient',
      lastName: (json['last_name'] as String?) ?? '',
      subscriptionTier: (json['subscription_tier'] as String?) ?? 'premium',
    );
  }

  String get fullName => '$firstName $lastName';

  @override
  List<Object?> get props => [id, email, firstName, lastName, subscriptionTier];
}

class TokenData extends Equatable {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;

  const TokenData({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
  });

  factory TokenData.fromJson(Map<String, dynamic> json) {
    return TokenData(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String,
      expiresIn: json['expires_in'] as int,
    );
  }

  @override
  List<Object?> get props => [accessToken, refreshToken, tokenType, expiresIn];
}
