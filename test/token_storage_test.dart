import 'package:flutter_auth_networking/auth/auth_providers.dart';
import 'package:flutter_auth_networking/auth/session_controller.dart';
import 'package:flutter_auth_networking/auth/token_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

// The key SecureTokenStorage writes under.
const key = 'auth_tokens';

void main() {
  test('reads back a stored pair', () async {
    FlutterSecureStorage.setMockInitialValues({
      key: '{"accessToken":"access-1","refreshToken":"refresh-1"}',
    });

    final tokens = await SecureTokenStorage().read();

    expect(tokens?.accessToken, 'access-1');
    expect(tokens?.refreshToken, 'refresh-1');
  });

  for (final (description, raw) in [
    ('is not JSON', 'not json'),
    ('has the wrong shape', '{"accessToken":1}'),
  ]) {
    test('drops stored data that $description', () async {
      FlutterSecureStorage.setMockInitialValues({key: raw});

      expect(await SecureTokenStorage().read(), isNull);
      expect(await const FlutterSecureStorage().read(key: key), isNull);
    });
  }

  test('corrupt stored data starts the session signed out', () async {
    FlutterSecureStorage.setMockInitialValues({key: 'not json'});
    final container = ProviderContainer(
      overrides: [tokenStorageProvider.overrideWithValue(SecureTokenStorage())],
    );
    addTearDown(container.dispose);

    await container.read(sessionControllerProvider.notifier).restore();

    expect(container.read(sessionControllerProvider), SessionState.signedOut);
  });
}
