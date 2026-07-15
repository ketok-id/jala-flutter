# Track C — v0.3.0: mocking & edit-and-resend

The category-changing release. Research finding: rule-based response mocking
(Charles "Map Local", Proxyman) is the most-loved feature of desktop proxies,
and no Flutter package does it well — requests_inspector's "Stopper" is a
one-off manual intercept, not a persistent rule engine. Jala already owns the
interceptor layer, so this is a natural extension, not a rewrite.

## C1. Rule engine (`jala_core`)

- Model `JalaMockRule`:
  - `id`, `name`, `enabled`
  - Matcher: `method?` (null = any), `urlPattern` (glob on full URL, same
    wildcard semantics as the filter grammar's `host:`), optional
    `bodyContains?`
  - Action (sealed):
    - `MockResponse(statusCode, headers, body, delay?)` — short-circuit with
      a canned response
    - `MockFailure(kind: timeout|connectionError, delay?)` — simulate errors
    - `MockDelay(duration)` — pass through but add latency (poor-man's
      throttling; the full throttling feature stays on the horizon)
- `JalaMockRegistry` on the binding: ordered rule list (first match wins),
  `match(method, url, body) -> JalaMockRule?`, CRUD, `Stream<List<rule>>`
  for UI. Rules are held in memory + persisted as JSON via a pluggable
  `JalaMockStore` interface; default implementation is in-memory, and the
  facade provides a file-backed one (see C4) — jala_core stays IO-free.
- Captured entries served from a mock get `mockRuleId` set; filter grammar
  gains `is:mocked`.

## C2. Interceptor integration

- `jala_dio`: in `onRequest`, after capture, query the registry. On
  `MockResponse` -> `handler.resolve(Response(...), true)` after optional
  delay; on `MockFailure` -> `handler.reject(DioException(...))`. Response
  events emitted so the mock shows in the inspector (badged).
- `jala_http`: same short-circuit inside `send()` before delegating to the
  inner client.
- Guarantee: mocking only ever activates when `JalaBinding.isEnabled` — a
  release build with jala disabled can never serve mocks.

## C3. Mock UI (`jala_ui`)

- New "Mocks" screen reachable from the inspector AppBar (rules icon with
  active-count badge): rule list with enable toggles, add/edit/delete.
- Rule editor: method dropdown, URL pattern field (with live "matches N
  captured calls" hint powered by the store), status code, headers table,
  body editor (JSON-aware), delay slider, failure-kind selector.
- The killer entry point — **"Mock this"** on a captured call's detail
  screen: pre-fills the editor from that call (method, URL -> pattern,
  actual response as the starting body). One tap from "saw the bug" to
  "reproduce forever".
- List tiles for mocked responses show a distinct badge (e.g. ⚡ or `MOCK`
  chip) so mocked traffic is never mistaken for real.

## C4. Persistence (facade `jala`)

- `Jala.initialize(config: ..., mockStorePath: ...)` — default file-backed
  store under the app's temp/support directory (only when enabled), so rules
  survive hot restarts and app restarts during a debug session. Path
  handling lives in the facade (has Flutter), not core. No dependency on
  path_provider: accept a caller-supplied directory, and in the example app
  wire path_provider explicitly.

## C5. Edit-and-resend (builds on replay)

- Detail screen action "Edit & resend": opens a request composer pre-filled
  from the captured call — editable method, URL, headers table, body.
  "Send" issues it through the active replayer (extend `JalaReplayer` with
  `replayModified(NetworkCallEntry, {method, uri, headers, body})`, default
  implementation falls back to plain replay in old adapters).
- Sent call is captured as a new entry with `replayOf` set (existing badge
  works); redacted (masked) header values are dropped, same as replay.
- Explicitly out of scope: in-flight breakpoints (pause-and-edit). Research
  verdict: deadlock/ANR-prone in-app; needs the desktop companion.

## Tests & release

- Core: rule matching precedence, glob edge cases, registry stream, JSON
  round-trip of rules.
- Adapters: mock served + captured + badged; failure kinds produce the right
  DioException/http exception; disabled binding serves no mocks.
- UI: widget tests for rule editor prefill from an entry, `is:mocked`
  filter, mock badge.
- Live smoke test: create a rule from a captured call on a device, kill and
  relaunch the app, rule still active and serving.
- All packages -> 0.3.0 lockstep; announcement (this is the "different
  category" post: "Charles-style Map Local, inside your Flutter app").
