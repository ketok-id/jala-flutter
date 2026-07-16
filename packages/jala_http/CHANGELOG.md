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
