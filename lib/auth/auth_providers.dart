import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'token_storage.dart';

// The Android emulator reaches the host machine at 10.0.2.2, the iOS
// simulator shares the host's loopback.
const _baseUrlOverride = String.fromEnvironment('API_BASE_URL');

String get _baseUrl {
  if (_baseUrlOverride.isNotEmpty) {
    return _baseUrlOverride;
  }
  return defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:8080'
      : 'http://127.0.0.1:8080';
}

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return SecureTokenStorage();
});

/// Dio without the auth interceptor. Login, refresh and the retry after a
/// refresh go through it.
final plainDioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );
});
