## 0.8.1 — 2026-08-11

- Lockstep release. No changes in this package; see the `jala` and
  `jala_ui` changelogs for the Android input/back fixes and the new
  file-backed export destination.

## 0.8.0 — 2026-08-03

### Fixed

- **Body redaction now covers every captured body shape.** New
  `CapturedBody.captureRedacted` runs `JalaRedactor.redactBody` over the
  text form a capture actually retains — including already-decoded
  `Map`/`List` bodies, which are encoded to JSON and redacted first.
  Previously each adapter decided for itself when to redact and only
  handled bodies that were already `String`, so the most common shapes in
  the ecosystem bypassed redaction entirely. Adapters must use this rather
  than `CapturedBody.capture` for anything off the wire.
- `CapturedBody.captureRedacted` takes `knownTruncated` for callers that
  already cut a body short upstream, replacing the "pass a cap one byte
  below the buffer length" trick — which redaction, being free to shrink
  the text, could silently defeat and report a truncated body as complete.
- `JalaRedactor.defaultJsonSecretValues` also matches a secret value that
  runs to the end of the text, so a body captured over the size cap does
  not leave the visible prefix of a token unmasked.
- `HarExporter` builds `queryString` from the raw query rather than
  `Uri.queryParameters`, which collapses repeated keys — `?tag=a&tag=b`
  exported as a single `tag=b`, losing a parameter the app really sent.
- `DartSnippetExporter` marks masked header values with a trailing comment
  instead of emitting them as ordinary string literals, and gained the
  `redacted` flag `CurlExporter` already had (false drops masked headers).
- `JalaReplayRegistry.replay` throws the new `JalaReplayException` for an
  entry whose request body hit the capture cap. Replay used to resend
  whatever prefix survived, silently delivering a corrupt payload to a live
  endpoint. `replayModified` with an explicit body is unaffected — that is
  the developer supplying the real content.

### Added

- gRPC model support (Track G, G1): `NetworkCallEntry.rpcKind`,
  `grpcStatusCode` and `trailers`, populated from matching fields on
  `NetworkRequestEvent` / `NetworkResponseEvent` / `NetworkErrorEvent`.
  `grpcStatusCode` is separate from `statusCode` because a failed RPC rides
  on an HTTP 200, and `JalaFilter`'s `s:error` accounts for that — without
  it every NOT_FOUND would file under "success". New `is:grpc` term;
  streaming messages reuse the existing subscription payload ring buffer.
- `JalaGrpcStatus` — canonical gRPC status codes and names. Lives here, not
  in `jala_grpc`, because `jala_ui` renders the name and adapters never
  depend on the UI (nor it on them).
- `JalaReplayException` and `NetworkCallEntry.replayBlockedReason` (via the
  `JalaReplayability` extension).
- `parseQueryParams` / `JalaQueryParam`, moved here from `jala_ui` so the
  detail screen and the HAR exporter share one wire-faithful parser.

## 0.7.0

- Redaction now covers URLs: `JalaRedactor.redactUri` masks the values of
  sensitive query parameters (`defaultRedactedQueryParams` — the
  `defaultFormSecretValues` name list plus presigned-URL `signature` /
  `X-Amz-*` params), configurable via the new `redactedQueryParams`
  constructor argument. A token in a URL is as sensitive as one in a header
  and more exposed, since the full URL appears on the call list, in the
  detail screen, and in every cURL / HAR / Dart-snippet export.
  The raw query is rewritten segment by segment, so repeated keys,
  valueless params (`?q&page=1`) and existing percent-encoding survive
  untouched. Empty values (`?token=`) are left alone.
- `JalaRedactor.stripMaskedQueryParams` removes masked parameters from a
  URL, for replayers that must not resend `••••••` as a credential.

## 0.6.0

- Call diff model: `JalaJsonDiff.diff` (structural recursive `DiffNode` —
  added/removed/changed/unchanged) and `JalaEntryDiff.of` (status, headers
  case-insensitively, request/response JSON bodies).
- Import codecs: `JalaCurlCodec.decode` → `ImportedRequest` (method, URI,
  headers, body; shell quotes, `-H`/`-d`/`-X`/`-u`, defaults POST when data
  present); `JalaHarCodec.decode` → `JalaSession` of `imported: true`
  entries. Failures are typed (`JalaImportFormatException` /
  `JalaSessionFormatException`), never crashes.

## 0.5.3

- Security: expanded default redacted headers (CSRF, session, AWS STS, …).
- Security: default body redaction for common JSON/form secret keys
  (`password`, `access_token`, `api_key`, …); opt out via
  `includeDefaultBodyPatterns: false`.
- Session export: `JalaSessionExportOptions` (full / noBodies / headersOnly /
  stripImages).
- Session import: reject pastes larger than 8 MiB
  (`JalaSessionCodec.defaultMaxDecodeChars`).

## 0.5.2

- Lockstep release; no functional changes.

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
