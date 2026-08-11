## 0.8.2 — 2026-08-11

- Lockstep release. No changes in this package; `jala_core` gains
  `JalaConfig.locale` and the inspector UI ships in Indonesian — see the
  `jala` and `jala_ui` changelogs.

## 0.8.1 — not published separately

Prepared in the repo, then folded into 0.8.2 before it reached
pub.dev. Everything below shipped **in 0.8.2**; there is no 0.8.1
on pub.dev.

- Lockstep release. No changes in this package; see the `jala` and
  `jala_ui` changelogs for the Android input/back fixes and the new
  file-backed export destination.

## 0.8.0 — 2026-08-03

### Fixed

- **Request and response bodies are now redacted on Dio's default paths.**
  Redaction was applied only to bodies that were already `String`, so
  `data: <String, dynamic>{...}` requests and the default
  `ResponseType.json` responses — both decoded `Map`s — were stored
  verbatim. `redactedBodyPatterns` and the built-in JSON secret-key
  patterns silently did nothing for the majority of Dio traffic.
- **Bandwidth throttling applies to buffered responses and requests.**
  `downloadBytesPerSec` previously only affected `ResponseType.stream`
  responses and `uploadBytesPerSec` was never applied at all, so picking
  "Slow 3G" on a normal Dio app honored its latency and drop rate but
  ignored its 50 KB/s cap. A buffered body cannot be delivered
  progressively, so it is held for the time those bytes would have taken;
  end-to-end timing now matches the streamed path.
- `JalaDioReplayer` refuses to replay an entry whose request body was
  truncated at capture time instead of resending the retained prefix.

## 0.7.0

- Sensitive query-parameter values (`?access_token=…`) are masked at
  capture time via `JalaRedactor.redactUri`, so the real value never
  reaches the store or any export. The outgoing request and mock matching
  still see the real URL.
- Replay drops query parameters whose value was masked, mirroring how it
  already drops redacted headers rather than resending the mask.

## 0.6.0

- Lockstep release with jala_core 0.6.0 (call diff + import codecs).

## 0.5.3

- Lockstep release with jala_core 0.5.3 security defaults.

## 0.5.2

- Lockstep release; no functional changes.

## 0.5.1

- Pub metadata: `homepage`, `issue_tracker`, clearer description.
- Docs: multi-client replay ownership (last `JalaDio.attach` wins);
  lockstep 0.5.x note; link to ADOPTION guide.

## 0.5.0

- Network throttling: `onRequest` consults `JalaBinding.instance
  .throttleRegistry` — a 100%-drop profile rejects with a connection-error
  `DioException` (captured as a normal error entry, tagged
  `throttledBy: <profileId>`); otherwise the configured latency (+ jitter)
  delays the request before it's forwarded. Only applied when a profile is
  active and the request's host matches the profile's host pattern.
- Bandwidth pacing (`downloadBytesPerSec`) delays each chunk of a
  `ResponseType.stream` response. Dio's default (buffered) response types
  resolve to bytes entirely inside Dio's own transformer, off a stream
  this interceptor never sees — those responses get latency/drop only,
  never pacing (documented in the README).
- Zero overhead when no profile is active: the throttle check is a cheap
  null/host-pattern check on the existing hot path, no behavior change.

## 0.4.0

- Lockstep release; no functional changes. Bumped for the `jala_core`
  0.4.0 dependency (GraphQL metadata + WebSocket models, unused by this
  package directly).

## 0.3.0

- Rule-based request mocking: after capture, match `JalaMockRegistry` and
  short-circuit with canned response, synthetic failure, or delay (only
  when Jala is enabled).
- Edit-and-resend: `JalaDioReplayer.replayModified` rebuilds
  `RequestOptions` with method/URL/headers/body overrides.

## 0.2.0

- Capture `FormData` as structured multipart parts (`@multipart` convention)
  without reading file bytes.
- Capture `ResponseType.bytes` image responses as `BodyKind.image` when
  within `maxBodyBytes` and `captureImageBodies` is enabled.
- Upload/download progress: wrap `Stream` request bodies and
  `ResponseType.stream` response bodies to emit `NetworkProgressEvent`
  (plain Map/JSON bodies remain no-progress by design — see interceptor
  docs).

## 0.1.1

- Add pub.dev topics.

## 0.1.0

- `JalaDioInterceptor` capturing request/response/error/cancel events for
  any `Dio` instance, with headers redacted at capture time.
- `JalaDio.attach(dio)` convenience that adds the interceptor and
  registers a replayer for `dio` in one call.
- `JalaDioReplayer` — one-tap in-app replay by rebuilding
  `RequestOptions` and re-issuing via `dio.fetch`, tagging the new entry
  with `replayOf`.
- `FormData` fields and file names/sizes are summarized without ever
  reading file bytes; `ResponseType.stream`/`bytes` responses are captured
  as metadata only.
- Every interceptor hook checks `JalaBinding.instance.isEnabled` first and
  is wrapped in try/catch, so a disabled Jala or a capture bug can never
  affect app networking.
