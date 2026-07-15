# ketok_dio

Dio integration for Ketok, the in-app Flutter network inspector: captures
every request, response, error, and cancellation made through a `Dio`
instance, and supports one-tap in-app replay.

See the [repo README](../../README.md) for what Ketok is and why (replay,
filter grammar, redaction-by-default) and the [`ketok`](../ketok) package
for the facade that wires this up in an app.

## Install

```yaml
dependencies:
  ketok_dio: ^0.1.0
```

## Attach

```dart
import 'package:dio/dio.dart';
import 'package:ketok_dio/ketok_dio.dart';

final dio = Dio();
KetokDio.attach(dio); // adds the interceptor AND enables replay for `dio`
```

`KetokDio.attach` reads `KetokBinding.instance` (wired up by
`Ketok.initialize()` from the `ketok` facade package), adds a
`KetokDioInterceptor` to `dio`, and registers a `KetokDioReplayer` for it so
the inspector UI's Replay action can re-issue calls made through `dio`.

Plain `dio.interceptors.add(KetokDioInterceptor())` also works and captures
calls identically — it just skips replay registration, so the Replay button
stays disabled for calls made through that `Dio` instance.

## Replay

Replaying a captured call rebuilds its `RequestOptions` and re-issues it
through the same `Dio` instance, so it flows through interceptors again and
is captured as a fresh entry with `replayOf` set to the original call's id.
Headers that were redacted at capture time (e.g. `Authorization`) are never
resent — Ketok never retains the real secret to resend in the first place.

## Production safety

- Every interceptor hook checks `KetokBinding.instance.isEnabled` first and
  forwards immediately when Ketok is disabled — zero capture work on the hot
  networking path, and safe to leave `KetokDioInterceptor` attached in
  release builds.
- A bug in Ketok's own capture logic can never break your networking: every
  hook wraps its capture work in `try`/`catch` and always forwards the
  request/response/error exactly once, regardless of whether capture
  succeeded.
- Sensitive header values (e.g. `Authorization`, `Cookie`) are redacted
  **at capture time**, before anything enters the in-memory store, and large
  bodies are hard-capped (`KetokConfig.maxBodyBytes`, default 512 KB) so
  Ketok stays safe against production-sized traffic.
