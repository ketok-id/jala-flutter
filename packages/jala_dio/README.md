# jala_dio

Dio integration for Jala, the in-app Flutter network inspector: captures
every request, response, error, and cancellation made through a `Dio`
instance, and supports one-tap in-app replay.

See the [repo README](../../README.md) for what Jala is and why (replay,
filter grammar, redaction-by-default) and the [`jala`](../jala) package
for the facade that wires this up in an app.

## Install

```yaml
dependencies:
  jala_dio: ^0.3.0   # requires jala_core ^0.2.0
```

## Attach

```dart
import 'package:dio/dio.dart';
import 'package:jala_dio/jala_dio.dart';

final dio = Dio();
JalaDio.attach(dio); // adds the interceptor AND enables replay for `dio`
```

`JalaDio.attach` reads `JalaBinding.instance` (wired up by
`Jala.initialize()` from the `jala` facade package), adds a
`JalaDioInterceptor` to `dio`, and registers a `JalaDioReplayer` for it so
the inspector UI's Replay action can re-issue calls made through `dio`.

Plain `dio.interceptors.add(JalaDioInterceptor())` also works and captures
calls identically — it just skips replay registration, so the Replay button
stays disabled for calls made through that `Dio` instance.

## Replay

Replaying a captured call rebuilds its `RequestOptions` and re-issues it
through the same `Dio` instance, so it flows through interceptors again and
is captured as a fresh entry with `replayOf` set to the original call's id.
Headers that were redacted at capture time (e.g. `Authorization`) are never
resent — Jala never retains the real secret to resend in the first place.

## Production safety

- Every interceptor hook checks `JalaBinding.instance.isEnabled` first and
  forwards immediately when Jala is disabled — zero capture work on the hot
  networking path, and safe to leave `JalaDioInterceptor` attached in
  release builds.
- A bug in Jala's own capture logic can never break your networking: every
  hook wraps its capture work in `try`/`catch` and always forwards the
  request/response/error exactly once, regardless of whether capture
  succeeded.
- Sensitive header values (e.g. `Authorization`, `Cookie`) are redacted
  **at capture time**, before anything enters the in-memory store, and large
  bodies are hard-capped (`JalaConfig.maxBodyBytes`, default 512 KB) so
  Jala stays safe against production-sized traffic.
