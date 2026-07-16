## 0.2.0

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
  size.
- `MultipartRequest` fields and file names/sizes are summarized without
  ever reading file bytes; `StreamedRequest` bodies are captured as
  metadata only (Jala never consumes a caller-driven upload sink).
- `send()` checks `JalaBinding.instance.isEnabled` first and is wrapped in
  try/catch throughout, so a disabled Jala or a capture bug can never
  affect app networking.
