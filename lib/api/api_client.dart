import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_interceptor.dart';
import '../auth/auth_providers.dart';
import '../auth/session_controller.dart';
import '../auth/token_refresher.dart';

final tokenRefresherProvider = Provider<TokenRefresher>((ref) {
  return TokenRefresher(
    dio: ref.watch(plainDioProvider),
    storage: ref.watch(tokenStorageProvider),
    onSessionExpired: () {
      ref.read(sessionControllerProvider.notifier).expire();
    },
  );
});

/// Dio for authenticated endpoints.
final apiDioProvider = Provider<Dio>((ref) {
  final plainDio = ref.watch(plainDioProvider);
  return Dio(plainDio.options)
    ..interceptors.add(
      AuthInterceptor(
        storage: ref.watch(tokenStorageProvider),
        refresher: ref.watch(tokenRefresherProvider),
        retryDio: plainDio,
      ),
    );
});
