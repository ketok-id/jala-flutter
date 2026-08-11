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

First release. `JalaGrpcInterceptor` — a `package:grpc` `ClientInterceptor`
that captures RPCs into the shared Jala store.

- Unary RPCs: request and response messages (proto3 JSON where the generated
  type supports it, else byte metadata), call metadata, trailers, gRPC status
  code, and duration.
- Streaming RPCs: the RPC envelope (method, status, trailers, duration) plus
  request-side byte progress.
- `is:grpc` filter term; `op:` globs the method name.
- Messages are captured through `CapturedBody.captureRedacted`, so proto3
  JSON — a decoded `Map` — is redacted like any other body.

### Known limitations

Both follow from `ClientInterceptor` being a narrower hook than the
HTTP adapters' — see `docs/plans/track-g-v0.8-grpc.md` for the source-level
detail and the two escape routes.

- **Streaming response messages are not captured.** `ResponseStream` is a
  single-subscription stream whose only constructor takes a `ClientCall`
  private to the call site, so it can be neither tapped nor rebuilt.
- **Mocking and throttling do not apply to gRPC.** Both need to fabricate or
  delay a response, which requires constructing a `ResponseFuture` /
  `ResponseStream`.
