# flutter-auth-networking

A networking layer for Flutter that keeps a JWT session alive on top of Dio.
When a request gets a 401, it refreshes the access token and retries the
request. When several requests get a 401 at the same time, they share one
refresh.

The repo holds the layer, a small example app and a fake backend, so it runs
without any external service.

## Run it

Start the backend, then the app on an Android emulator or iOS simulator:

```sh
cd server && dart run bin/server.dart
```

```sh
flutter run
```

Sign in with the prefilled account. Access tokens live for 10 seconds
(`ACCESS_TTL_SECONDS` changes that). Wait for the token to expire and tap
"Send 5 requests at once". The server log shows five 401s, one
`POST /auth/refresh` and five 200s, and the counter on screen goes up by one.

Restart the server to see the other path: it forgets every refresh token, the
next refresh is rejected and the app returns to the login screen.

The server listens on loopback only, so a physical phone cannot reach it. The
app talks to `10.0.2.2:8080` on Android and `127.0.0.1:8080` on iOS; pass
`--dart-define=API_BASE_URL=...` to point it elsewhere.

## Layout

```
lib/auth/token_storage.dart      storage interface, secure storage behind it
lib/auth/token_refresher.dart    single-flight refresh
lib/auth/auth_interceptor.dart   adds the header, refreshes and retries on 401
lib/auth/session_controller.dart signedOut / signedIn / expired
lib/api/api_client.dart          wires the pieces into the Dio the app uses
lib/router.dart                  go_router redirect driven by the session
server/bin/server.dart           fake backend (shelf)
test/auth_flow_test.dart         the behaviour described below
```

## Design notes

**The race.** The server rotates refresh tokens: each one works once. If two
requests get a 401 and each starts its own refresh, the first spends the
token and the second is rejected. From the server's side that looks like a
stolen token, and the user is signed out for no reason.

**A shared `Future` instead of a lock.** `TokenRefresher` keeps the `Future`
of the refresh that is running and hands the same one to every caller. All of
them wait on one request and see one outcome, success or failure. A lock only
makes callers take turns; the second one still has to find out that a refresh
just happened. Dart runs this code on one thread, so storing the `Future` is
not itself a race.

**A 401 that arrives late.** A request sent with the old token can get its
401 after the refresh has finished. The interceptor compares the token the
request was sent with to the stored one, and if they differ it retries with
the stored token instead of refreshing again.

**No loop by construction.** The refresh call and the retry go through a
second Dio that has no auth interceptor. A 401 on either reaches the caller;
nothing can trigger another refresh. There is no "already retried" flag to
forget.

**Only a 401 ends the session.** If the refresh fails with a timeout or a
500, the tokens stay and the request fails. A dropped connection should not
sign anyone out.

**Tokens in secure storage.** A refresh token is a long-lived credential.
`flutter_secure_storage` keeps it in the Keychain on iOS and encrypts it with
a Keystore key on Android, where shared preferences would be a plain file.
Both tokens are written under one key so the pair is replaced as a whole.

## Tests

```sh
flutter test
```

- five concurrent 401s produce one refresh call and five successful responses
- a rejected refresh expires the session; there is no retry and no second
  refresh
- the refresh request does not pass through the auth interceptor
- a retried request that gets a 401 again is not refreshed a second time
- a late 401 reuses the new token
- a network failure during refresh keeps the session

## Not done

- Social login, biometric unlock, an offline request queue.
- Refreshing before the token expires. The layer reacts to 401s only.
- Server-side logout. Signing out deletes the tokens on the device.
- Retrying requests whose body is a stream (file uploads); the body cannot be
  sent twice.
- If the user signs out while a refresh is in the air, the new tokens are
  still written to storage.
- The iOS build. The example app was run on an Android emulator only.
- Built with Flutter 3.44. From 3.47 on, the analyzer reports
  `package:flutter/material.dart` as deprecated in favour of `material_ui`.

## License

MIT
