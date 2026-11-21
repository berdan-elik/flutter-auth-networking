import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Prefilled with the only account the fake server knows.
  final _email = TextEditingController(text: 'demo@example.com');
  final _password = TextEditingController(text: 'password');

  var _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      // On success the router redirects, so there is nothing to do here.
      await ref
          .read(sessionControllerProvider.notifier)
          .signIn(email: _email.text.trim(), password: _password.text);
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _error = e.response?.statusCode == 401
            ? 'Wrong email or password.'
            : 'Could not reach the server.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final expired =
        ref.watch(sessionControllerProvider) == SessionState.expired;

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (expired) ...[
            const Text('Your session expired. Sign in again.'),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: const Text('Sign in'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
