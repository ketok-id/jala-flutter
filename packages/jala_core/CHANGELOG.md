## 0.5.1

- Pub metadata: `homepage`, `issue_tracker`, and description now mentions
  throttling + session export/import (docs-only; no API changes).

## 0.5.0

- Network throttling model: `JalaThrottleProfile` (latency/jitter/bandwidth/
  drop rate) with const presets `slow3g` / `fast3g` / `flaky` / `offline`,
  and `JalaThrottleRegistry` on the binding (`activeProfile`, host-pattern
  glob, `watch`, `shouldDrop` / `latencyFor` / `paceFor`). Active only while
  the binding is enabled.
- Session share codec: `JalaSessionCodec.encode`/`decode` with a versioned
  JSON envelope (`jala-session` marker, v1). Round-trips `NetworkCallEntry`
  (incl. captured bodies) and `WsConnectionEntry` + frames; defensive
  `JalaSessionFormatException` on malformed input.
- `JalaStore.importSession` (replace/append) + `isViewingImport`; imported
  entries are tagged `imported: true`.
- GraphQL subscription payload ring: `NetworkSubscriptionPayloadEvent`,
  `NetworkCallEntry.payloads` / `payloadCount`, capped by
  `JalaConfig.maxSubscriptionPayloads` (default 50; wired through
  `JalaBinding.initialize`).
- Filter grammar: `is:subscription`.

## 0.4.0

- GraphQL metadata on the existing call model: `NetworkCallEntry`/
  `NetworkRequestEvent` gain `operationName`/`operationType`
  (`query`/`mutation`/`subscription`) — GraphQL calls are still
  `NetworkCallEntry`s, just tagged.
- New WebSocket entity: `WsConnectionEntry` (id, uri, status, open/close
  times, close code/reason, frame count) with a per-connection `WsFrame`
  ring buffer (default 200 frames; direction, binary flag, size, redacted
  text preview capped at 4 KB). New events: `WsConnectEvent`,
  `WsOpenEvent`, `WsFrameEvent`, `WsCloseEvent`, `WsErrorEvent`.
- `JalaStore` gains a parallel `wsConnections` collection (cap 20,
  oldest-closed evicted first) and a `watchWs` stream, independent of the
  existing `entries`/`watch` — WebSocket connections are never merged into
  `NetworkCallEntry` at the core layer.
- Filter grammar: `op:<name>` (operationName glob), `is:graphql`
  (`operationName != null`), `is:ws`, and a new `matchesWs` entry point for
  matching `WsConnectionEntry` (bare text, `host:`/`d:`, `status:`/`s:`,
  `is:ws`).

## 0.3.0

- Mock rule engine: `JalaMockRule`, sealed `MockAction`
  (`MockResponse` / `MockFailure` / `MockDelay`), `JalaMockRegistry`,
  and pluggable `JalaMockStore` (in-memory default).
- URL glob helper `globMatches` for full-URL pattern matching.
- `NetworkCallEntry.mockRuleId` / request-event field for mocked calls.
- Filter grammar: `is:mocked`.
- Replay API: `JalaReplayer.replayModified` + registry helper for
  edit-and-resend.

## 0.2.0

- Image body capture: `BodyKind.image` plus `CapturedBody.bytes` /
  `CapturedBody.captureBytes`, gated by `JalaConfig.captureImageBodies`
  (default true) and `maxBodyBytes`.
- Multipart model: `JalaMultipartPart` and `CapturedBodyMultipart` with the
  `{"@multipart": [...]}` JSON convention for structured part metadata.
- Progress events: `NetworkProgressEvent` (sent/received byte counters) and
  `NetworkCallEntry.progress` updated live by the store.
- cURL exporter emits `-F` flags with filename placeholders for multipart
  bodies (never real file contents); image bodies export as size/mime
  placeholders.

## 0.1.1

- Add pub.dev topics.

## 0.1.0

- Initial release: `NetworkCallEntry` / `CapturedBody` models with a 512 KB
  per-body cap and safe handling of binary, oversize, and malformed-UTF8
  data.
- `JalaEventBus` + `JalaStore` ring buffer (default 300 entries)
  correlating request/response/error/cancel events by call id, evicting
  oldest completed entries first.
- `JalaRedactor` — case-insensitive header redaction (`Authorization`,
  `Cookie`, `X-Api-Key`, etc. by default) and body pattern redaction,
  designed to run at capture time so secrets never enter the store.
- `JalaFilter` DevTools-style query grammar: `method:`/`m:`, `status:`/`s:`,
  `host:`/`d:`, `path:`, `type:`/`t:`, `larger-than:`, `slower-than:`,
  `is:replay`, `body:`, bare text, and `-` negation.
- `CurlExporter`, `DartSnippetExporter`, and `HarExporter` (HAR 1.2, single
  call or whole session).
- `JalaBinding` process-wide singleton and `JalaReplayRegistry` so client
  integrations (e.g. `jala_dio`) can wire capture and replay.
- `JalaConfig` with `enabled`, `maxEntries`, `maxBodyBytes`, and `redactor`.
