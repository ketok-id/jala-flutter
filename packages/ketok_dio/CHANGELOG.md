## 0.1.0

- `KetokDioInterceptor` capturing request/response/error/cancel events for
  any `Dio` instance, with headers redacted at capture time.
- `KetokDio.attach(dio)` convenience that adds the interceptor and
  registers a replayer for `dio` in one call.
- `KetokDioReplayer` — one-tap in-app replay by rebuilding
  `RequestOptions` and re-issuing via `dio.fetch`, tagging the new entry
  with `replayOf`.
- `FormData` fields and file names/sizes are summarized without ever
  reading file bytes; `ResponseType.stream`/`bytes` responses are captured
  as metadata only.
- Every interceptor hook checks `KetokBinding.instance.isEnabled` first and
  is wrapped in try/catch, so a disabled Ketok or a capture bug can never
  affect app networking.
