import 'package:dio/dio.dart';

import 'auth_tokens.dart';
import 'token_storage.dart';

class SessionExpiredException implements Exception {
  const SessionExpiredException();

  @override
  String toString() => 'SessionExpiredException';
}

class TokenRefresher {
  /// The Dio passed here must not have the auth interceptor attached,
  /// otherwise a 401 from the refresh endpoint would trigger another refresh.
  TokenRefresher({
    required this._dio,
    required this._storage,
    required this._onSessionExpired,
  });

  final Dio _dio;
  final TokenStorage _storage;
  final void Function() _onSessionExpired;

  Future<AuthTokens>? _inFlight;

  /// Callers that arrive while a refresh is running get the same future, so
  /// the refresh token is spent once and they all see the same outcome.
  Future<AuthTokens> refresh() {
    return _inFlight ??= _refresh().whenComplete(() => _inFlight = null);
  }

  Future<AuthTokens> _refresh() async {
    final current = await _storage.read();
    if (current == null) {
      // Signed out while a request was in the air. Nothing to expire.
      throw const SessionExpiredException();
    }

    try {
      final response = await _dio.post<Map<String, Object?>>(
        '/auth/refresh',
        data: {'refreshToken': current.refreshToken},
      );
      final tokens = AuthTokens.fromJson(response.data!);
      await _storage.write(tokens);
      return tokens;
    } on DioException catch (e) {
      // Only a 401 means the refresh token is dead. A timeout or a 500 says
      // nothing about the session, so the tokens stay and the error surfaces.
      if (e.response?.statusCode != 401) {
        rethrow;
      }
      await _storage.clear();
      _onSessionExpired();
      throw const SessionExpiredException();
    }
  }
}
