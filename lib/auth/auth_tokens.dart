class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  factory AuthTokens.fromJson(Map<String, Object?> json) {
    return AuthTokens(
      accessToken: json['accessToken']! as String,
      refreshToken: json['refreshToken']! as String,
    );
  }

  final String accessToken;
  final String refreshToken;

  Map<String, Object?> toJson() {
    return {'accessToken': accessToken, 'refreshToken': refreshToken};
  }
}
