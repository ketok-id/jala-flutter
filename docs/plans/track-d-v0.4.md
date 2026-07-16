# Track D — v0.4.0: GraphQL + WebSocket

The two capture surfaces every incumbent handles badly. Research recap:
Chucker's GraphQL support lags Apollo 4; Alice's GraphQL issue sat unaddressed
for years; only requests_inspector has purpose-built GraphQL; WebSocket
frame-level inspection is effectively greenfield in Flutter.

Two new packages, born at 0.4.0: `jala_graphql`, `jala_websocket` (both names
verified free on pub.dev, 2026-07-16). All packages release in lockstep at
0.4.0. New packages need publisher assignment after first publish (user,
Admin tab) — don't forget like jala_http.

Execution order (mirrors Track B's pattern): D1 first and alone (shared core
model — everything depends on it), then D2 and D3 as parallel executors, then
D4 example/tests, then release. Coordinator pre-wires new package stubs +
workspace entries before spawning parallel executors.

## D1. Core model extensions (`jala_core`, `jala_ui` list only)

**GraphQL metadata on existing entries** (GraphQL calls ARE network calls):
- `NetworkCallEntry.operationName: String?`, `operationType: String?`
  (`query`/`mutation`/`subscription`), populated via matching new optional
  fields on `NetworkRequestEvent`.
- List tile: when `operationName != null`, title shows `operationName`
  (secondary line keeps host + path); method chip shows `operationType`
  uppercased (QUERY/MUTATION) instead of POST.

**WebSocket is a new entity, not a NetworkCallEntry.** New model in core:
- `WsConnectionEntry {id, uri, status: connecting|open|closed|error,
  openedAt, closedAt?, closeCode?, closeReason?, frameCount, frames}` where
  `frames` is a per-connection ring buffer (default 200) of
  `WsFrame {timestamp, direction: sent|received, isBinary, size, preview}`
  — preview is text capped at 4 KB (binary: metadata only), redacted via the
  existing body-pattern redactor.
- New events: `WsConnectEvent, WsFrameEvent, WsCloseEvent, WsErrorEvent`
  (extend the sealed `JalaEvent`; correlated by connection id).
- Store: a parallel `wsConnections` collection (cap: 20 connections,
  oldest-closed evicted first) + `watchWs` stream. Do NOT force both entry
  kinds into one list type in core; merging happens in the UI layer.

**Filter grammar:** `op:<name>` (operationName glob), `is:graphql`
(operationName != null), `is:ws` (only meaningful in the merged UI list —
grammar itself gains a `matchesWs(WsConnectionEntry)` for uri/status terms:
bare text, `host:`, `is:ws`, `s:error`).

## D2. `jala_websocket` (new package)

- Dep: `web_socket_channel: ^3.0.0` + `jala_core`.
- API: `JalaWebSocketChannel.wrap(WebSocketChannel channel, {Uri? uri})` —
  returns a `WebSocketChannel` whose `stream` and `sink` are teed:
  received frames → `WsFrameEvent(direction: received)`, sent →
  `direction: sent`; `sink.close()` / stream done → `WsCloseEvent` with
  code/reason; stream error → `WsErrorEvent`. Disabled binding = zero-cost
  passthrough (return the original channel untouched).
- `uri` param because `WebSocketChannel` doesn't expose its url; document.
- Tests with a fake/loopback channel (StreamChannelController): connect,
  both directions, binary metadata-only, close codes, error, ring-buffer
  overflow, disabled passthrough, redaction of frame text.

## D3. `jala_graphql` (new package)

- Bind to **`gql_exec` + `gql_link`**, NOT `graphql_flutter` — both
  graphql_flutter and ferry are built on gql links, so one adapter covers
  both ecosystems. Dep: `gql_exec`, `gql_link`, `jala_core`.
- API: `JalaGraphQLLink extends Link` — insert before the terminating
  HttpLink: `Link.from([JalaGraphQLLink(), HttpLink(...)])`.
- Capture per operation: operationName, operationType (parse from the
  document's first OperationDefinition), query text (pretty-printed source),
  variables (JSON, redacted via body patterns), response data/errors,
  duration. Emits standard request/response/error events with the D1
  GraphQL fields set, `client: 'graphql'`, url from a `uri` constructor
  param (links don't know the endpoint; document).
- Subscriptions: capture the START as an entry (operationType
  `subscription`, status pending while active) and each payload as… OUT OF
  SCOPE for v0.4 beyond the start entry + completion — payload streaming
  belongs to the WS frame model and needs jala_graphql↔jala_websocket
  coordination; note in README, revisit in v0.5.
- Double-capture note in README: if the app also wraps its HTTP transport
  with jala_dio/jala_http, the same operation appears twice (once as
  GraphQL entry, once as raw POST). Recommendation: don't wrap the
  transport used by GraphQL, or filter with `-is:graphql`/`is:graphql`.
- Tests: fake terminating link; query/mutation capture, variables
  redaction, error result, network error, disabled passthrough, operation
  parsing edge cases (anonymous operation, multiple definitions).

## D4. UI (`jala_ui`)

- **Merged list**: inspector list interleaves NetworkCallEntry +
  WsConnectionEntry chronologically (combine `watch` + `watchWs`). WS tile:
  `WS` chip, uri, live status color (connecting=pending style, open=blue,
  closed=grey, error=red), frame count + last-activity time, updating live.
- **WS connection detail screen**: connection info header (uri, status,
  open/close times, close code/reason) + frame timeline (direction arrow,
  relative timestamp, size; tap a text frame → body view, reusing the JSON
  tree when the frame parses as JSON). In-frame-list filter box (substring).
- **GraphQL detail**: Request tab for `is:graphql` entries becomes two
  sections — Query (monospace, selectable) and Variables (JSON tree).
- Actions on WS entries: copy frame text, copy connection summary as JSON
  (no cURL/HAR — not representable; hide those buttons for WS).
- Widget tests: merged-list ordering + live status, ws detail frame tap,
  graphql request panes, `is:ws`/`is:graphql`/`op:` filtering through the
  real filter engine.

## D5. Example, smoke, release

- Example rig: new section "realtime" — WebSocket demo against
  `wss://echo.websocket.events` (public echo; send/receive a few frames,
  then close), GraphQL demo against `https://countries.trevorblades.com/`
  (public, CORS-enabled; one query with variables). Integration smoke test
  per the established `integration_test/` pattern (store-level asserts).
- Live smoke on simulator or device: ws connect → frames → close renders;
  graphql operation shows name + panes; filters work.
- Release: lockstep 0.4.0 everywhere (including deps `jala_core: ^0.4.0`),
  CHANGELOGs, `--fatal-infos` clean (CI's bar), dry-run ×7, publish order:
  jala_core → jala_dio/jala_http/jala_graphql/jala_websocket/jala_ui →
  jala. README: comparison table rows for GraphQL/WebSocket (both "No"
  for alice/chucker_flutter — cite carefully; requests_inspector has both
  but isn't in our table), roadmap section refresh.
- Reminder for user afterwards: assign jala_graphql + jala_websocket to
  the ketok.id publisher.

## Explicitly out of scope (v0.4)

- GraphQL subscription payload streaming (needs WS/GraphQL coordination).
- Frame-level mocking for WS; GraphQL-aware mock matching (rules match the
  underlying POST today — works, just not operation-aware). Both → v0.5
  candidates depending on feedback.
- HAR export for WS (no standard exists).
