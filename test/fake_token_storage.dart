import 'package:flutter_auth_networking/auth/auth_tokens.dart';
import 'package:flutter_auth_networking/auth/token_storage.dart';

class FakeTokenStorage implements TokenStorage {
  FakeTokenStorage([this.tokens]);

  AuthTokens? tokens;

  @override
  Future<AuthTokens?> read() async => tokens;

  @override
  Future<void> write(AuthTokens tokens) async => this.tokens = tokens;

  @override
  Future<void> clear() async => tokens = null;
}
