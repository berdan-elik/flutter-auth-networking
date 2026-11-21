import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../auth/auth_providers.dart';
import '../auth/session_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _burstSize = 5;

  late final Future<Map<String, Object?>> _profile = _fetchProfile();

  var _sending = false;
  String? _burstResult;
  int? _refreshCount;

  @override
  void initState() {
    super.initState();
    _loadRefreshCount();
  }

  Future<Map<String, Object?>> _fetchProfile() async {
    final response = await ref
        .read(apiDioProvider)
        .get<Map<String, Object?>>('/me');
    return response.data!;
  }

  /// Fires the requests together. With an expired access token all of them
  /// get a 401, and the server counter should still go up by exactly one.
  Future<void> _sendBurst() async {
    setState(() => _sending = true);

    final dio = ref.read(apiDioProvider);
    final results = await Future.wait([
      for (var i = 0; i < _burstSize; i++)
        dio.get<Object?>('/me').then((_) => true, onError: (Object _) => false),
    ]);
    await _loadRefreshCount();

    if (!mounted) {
      return;
    }
    final succeeded = results.where((ok) => ok).length;
    setState(() {
      _sending = false;
      _burstResult = '$succeeded of $_burstSize requests succeeded.';
    });
  }

  Future<void> _loadRefreshCount() async {
    try {
      final response = await ref
          .read(plainDioProvider)
          .get<Map<String, Object?>>('/stats');
      if (mounted) {
        setState(() => _refreshCount = response.data!['refreshCount']! as int);
      }
    } on DioException {
      // The counter is informational. Keep the last known value.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(sessionControllerProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder(
            future: _profile,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Could not load the profile.');
              }
              final profile = snapshot.data;
              if (profile == null) {
                return const LinearProgressIndicator();
              }
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(profile['name']! as String),
                subtitle: Text(profile['email']! as String),
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Refresh calls seen by the server: ${_refreshCount ?? '-'}'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _sending ? null : _sendBurst,
            child: const Text('Send $_burstSize requests at once'),
          ),
          if (_burstResult != null) ...[
            const SizedBox(height: 12),
            Text(_burstResult!),
          ],
          const SizedBox(height: 24),
          const Text(
            'Access tokens live for a few seconds. Wait for one to expire, '
            'then send the requests: the counter goes up by one, not by '
            '$_burstSize.',
          ),
        ],
      ),
    );
  }
}
