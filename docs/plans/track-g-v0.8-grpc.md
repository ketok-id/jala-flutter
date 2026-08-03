# Track G — v0.8.0: `jala_grpc`

Next capture-surface expansion. gRPC / gRPC-web is effectively greenfield in
Flutter — the same gap GraphQL and WebSocket were before Track D.

One new package, born at 0.8.0: `jala_grpc` (verify the name is free on
pub.dev before starting). Ships alongside the capture-integrity hardening
already staged under `## Unreleased`; all packages release in lockstep at
0.8.0. New package needs publisher assignment to `ketok.id` after first
publish (user, Admin tab) — don't forget like `jala_http`.

Execution order mirrors Track D: **G1 core alone** (shared model — everything
depends on it) → **G2 package + G3 UI as parallel executors** → **G4
example/smoke/release**. Coordinator pre-wires the package stub and the
workspace entry before spawning parallel executors.

## What the `grpc` API actually allows (verified against grpc 5.1.0)

Read this before scoping anything. The sanctioned extension point is
`ClientInterceptor`, and it is **narrower than the other three adapters'**.
These are source-verified facts, not assumptions:

```dart
abstract class ClientInterceptor {
  ResponseFuture<R> interceptUnary<Q, R>(
      ClientMethod<Q, R> method, Q request, CallOptions options,
      ClientUnaryInvoker<Q, R> invoker);
  ResponseStream<R> interceptStreaming<Q, R>(
      ClientMethod<Q, R> method, Stream<Q> requests, CallOptions options,
      ClientStreamingInvoker<Q, R> invoker);
}
```

- ✅ **No-op when disabled is free.** Both methods default to
  `return invoker(...)`; the disabled path is literally that one line.
- ✅ **Unary capture is complete.** `interceptUnary` returns a
  `ResponseFuture<R>` — a `Future`, so extra listeners are free. Attach
  side-effect listeners to it and to its `headers` / `trailers` futures,
  then return **the same object** so the app keeps `cancel()` and identity.
- ✅ **Request messages are capturable on both call kinds.** We construct the
  `Stream<Q>` handed to `invoker`, so a `.map` tap is ours to add.
- ✅ **Method identity** comes from `ClientMethod.path`
  (`/package.Service/Method`) — split it for service + method.
