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
