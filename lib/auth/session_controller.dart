import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';
import 'auth_tokens.dart';

enum SessionState { signedOut, signedIn, expired }

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() => SessionState.signedOut;

  /// Called once before the first frame, so the router starts on the right
  /// screen instead of flashing the login page.
  Future<void> restore() async {
    final tokens = await ref.read(tokenStorageProvider).read();
    if (tokens != null) {
      state = SessionState.signedIn;
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    final response = await ref
        .read(plainDioProvider)
        .post<Map<String, Object?>>(
          '/auth/login',
          data: {'email': email, 'password': password},
        );
    await ref
        .read(tokenStorageProvider)
        .write(AuthTokens.fromJson(response.data!));
    state = SessionState.signedIn;
  }

  Future<void> signOut() async {
    await ref.read(tokenStorageProvider).clear();
    state = SessionState.signedOut;
  }

  /// Called by the token refresher after the server rejected the refresh
  /// token. The tokens are already cleared at that point.
  void expire() {
    state = SessionState.expired;
  }
}
