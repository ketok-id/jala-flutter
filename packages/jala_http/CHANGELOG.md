## 0.8.1 — 2026-08-11

- Lockstep release. No changes in this package; see the `jala` and
  `jala_ui` changelogs for the Android input/back fixes and the new
  file-backed export destination.

## 0.8.0 — 2026-08-03

### Fixed

- **Request and response bodies are now redacted.** This adapter never
  called `JalaRedactor.redactBody` at all, so neither the built-in
  JSON/form secret-key patterns nor a caller's `redactedBodyPatterns`
  applied to anything it captured: passwords and tokens in bodies reached
  the store, the inspector UI, and every cURL / HAR / session export
  verbatim, contradicting the capture-time redaction guarantee.
- An over-cap response is still reported as truncated once redaction has
  shrunk it. Truncation was forced by capping at one byte below the
  buffered length, which masking could push the body back under.
- `JalaHttpReplayer` refuses to replay an entry whose request body was
  truncated at capture time instead of resending the retained prefix.

## 0.7.0

- Sensitive query-parameter values (`?access_token=…`) are masked at
  capture time via `JalaRedactor.redactUri`, so the real value never
  reaches the store or any export. The outgoing request still carries the
  real URL.
- Replay drops query parameters whose value was masked, mirroring how it
  already drops redacted headers rather than resending the mask.

## 0.6.0

- Lockstep release with jala_core 0.6.0 (call diff + import codecs).

## 0.5.3

- Lockstep release with jala_core 0.5.3 security defaults.

## 0.5.2

- Lockstep release; no functional changes.

## 0.5.1

- Pub metadata: `homepage`, `issue_tracker`, clearer description (docs-only).

## 0.5.0

- Network throttling: `send()` consults `JalaBinding.instance
  .throttleRegistry` — a 100%-drop profile throws `http.ClientException`
  (captured as a normal error entry, tagged `throttledBy: <profileId>`)
  before ever reaching the inner client; otherwise the configured latency
  (+ jitter) delays the request first. Only applied when a profile is
  active and the request's host matches the profile's host pattern.
- Full bandwidth pacing, both directions: download pacing
  (`downloadBytesPerSec`) delays each chunk of the response stream tee
  before it reaches the caller; upload pacing (`uploadBytesPerSec`) delays
  each chunk of the finalized request byte stream. `package:http` gets the
  complete throttle treatment (unlike `jala_dio`, which can only pace
  `ResponseType.stream` responses).
- Zero overhead when no profile is active: the throttle check is a cheap
  null/host-pattern check on the existing hot path, no behavior change.

## 0.4.0

- Lockstep release; no functional changes. Bumped for the `jala_core`
  0.4.0 dependency (GraphQL metadata + WebSocket models, unused by this
  package directly).

## 0.3.0

- Rule-based request mocking: match `JalaMockRegistry` before the inner
  client and short-circuit with canned `StreamedResponse`, timeout /
  connection errors, or delay (only when Jala is enabled).
- Edit-and-resend: `JalaHttpReplayer.replayModified` with method/URL/
  headers/body overrides.

## 0.2.0

- First release of the `package:http` adapter for Jala.
- `JalaHttpClient` — a `http.BaseClient` wrapper capturing
  request/response/error events for any `http.Client` it wraps, with
  headers redacted at capture time.
- `JalaHttp.wrap(inner)` convenience that wraps a client and registers a
  replayer for it in one call.
- `JalaHttpReplayer` — one-tap in-app replay by rebuilding a `http.Request`
  and re-issuing it through the wrapped client, tagging the new entry with
  `replayOf`.
- Response bodies are captured via a stream tee: the caller always
  receives the complete, unmodified body, while capture buffers at most
  `maxBodyBytes` of it in parallel and reports the true total transferred
  size. Cancelling the caller's subscription mid-read still completes the
  store entry with the bytes received so far.
- Image responses (`image/*` within cap) are captured as `BodyKind.image`.
- `MultipartRequest` is captured as structured `@multipart` parts (fields +
  file names/sizes, never file bytes); `StreamedRequest` bodies stay
  metadata-only.
- Upload/download progress: the request/response tees emit
  `NetworkProgressEvent` about every 64 KB (and on completion).
- `send()` checks `JalaBinding.instance.isEnabled` first and is wrapped in
  try/catch throughout, so a disabled Jala or a capture bug can never
  affect app networking.
