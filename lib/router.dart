import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth/session_controller.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // go_router re-runs redirect when a Listenable fires. This notifier mirrors
  // the session state so a change moves the user without any screen having
  // to navigate.
  final session = ValueNotifier(ref.read(sessionControllerProvider));
  ref.listen(sessionControllerProvider, (_, next) => session.value = next);
  ref.onDispose(session.dispose);

  return GoRouter(
    initialLocation: '/profile',
    refreshListenable: session,
    redirect: (context, state) {
      final signedIn = session.value == SessionState.signedIn;
      final atLogin = state.matchedLocation == '/login';
      if (!signedIn) {
        return atLogin ? null : '/login';
      }
      return atLogin ? '/profile' : null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});
