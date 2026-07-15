# Ketok v0.1 — Network Inspector Specification (BINDING)

This document is the implementation contract for Ketok v0.1. Implementor agents MUST
follow the APIs, names, and behaviors here. If something is ambiguous, choose the
simplest option consistent with the Principles and leave a `// SPEC-NOTE:` comment.

## Positioning (from competitive research, 2026-07)

Ketok v0.1 must beat Alice/Chucker on these verified gaps:

1. **Structured filter query bar** (Chrome-DevTools style) — absent in Alice (issue #255) and Chucker (#286).
2. **Copy as cURL AND copy as Dart Dio snippet** — Alice has neither (#232); the Dart snippet is unique in the ecosystem.
3. **One-tap in-app request replay** — no Flutter package has it.
4. **HAR 1.2 export** (single call + whole session) — Chucker has it, no maintained Flutter package does.
5. **Production safety by default** — redaction ON by default, `enabled:false` = true no-op. Alice's weakest point (#174).
6. **All 6 platforms** (android/ios/macos/windows/linux/web) — Alice is mobile-only (#243).
7. **Large-body safety** — hard caps on captured body size (Chucker has open OOM issues #1068).

Deferred (do NOT build in v0.1): mocking/map-local, breakpoints, throttling,
request compose/edit, GraphQL/WebSocket, persistence, global body-search index,
notifications, shake-to-open.

## Toolchain

- Flutter 3.41 / Dart 3.11, stable channel. Use **pub workspaces** (root pubspec with
  `workspace:` list; each package has `resolution: workspace`).
- Lints: `package:flutter_lints` (UI/facade/dio/example) and `package:lints/recommended`
  (core). One shared `analysis_options.yaml` at root; packages include it.
- Every package: `dart analyze` clean, tests pass with `flutter test` (or `dart test` for core).

## Repository layout

```
ketok_dev_flutter/
├── pubspec.yaml                 # workspace root (name: ketok_workspace)
├── analysis_options.yaml
├── docs/SPEC-v0.1.md            # this file
├── packages/
│   ├── ketok_core/              # pure Dart, NO Flutter dependency
│   ├── ketok_dio/               # depends: ketok_core, dio
│   ├── ketok_ui/                # depends: ketok_core, flutter
│   └── ketok/                   # facade; depends: ketok_core, ketok_ui, flutter
└── examples/
    └── ketok_example/           # flutter app; depends: ketok, ketok_dio, dio
```

Path dependencies between packages (publish_to: none is NOT set — these will be
published; use normal `dependencies:` with workspace resolution).
All package versions: `0.1.0`. Dart SDK constraint `^3.11.0`.

---

## Package: ketok_core (pure Dart)

`lib/ketok_core.dart` exports everything below from `lib/src/...`.

### Models (`src/model/`)

```dart
/// Immutable. One captured network call, materialized from events.
class NetworkCallEntry {
  final String id;                     // uuid-ish; use monotonic counter + random suffix
  final DateTime startTime;
  final String method;                 // uppercase
  final Uri uri;
  final Map<String, String> requestHeaders;   // ALREADY redacted at capture time
  final CapturedBody requestBody;
  final int? statusCode;               // null while pending
  final String? statusMessage;
  final Map<String, String> responseHeaders;  // redacted
  final CapturedBody responseBody;
  final Duration? duration;            // null while pending
  final int? requestSize;              // bytes, best-effort
  final int? responseSize;
  final KetokCallStatus status;        // pending | success | error | cancelled
  final String? errorMessage;
  final String? replayOf;              // id of original call if this is a replay
  final String client;                 // e.g. 'dio'
  // copyWith(...)
}

enum KetokCallStatus { pending, success, error, cancelled }

/// Body capture with hard size cap. Never throws on binary data.
class CapturedBody {
  final BodyKind kind;                 // none | text | json | bytes | truncated | stream
  final String? text;                  // decoded text/json (possibly truncated)
  final int? originalSize;             // bytes if known
  final bool truncated;
  final String? contentType;
  static const int defaultMaxBytes = 512 * 1024; // 512 KB cap per body
  // factory CapturedBody.capture(dynamic data, {String? contentType, int maxBytes})
  //   - String -> text/json (json if contentType contains 'json' or parses as JSON)
  //   - List<int>/bytes -> if contentType is texty, decode utf8 (malformed: allow);
  //     else kind=bytes with originalSize only (do NOT keep raw bytes over maxBytes)
  //   - Map/List -> jsonEncode -> json
  //   - null -> none
  //   - Stream -> kind=stream, metadata only
}
```

### Events (`src/event/`)

```dart
sealed class KetokEvent { final String callId; final DateTime timestamp; }
class NetworkRequestEvent extends KetokEvent { /* method, uri, headers, body, size, client */ }
class NetworkResponseEvent extends KetokEvent { /* statusCode, statusMessage, headers, body, size, duration */ }
class NetworkErrorEvent extends KetokEvent { /* errorMessage, statusCode?, headers?, body?, duration */ }
class NetworkCancelEvent extends KetokEvent { }
```

`KetokEventBus`: broadcast `Stream<KetokEvent> get events`, `void emit(KetokEvent e)`.
Synchronous no-op (drop event, zero allocation beyond the call) when `Ketok` disabled —
bus takes a `bool Function() isEnabled` check.

### Store (`src/store/`)

```dart
class KetokStore {
  KetokStore({required KetokEventBus bus, int maxEntries = 300});
  List<NetworkCallEntry> get entries;          // newest first
  Stream<List<NetworkCallEntry>> get watch;    // emits on every change
  NetworkCallEntry? byId(String id);
  void clear();
}
```

Ring buffer: when over `maxEntries`, evict oldest **completed** entries first,
then oldest pending. Correlates request/response/error events by `callId` into
immutable entries (replace entry via copyWith). Must be safe if a response event
arrives for an evicted/unknown id (ignore).

### Redaction (`src/redact/`)

```dart
class KetokRedactor {
  KetokRedactor({Set<String> redactedHeaders = defaultRedactedHeaders,
                 List<Pattern> redactedBodyPatterns = const []});
  static const defaultRedactedHeaders = {
    'authorization', 'proxy-authorization', 'cookie', 'set-cookie',
    'x-api-key', 'x-auth-token', 'api-key',
  };
  Map<String, String> redactHeaders(Map<String, String> headers); // case-insensitive match -> value '••••••'
  String redactBody(String body); // replace pattern matches with '••••••'
}
```

Redaction happens **at capture time** in the interceptor (values never enter the store).

### Filter engine (`src/filter/`)

DevTools-style grammar. `KetokFilter.parse(String query)` -> `KetokFilter` with
`bool matches(NetworkCallEntry e)`. Space-separated terms, AND semantics,
`-` prefix negates a term. Case-insensitive. Malformed terms degrade to free-text.

| term | matches |
|---|---|
| `method:get` or `m:get` | HTTP method (comma list allowed: `m:get,post`) |
| `status:404` / `s:404` | exact code |
| `status:4xx` | status class; also `s:error` (>=400 or error/cancelled), `s:pending` |
| `host:api.example.com` / `d:` | host; `*` wildcard allowed (`host:*.example.com`) |
| `path:/users` | path substring |
| `type:json` / `t:json` | response content-type substring |
| `larger-than:10k` | responseSize > n (`k`/`m` suffixes, bytes otherwise) |
| `slower-than:500` | duration > n ms |
| `is:replay` | replayOf != null |
| `body:token` | substring in captured request or response body text |
| bare word | substring of method + full URL |

### Exporters (`src/export/`)

- `CurlExporter.export(NetworkCallEntry, {bool redacted = true})` -> `curl -X POST 'url' -H '...' -d '...'`
  (multiline with `\` continuations; single-quote escaping; `--compressed` when accept-encoding gzip).
- `DartSnippetExporter.export(entry)` -> runnable `dio` snippet:
  ```dart
  final dio = Dio();
  final response = await dio.request('https://...',
    options: Options(method: 'POST', headers: {...}), data: {...});
  ```
- `HarExporter.exportSession(List<NetworkCallEntry>)` / `exportCall(entry)` -> HAR 1.2
  JSON string (creator `{"name":"ketok","version":"0.1.0"}`); omit timings sub-phases we
  don't have (use -1 per HAR spec), include startedDateTime, time, request/response
  headers, bodies as text where captured.

### Config (`src/config.dart`)

```dart
class KetokConfig {
  final bool enabled;                  // facade defaults this to kDebugMode
  final int maxEntries;                // default 300
  final int maxBodyBytes;              // default 512*1024
  final KetokRedactor redactor;
}
```

### Core tests (high value, near-full coverage)

store correlation/eviction, filter grammar (every term + negation + combos),
CapturedBody (json/text/bytes/oversize/malformed-utf8/stream), redactor
(case-insensitivity, defaults), cURL escaping (quotes in body, unicode),
HAR shape validated by decoding JSON and asserting required fields.

---

## Package: ketok_dio

```dart
class KetokDioInterceptor extends Interceptor {
  KetokDioInterceptor();  // reads global Ketok bindings via KetokBinding.instance (core)
}
```

- On attach to a `Dio`, the interceptor also registers that Dio instance with
  `KetokReplayRegistry` (core holds the registry interface; ketok_dio implements
  replay by `dio.fetch(rebuiltRequestOptions)`), so the UI can trigger
  `KetokReplay.replay(entryId)`. Replayed calls flow through interceptors again
  and are captured as new entries with `replayOf` set.
- Zero-cost when disabled: first line of each hook checks enabled flag and forwards.
- Capture: method, uri, headers (redacted), body via `CapturedBody.capture`,
  FormData -> summarize fields + file names/sizes (never read file bytes),
  `ResponseType.stream`/`bytes` -> metadata only, duration measured via stopwatch
  keyed in `RequestOptions.extra['ketok_start']`, response headers flattened
  (multi-value joined with ', ').
- Handles: onRequest, onResponse, onError (DioException types incl. cancel ->
  NetworkCancelEvent), and must never throw (wrap in try/catch; a logging bug
  must not break the app's networking).
- Tests: use `dio` with a mock `HttpClientAdapter` to simulate success/error/
  cancel/binary/large bodies; assert emitted entries and replay behavior.

## Package: ketok_ui

Flutter widgets. Own Navigator (do not touch host app navigation), own explicit
`KetokTheme` (light/dark/system — never inherit host Theme). Material 3.

- `KetokInspectorScreen` — root: filter bar + call list + app bar actions
  (clear, export session as HAR via share/copy, theme toggle).
  - Filter bar: TextField wired to `KetokFilter.parse`, with a hint showing grammar
    and a help popover listing terms. Live filtering.
  - List tile: method chip, status color (pending spinner / 2xx green / 3xx blue /
    4xx orange / 5xx+error red), path (host as secondary), duration, size,
    replay badge when `replayOf != null`.
- `KetokCallDetailScreen` — tabs: Overview (url, timing, sizes, status),
  Request (headers table + body), Response (headers + body).
  - Body view by kind: collapsible pretty-JSON tree with in-body search,
    image preview (content-type image/*, from re-request? NO — v0.1: only if bytes
    kept under cap; otherwise placeholder), plain text (selectable), and
    "binary/too large (n bytes) — metadata only" fallback.
  - Actions: Copy body, Copy cURL, Copy Dart snippet, Export HAR (this call),
    **Replay** button (disabled with tooltip if no replayer registered).
- `KetokOverlayButton` — draggable floating bubble (snaps to edges, shows badge
  with pending/error count), opens inspector via `Ketok.open()`.
- Uses only `KetokStore.watch` streams; no business logic in widgets beyond display.
- Widget tests: list renders + live-filters entries; detail shows redacted header;
  JSON viewer expands nodes; copy-cURL puts expected string on clipboard.

## Package: ketok (facade)

```dart
Ketok.initialize({KetokConfig? config});        // idempotent; wires bus+store+binding
Ketok.open();                                   // opens inspector (own navigator overlay)
Ketok.close();
Ketok.store / Ketok.bus / Ketok.isEnabled       // accessors for plugins
KetokOverlay(child: app)                        // inserts bubble + inspector host above app
```

Default `enabled: kDebugMode`. When disabled: `KetokOverlay` returns `child`
directly, interceptor no-ops. README: hero section leads with production-safety +
replay + filter grammar (the differentiators), comparison table vs Alice/Chucker.

## Example app (`examples/ketok_example`)

Buttons firing against `https://httpbin.org` (and jsonplaceholder as backup):
GET json, POST json, 404, 500, slow (delay/3), redirect, image (png), large
response (~1MB to prove truncation), gzip, multipart upload, cancelled request,
error (bad host). Uses `KetokOverlay` + `KetokDioInterceptor`. This is the manual
QA rig.

## Definition of done (v0.1)

1. `dart analyze` clean at workspace root; all package tests green.
2. Example app builds for at least macOS + iOS sim (CI-less for now; verified locally).
3. Filter grammar, cURL, Dart snippet, HAR, replay, redaction all covered by tests.
4. READMEs in each package; root README with the comparison table.
