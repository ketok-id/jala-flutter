# jala_http

`package:http` integration for Jala, the in-app Flutter network inspector:
captures every request, response, and error made through a `http.Client`,
and supports one-tap in-app replay and full network throttling (latency,
drop, upload + download pacing).

See the [repo README](../../README.md) for what Jala is and why (replay,
filter grammar, redaction-by-default) and the [`jala`](../jala) package
for the facade that wires this up in an app.

**Lockstep** with `jala` / `jala_core` `0.5.x`. Brownfield:
[docs/ADOPTION.md](../../docs/ADOPTION.md).

## Install

```yaml
dependencies:
  jala_http: ^0.5.2   # requires jala_core ^0.5.2
```

## Wrap

```dart
import 'package:http/http.dart' as http;
import 'package:jala_http/jala_http.dart';

final client = JalaHttp.wrap(http.Client());
await client.get(Uri.parse('https://example.com'));
```

`JalaHttp.wrap` reads `JalaBinding.instance` (wired up by
`Jala.initialize()` from the `jala` facade package), wraps the given
`http.Client` (a fresh one when omitted) in a [`JalaHttpClient`], and
registers a `JalaHttpReplayer` for it so the inspector UI's Replay action
can re-issue calls made through the returned client.

Plain `JalaHttpClient(inner: http.Client())` also works and captures calls
identically — it just skips replay registration, so the Replay button
stays disabled for calls made through that client.

## The stream tee

`http.Client.send()` returns a `StreamedResponse` whose body is a stream —
`JalaHttpClient` must capture a preview of it without ever preventing the
caller from receiving the complete, original body. It does this with a
tee: every chunk from the real response stream is forwarded to the caller
unmodified, while a separate buffer (capped at `maxBodyBytes`) and byte
counter track a preview and the true total size for the inspector. A
download larger than the cap is delivered to your app in full; only the
inspector's preview is truncated.

## Replay

Replaying a captured call rebuilds a `http.Request` and re-issues it
through the same wrapped client, so it's captured as a fresh entry with
`replayOf` set to the original call's id. Headers that were redacted at
capture time (e.g. `Authorization`) are never resent — Jala never retains
the real secret to resend in the first place.

## Throttling

`JalaHttpClient.send` consults `JalaBinding.instance.throttleRegistry`
(configured from the inspector UI or directly via
`JalaThrottleRegistry.setActive`) whenever a profile is active and the
request's host matches the profile's host pattern:

- A 100% drop-rate profile (e.g. the `offline` preset) throws
  `http.ClientException` **before the request ever reaches your wrapped
  client** — captured as a normal error entry, tagged
  `throttledBy: <profileId>`.
- Otherwise the profile's latency (± jitter) delays the request before
  it's forwarded.
- Bandwidth pacing is applied in **both** directions — unlike `jala_dio`,
  which can only pace `ResponseType.stream` responses, `JalaHttpClient`
  sees every request/response byte, so it gets the complete treatment:
  `downloadBytesPerSec` delays each chunk of the response stream tee (see
  above), and `uploadBytesPerSec` delays each chunk of the finalized
  request byte stream.

No profile active (the common case) costs a cheap null/host-pattern check
on the existing hot path — no measurable overhead.

## Production safety

- `send()` checks `JalaBinding.instance.isEnabled` first and forwards
  immediately when Jala is disabled — zero capture work on the hot
  networking path, and safe to leave `JalaHttpClient` wrapped in release
  builds.
- A bug in Jala's own capture logic can never break your networking:
  capture is wrapped in `try`/`catch` throughout, and the request/response
  is always forwarded exactly once regardless of whether capture
  succeeded.
- Sensitive header values (e.g. `Authorization`, `Cookie`) are redacted
  **at capture time**, before anything enters the in-memory store, and
  response bodies are captured through a bounded stream tee (see above) so
  Jala stays safe against large-body production traffic.
