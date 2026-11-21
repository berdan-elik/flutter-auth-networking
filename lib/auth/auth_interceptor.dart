import 'package:dio/dio.dart';

import 'token_refresher.dart';
import 'token_storage.dart';

class AuthInterceptor extends Interceptor {
  /// The retry goes through [retryDio], which has no auth interceptor. A
  /// second 401 on the retried request therefore reaches the caller instead
  /// of starting another refresh.
  AuthInterceptor({
    required this._storage,
    required this._refresher,
    required this._retryDio,
  });

  static const _header = 'Authorization';

  final TokenStorage _storage;
  final TokenRefresher _refresher;
  final Dio _retryDio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final tokens = await _storage.read();
    if (tokens != null) {
      options.headers[_header] = _bearer(tokens.accessToken);
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final sentHeader = options.headers[_header];
    if (err.response?.statusCode != 401 || sentHeader == null) {
      return handler.next(err);
    }

    try {
      // A 401 can arrive after another request already refreshed. The stored
      // token then differs from the one this request was sent with, and
      // refreshing again would spend a refresh token for nothing.
      final stored = await _storage.read();
      final tokens = stored != null && _bearer(stored.accessToken) != sentHeader
          ? stored
          : await _refresher.refresh();

      options.headers[_header] = _bearer(tokens.accessToken);
      handler.resolve(await _retryDio.fetch<Object?>(options));
    } on SessionExpiredException {
      handler.next(err);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  String _bearer(String accessToken) => 'Bearer $accessToken';
}