- ⚠️ **Streaming *response* messages are NOT capturable via the
  interceptor.** `ResponseStream<R>` is a single-subscription `StreamView`
  and its only constructor is `ResponseStream(ClientCall<dynamic, R>)` —
  the `ClientCall` is private to the call site. We can neither tap the
  stream (that steals the app's subscription) nor rebuild an equivalent one.
- ⚠️ **Mocking, throttle latency and drops do NOT work for gRPC.** All three
  need to fabricate or delay a response, which means constructing a
  `ResponseFuture` / `ResponseStream` — impossible for the same reason.

**Scope consequence: `jala_grpc` v1 is capture-only.** It does not
participate in `JalaMockRegistry` or `JalaThrottleRegistry`. Say so in the
README and in `docs/ADOPTION.md`'s throttle matrix rather than letting users
discover it — that failure mode is exactly what the 0.8.0 hardening fixed
elsewhere (Dio's bandwidth caps silently applied to one response type for
two releases).

If full streaming capture turns out to be a must-have, there are two routes,
both out of scope here and to be decided before G2 starts:

1. **Upstream.** PR a response-tap hook (or a public `ClientCall.response`
   override point) to `grpc-dart`. Cleanest, slowest.
2. **Channel subclass.** `ClientCall.response` *is* an overridable getter
   (`call.dart:489`), and both `ResponseFuture` and `ResponseStream` read it
   at construction — so a `ClientChannel` whose `createCall` returns a
   `ClientCall` subclass would see every message. But dispatching that call
   requires `getConnection()` / `ClientConnection.dispatchCall`, and
   `ClientConnection` is **not exported** from `package:grpc`. Fragile,
   version-coupled, and it changes the host's channel construction rather
   than adding to an interceptor list. Prototype before committing.

## G1. Core model extensions (`jala_core`) — ✅ DONE

gRPC calls **are** network calls — extend `NetworkCallEntry`, don't add a
parallel entity (the WS precedent does not apply; a gRPC RPC has one request
and N responses, which is the *GraphQL subscription* shape).

As shipped — three new fields, everything else reused:

- `NetworkCallEntry.rpcKind: String?` (`unary` / `serverStreaming` /
  `clientStreaming` / `bidi`), from a matching field on
  `NetworkRequestEvent`.
- `NetworkCallEntry.grpcStatusCode: int?`, from `NetworkResponseEvent` and
  `NetworkErrorEvent`. Separate from `statusCode` because a failed RPC rides
  on an HTTP 200 — the same convention `jala_graphql` already uses.
- `NetworkCallEntry.trailers: Map<String, String>` (default empty).
- Reused unchanged: `operationName` (= method name), `statusMessage` (= gRPC
  status message), `client: 'grpc'`, and the `payloads` / `payloadCount`
  ring buffer built for GraphQL subscriptions — no new collection, no new
  cap, and the detail UI already renders it. `grpcStatusMessage` was dropped
  from the original sketch as redundant with `statusMessage`.
- Filter: `is:grpc` (`client == 'grpc'`); `op:` globs `operationName` for
  free. **`s:error` also matches a non-zero `grpcStatusCode`** — without
  that branch every NOT_FOUND / PERMISSION_DENIED files under "success",
  since the HTTP status is 200.

**Open question 3 answered: trailers are a separate field, not merged into
`responseHeaders`.** Merging would render `grpc-status` as an ordinary HTTP
header in the headers table and in HAR exports, misreporting what the server
sent.

Covered by 12 tests across `jala_store_test`, `jala_filter_test` and
`jala_session_codec_test` (store wiring, error-event field preservation,
payload ring reuse, filter terms, session round-trip, and that a non-gRPC
entry omits all three fields from its JSON).

## G2. `jala_grpc` (new package) — ✅ DONE (capture-only, per Q1 below)

- Deps: `grpc: ^5.1.0` + `jala_core`. Pure Dart, no Flutter.
- API: `JalaGrpcInterceptor()`, added to a generated client's
  `interceptors:` list. Document that it must be constructed per client and
  that **`Client($channel, interceptors: [...])` is the only supported wiring**
  — the deprecated `$createCall` path bypasses interceptors entirely.
- Unary: emit `NetworkRequestEvent` before `invoker`, then attach listeners
  for value / error / `headers` / `trailers`, and return the invoker's
  `ResponseFuture` untouched.
- Streaming: tap the request stream for messages and count; emit the
  envelope on `trailers` completion. Response messages are not captured —
  see the constraint above; surface that honestly in the UI (G3), not as a
  silently empty payload list.
- Message capture: `toProto3Json()` where the generated type offers it, else
  byte-length metadata via `requestSerializer`. **Capture through
  `CapturedBody.captureRedacted`, never `CapturedBody.capture`** — a
  proto3-JSON message is a decoded `Map`, exactly the shape that bypassed
  redaction before 0.8.0.
- Errors: `GrpcError` → `NetworkErrorEvent` with `grpcStatusCode`;
  `GrpcError.deadlineExceeded` and cancellation map to the existing
  cancelled/error statuses.
- Standard invariants apply unchanged: no-op when disabled, capture in
  `try`/`catch`, forward exactly once, hard body caps.

Tests: a fake `ClientInterceptor` harness driving `interceptUnary` /
`interceptStreaming` with a stub invoker (no real HTTP/2). Cover unary
success/error/cancel, streaming request messages, trailers → status,
disabled passthrough returns the invoker's object identically, redaction of
a proto3-JSON message, and capture failure never breaking the call.

## G3. UI (`jala_ui`) — ✅ DONE

- List tile: gRPC entries show `service/method` as the title and an
  `rpcKind` chip instead of the HTTP method chip (every RPC is a POST,
  which tells a developer nothing); status shows the gRPC code name
  (`NOT_FOUND`, not `200`).
- `JalaTheme.statusColorFor` reads `grpcStatusCode` before `statusCode` —
  a gRPC failure rides on an HTTP 200, so colouring by status alone painted
  every `NOT_FOUND` green. Same class of bug as the `s:error` filter gap
  found in G1.
- Detail: trailers render as their own section rather than merged into the
  headers table, and a streaming RPC shows an explicit "response messages
  are not captured for streaming RPCs" note in place of the body, so an
  empty section never reads as "the server sent nothing".
- `gRPC` quick-filter chip alongside GraphQL/WS.

**Layering note:** the gRPC status-name table lives in `jala_core`
(`JalaGrpcStatus`), not `jala_grpc` — `jala_ui` renders it and adapters
never depend on the UI nor it on them. `jala_grpc` uses the same table for
its error messages.

Covered by 8 widget tests across `jala_call_list_tile_test` and
`jala_call_detail_screen_test`, including a regression guard that a failed
RPC is not coloured the same as a successful one, and that a non-gRPC entry
grows no trailers section.

## G4. Example, smoke, release

- `examples/jala_example`: a gRPC panel driven by a stub in-process
  server or a canned fake channel (no network dependency in CI).
- On-device smoke per the standing rule.
- Release: lockstep 0.8.0 across all eight packages, seven existing
  CHANGELOGs get their `## Unreleased` heading retitled, `docs/COMPAT.md`
  and `docs/ROADMAP.md` updated, `dart pub publish --dry-run` clean.

## Open questions to settle before G2

1. ~~Streaming response capture: accept the v1 limitation, or take the
   upstream / channel-subclass route?~~ **Answered: accept it.** G2 shipped
   capture-only. The channel-subclass route was re-confirmed unviable while
   building the test harness — `ClientChannelBase` and `ClientConnection`
   are not exported from `package:grpc`, so a wrapping channel cannot
   dispatch its own `ClientCall` subclass. Revisit only via upstream.
2. gRPC-web: `GrpcWebClientChannel` uses the same `Client` interceptor
   path, so it should work unchanged — **still unverified**, and the one
   claim in the README that rests on reasoning rather than a test.
3. ~~Trailers in `responseHeaders`: merged, or separate?~~ **Answered in
   G1: separate field.**
