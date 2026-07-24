# jala_dio

Dio integration for Jala, the in-app Flutter network inspector: captures
every request, response, error, and cancellation made through a `Dio`
instance, and supports one-tap in-app replay and network throttling.

See the [repo README](../../README.md) for what Jala is and why (replay,
filter grammar, redaction-by-default) and the [`jala`](../jala) package
for the facade that wires this up in an app.

**Existing app?** [docs/ADOPTION.md](../../docs/ADOPTION.md).  
**Lockstep:** use the same `0.6.x` as `jala` / `jala_core` (see
[docs/COMPAT.md](../../docs/COMPAT.md)). Requires Dart `^3.11`.

## Install

```yaml
dependencies:
  jala: ^0.6.0
  jala_dio: ^0.6.0   # requires jala_core ^0.6.0
  dio: ^5.0.0
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

**Multiple clients:** each `JalaDio.attach` / `JalaHttp.wrap` registers a
replayer; the **last** registration wins for the inspector’s Replay button.
Attach every Dio you want **captured**, and attach your **primary** API
client last (or accept that secondary clients capture but may not replay).
Details: [ADOPTION — multiple Dio](../../docs/ADOPTION.md#multiple-dio-instances-very-common).

## Throttling

`JalaDioInterceptor.onRequest` consults `JalaBinding.instance
.throttleRegistry` (configured from the inspector UI or directly via
`JalaThrottleRegistry.setActive`) whenever a profile is active and the
request's host matches the profile's host pattern:

- A 100% drop-rate profile (e.g. the `offline` preset) rejects the request
  with a connection-error `DioException` **before it ever reaches your
  `HttpClientAdapter`** — captured as a normal error entry, tagged
  `throttledBy: <profileId>`.
- Otherwise the profile's latency (± jitter) delays the request before
  it's forwarded.
- Bandwidth pacing (`downloadBytesPerSec`) is honored **only** for
  `ResponseType.stream` responses — each chunk of the response stream is
  delayed to simulate the cap. Dio's default (buffered) response types
  resolve to bytes entirely inside Dio's own transformer, off a stream
  this interceptor never sees, so they get latency/drop treatment only,
  never bandwidth pacing. Request a streamed response
  (`Options(responseType: ResponseType.stream)`) if you need to see a
  download visibly slow down.

No profile active (the common case) costs a cheap null/host-pattern check
on the existing hot path — no measurable overhead.

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
