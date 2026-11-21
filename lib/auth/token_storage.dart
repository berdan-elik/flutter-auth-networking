import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_tokens.dart';

abstract interface class TokenStorage {
  Future<AuthTokens?> read();

  Future<void> write(AuthTokens tokens);

  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([this._storage = const FlutterSecureStorage()]);

  static const _key = 'auth_tokens';

  final FlutterSecureStorage _storage;

  // Every request reads the access token. Keeping the pair in memory after
  // the first read avoids a platform channel round trip per request.
  AuthTokens? _cached;
  var _loaded = false;

  @override
  Future<AuthTokens?> read() async {
    if (!_loaded) {
      final raw = await _storage.read(key: _key);
      if (raw != null) {
        _cached = _decode(raw);
        if (_cached == null) {
          // Unreadable data cannot become readable later. Dropping it lets
          // the app start signed out instead of failing on every launch.
          await _storage.delete(key: _key);
        }
      }
      _loaded = true;
    }
    return _cached;
  }

  // Both tokens go under one key so a write replaces the pair as a whole.
  // Two keys could leave a new access token next to an old refresh token if
  // the app died between the writes.
  @override
  Future<void> write(AuthTokens tokens) async {
    await _storage.write(key: _key, value: jsonEncode(tokens));
    _cached = tokens;
    _loaded = true;
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _key);
    _cached = null;
    _loaded = true;
  }

  AuthTokens? _decode(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json case {
        'accessToken': final String accessToken,
        'refreshToken': final String refreshToken,
      }) {
        return AuthTokens(accessToken: accessToken, refreshToken: refreshToken);
      }
    } on FormatException {
      // Not JSON at all.
    }
    return null;
  }
}
