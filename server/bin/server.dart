import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

const demoEmail = 'demo@example.com';
const demoPassword = 'password';

Future<void> main() async {
  final env = Platform.environment;
  final port = int.parse(env['PORT'] ?? '8080');
  final accessTtl = Duration(
    seconds: int.parse(env['ACCESS_TTL_SECONDS'] ?? '10'),
  );

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(AuthServer(accessTtl: accessTtl).router.call);
  final server = await shelf_io.serve(
    handler,
    InternetAddress.loopbackIPv4,
    port,
  );

  stdout.writeln(
    'listening on http://${server.address.host}:${server.port} '
    '(access tokens live ${accessTtl.inSeconds}s)',
  );
}

class AuthServer {
  AuthServer({required this.accessTtl});

  final Duration accessTtl;

  // Generated per process, so the repo holds no signing secret. Tokens issued
  // before a restart stop verifying, which the app sees as an expired session.
  final _signingKey = SecretKey(_randomToken());

  // Refresh token -> email. A refresh token is removed when it is used, so
  // presenting the same one twice fails the second time.
  final _refreshTokens = <String, String>{};

  var _refreshCount = 0;

  Router get router => Router()
    ..post('/auth/login', _login)
    ..post('/auth/refresh', _refresh)
    ..get('/me', _me)
    ..get('/stats', _stats);

  Future<Response> _login(Request request) async {
    final body = await _readJson(request);
    if (body['email'] != demoEmail || body['password'] != demoPassword) {
      return _json(401, {'error': 'invalid_credentials'});
    }
    return _json(200, _issueTokens(demoEmail));
  }

  Future<Response> _refresh(Request request) async {
    final body = await _readJson(request);
    final email = _refreshTokens.remove(body['refreshToken']);
    if (email == null) {
      return _json(401, {'error': 'invalid_refresh_token'});
    }
    _refreshCount++;
    return _json(200, _issueTokens(email));
  }

  Response _me(Request request) {
    final email = _authenticate(request);
    if (email == null) {
      return _json(401, {'error': 'invalid_access_token'});
    }
    return _json(200, {'email': email, 'name': 'Demo User'});
  }

  Response _stats(Request request) {
    return _json(200, {'refreshCount': _refreshCount});
  }

  Map<String, Object?> _issueTokens(String email) {
    final refreshToken = _randomToken();
    _refreshTokens[refreshToken] = email;
    return {
      'accessToken': JWT(
        <String, Object?>{},
        subject: email,
      ).sign(_signingKey, expiresIn: accessTtl),
      'refreshToken': refreshToken,
    };
  }

  String? _authenticate(Request request) {
    final header = request.headers[HttpHeaders.authorizationHeader];
    if (header == null || !header.startsWith('Bearer ')) {
      return null;
    }
    // tryVerify returns null for a bad signature and for an expired token.
    return JWT.tryVerify(header.substring(7), _signingKey)?.subject;
  }
}

Future<Map<String, Object?>> _readJson(Request request) async {
  try {
    final decoded = jsonDecode(await request.readAsString());
    return decoded is Map<String, Object?> ? decoded : const {};
  } on FormatException {
    return const {};
  }
}

Response _json(int status, Map<String, Object?> body) {
  return Response(
    status,
    body: jsonEncode(body),
    headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
  );
}

String _randomToken() {
  final random = Random.secure();
  final bytes = List.generate(32, (_) => random.nextInt(256));
  return base64Url.encode(bytes);
}
