import 'package:dio/dio.dart';
import 'package:flutter_auth_networking/api/api_client.dart';
import 'package:flutter_auth_networking/auth/auth_providers.dart';
import 'package:flutter_auth_networking/auth/auth_tokens.dart';
import 'package:flutter_auth_networking/auth/session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'fake_token_storage.dart';

const oldTokens = AuthTokens(
  accessToken: 'access-1',
  refreshToken: 'refresh-1',
);
const newTokens = AuthTokens(
  accessToken: 'access-2',
  refreshToken: 'refresh-2',
);

const oldHeader = {'Authorization': 'Bearer access-1'};
const newHeader = {'Authorization': 'Bearer access-2'};

const profile = {'email': 'demo@example.com', 'name': 'Demo User'};
const unauthorized = {'error': 'unauthorized'};

// Long enough for every request of a burst to get its 401 while the refresh
// is still running.
const refreshDelay = Duration(milliseconds: 50);

void main() {
  late FakeTokenStorage storage;
  late ProviderContainer container;

  // The two Dio instances the app uses, each with its own mocked server and
  // a log of the requests that went through it.
  late Dio apiDio;
  late DioAdapter apiServer;
  late List<RequestOptions> apiRequests;
  late DioAdapter plainServer;
  late List<RequestOptions> plainRequests;

  int refreshCalls() {
    return plainRequests.where((r) => r.path == '/auth/refresh').length;
  }

  SessionState session() => container.read(sessionControllerProvider);

  Interceptor recordInto(List<RequestOptions> log) {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        log.add(options);
        handler.next(options);
      },
    );
  }

  setUp(() async {
    storage = FakeTokenStorage(oldTokens);

    final plainDio = Dio(BaseOptions(baseUrl: 'http://server.test'));
    plainRequests = [];
    plainDio.interceptors.add(recordInto(plainRequests));
    plainServer = DioAdapter(dio: plainDio);

    container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        plainDioProvider.overrideWithValue(plainDio),
      ],
    );
    addTearDown(container.dispose);

    apiDio = container.read(apiDioProvider);
    apiRequests = [];
    apiDio.interceptors.add(recordInto(apiRequests));
    apiServer = DioAdapter(dio: apiDio);

    await container.read(sessionControllerProvider.notifier).restore();
    expect(session(), SessionState.signedIn);

    // The server no longer accepts the stored access token.
    apiServer.onGet(
      '/me',
      (server) => server.reply(401, unauthorized),
      headers: oldHeader,
    );
  });

  void refreshSucceeds() {
    plainServer.onPost(
      '/auth/refresh',
      (server) => server.reply(200, newTokens.toJson(), delay: refreshDelay),
      data: {'refreshToken': oldTokens.refreshToken},
    );
  }

  void retrySucceeds() {
    plainServer.onGet(
      '/me',
      (server) => server.reply(200, profile),
      headers: newHeader,
    );
  }

  Future<Response<Map<String, Object?>>> getProfile() {
    return apiDio.get<Map<String, Object?>>('/me');
  }

  final isUnauthorized = isA<DioException>().having(
    (e) => e.response?.statusCode,
    'status code',
    401,
  );

  test('five concurrent 401s share one refresh and all succeed', () async {
    refreshSucceeds();
    retrySucceeds();

    final responses = await Future.wait([
      for (var i = 0; i < 5; i++) getProfile(),
    ]);

    expect(responses.map((r) => r.data), everyElement(profile));
    expect(refreshCalls(), 1);
    expect(storage.tokens?.refreshToken, newTokens.refreshToken);
    expect(session(), SessionState.signedIn);
  });

  test('a rejected refresh expires the session without retrying', () async {
    plainServer.onPost(
      '/auth/refresh',
      (server) => server.reply(401, unauthorized, delay: refreshDelay),
      data: {'refreshToken': oldTokens.refreshToken},
    );

    final results = await Future.wait([
      for (var i = 0; i < 5; i++)
        getProfile().then<Object?>((r) => r, onError: (Object e) => e),
    ]);

    expect(results, everyElement(isUnauthorized));
    expect(refreshCalls(), 1);
    // Nothing but the single refresh attempt went out after the 401s.
    expect(plainRequests, hasLength(1));
    expect(storage.tokens, isNull);
    expect(session(), SessionState.expired);
  });

  test('the refresh request bypasses the auth interceptor', () async {
    refreshSucceeds();
    retrySucceeds();

    await getProfile();

    final refresh = plainRequests.singleWhere((r) => r.path == '/auth/refresh');
    expect(refresh.headers, isNot(contains('Authorization')));
    expect(apiRequests.map((r) => r.path), ['/me']);
  });

  test(
    'a retried request that is rejected again is not refreshed twice',
    () async {
      refreshSucceeds();
      plainServer.onGet(
        '/me',
        (server) => server.reply(401, unauthorized),
        headers: newHeader,
      );

      await expectLater(getProfile(), throwsA(isUnauthorized));

      expect(refreshCalls(), 1);
      expect(session(), SessionState.signedIn);
    },
  );

  test('a 401 that arrives after a refresh reuses the new token', () async {
    apiServer.onGet(
      '/me',
      (server) => server.reply(401, unauthorized, delay: refreshDelay),
      headers: oldHeader,
    );
    retrySucceeds();

    final response = getProfile();
    // While the request is in the air, another one finishes refreshing.
    await Future<void>.delayed(refreshDelay ~/ 2);
    storage.tokens = newTokens;

    expect((await response).data, profile);
    expect(refreshCalls(), 0);
  });

  test('a network failure during refresh keeps the session', () async {
    plainServer.onPost(
      '/auth/refresh',
      (server) => server.throws(
        0,
        DioException.connectionError(
          requestOptions: RequestOptions(path: '/auth/refresh'),
          reason: 'offline',
        ),
      ),
      data: {'refreshToken': oldTokens.refreshToken},
    );

    await expectLater(
      getProfile(),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.connectionError,
        ),
      ),
    );
    expect(storage.tokens?.refreshToken, oldTokens.refreshToken);
    expect(session(), SessionState.signedIn);
  });
}
