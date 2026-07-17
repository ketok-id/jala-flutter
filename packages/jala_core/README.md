# jala_core

Pure-Dart core for [Jala](https://github.com/ketok-id/jala-flutter), the in-app
Flutter network inspector: the captured-call model, event bus, ring-buffer
store, capture-time redaction, DevTools-style filter grammar, exporters
(cURL, Dart/Dio snippet, HAR 1.2), network throttling, and session
export/import.

**Zero Flutter dependency.** This package only depends on `dart:core` /
`dart:convert` and is tested with `dart test`, so it can be reused outside
Flutter (CLI tooling, server-side log tooling, etc.) as well as inside it.

> **Building an app?** Install [`jala`](../jala) instead — it pulls in
> this package plus `jala_ui` and gives you `Jala.initialize()` and
> `JalaOverlay` out of the box. `jala_core` is for people building client
> integrations or plugins (like `jala_dio`), or anyone who wants the model/
> store/filter/exporter primitives without any UI.
>
> **Apps:** [docs/ADOPTION.md](../../docs/ADOPTION.md). **0.x policy:**
> [docs/COMPAT.md](../../docs/COMPAT.md). Lockstep with other Jala packages
> at the same `0.5.x`.

## Main classes

| Class | Role |
|---|---|
| `JalaBinding` | Process-wide singleton wiring config, event bus, store, replay registry, mock registry, and throttle registry. Client integrations read `JalaBinding.instance` instead of taking constructor parameters. |
| `JalaReplayRegistry` / `JalaReplayer` | Connects the inspector UI's Replay action to whichever client integration can re-issue a call. |
| `JalaMockRegistry` / `JalaMockRule` | Ordered mock rules (first enabled match wins) for canned responses / failures / delays. |
| `JalaThrottleRegistry` / `JalaThrottleProfile` | Active network-condition profile (latency, jitter, bandwidth, drop rate) with presets `slow3g` / `fast3g` / `flaky` / `offline`. Active only while the binding is enabled. |
| `JalaEvent` / `JalaEventBus` | Sealed event types (HTTP request/response/error/cancel/progress, GraphQL subscription payloads, WebSocket lifecycle/frames) and the broadcast bus clients emit them into. A true no-op when Jala is disabled. |
| `JalaStore` | Ring-buffer store (default 300 HTTP entries + parallel WS connections) that correlates events into immutable `NetworkCallEntry` / `WsConnectionEntry` values, plus `importSession` / `isViewingImport`. |
| `NetworkCallEntry` / `CapturedBody` | One captured HTTP/GraphQL call (incl. `throttledBy`, `imported`, GraphQL metadata, subscription `payloads` ring) and its request/response bodies with a hard 512 KB capture cap. |
| `WsConnectionEntry` / `WsFrame` | WebSocket connection + frame timeline (direction, size, redacted text preview). |
| `JalaSessionCodec` / `JalaSession` / `JalaSessionExportOptions` | Versioned JSON session export/import (`format: "jala-session"`, v1). Export can strip bodies/images/WS previews; decode rejects oversized pastes. |
| `JalaRedactor` | Case-insensitive header redaction (`Authorization`, `Cookie`, `X-Api-Key`, etc. by default) and body pattern redaction, meant to run **at capture time** so secrets never enter the store. |
| `JalaFilter` | `JalaFilter.parse(query)` compiles a DevTools-style query into a `matches(NetworkCallEntry)` predicate (and `matchesWs` for WebSocket entries). |
| `CurlExporter` | Renders an entry as a runnable, shell-escaped `curl` command. |
| `DartSnippetExporter` | Renders an entry as a runnable `dio.request(...)` snippet. |
| `HarExporter` | Renders one call or a whole session as HAR 1.2 JSON. |
| `JalaConfig` | `enabled`, `maxEntries`, `maxBodyBytes`, `captureImageBodies`, `maxWsConnections`, `maxWsFramesPerConnection`, `maxSubscriptionPayloads`, `redactor` — passed to `JalaBinding.instance.initialize(config: ...)`. |

## Filter grammar

`JalaFilter.parse(String query)` splits the query on whitespace into terms
(AND semantics), where a leading `-` negates a term. Matching is
case-insensitive; malformed structured terms degrade to free text instead of
throwing.

| Term | Matches |
|---|---|
| `method:get` / `m:get` | HTTP method; comma list allowed (`m:get,post`) |
| `status:404` / `s:404` | Exact status code |
| `status:4xx` | Status class; also `s:error` (>= 400 or errored/cancelled) and `s:pending` |
| `host:api.example.com` / `d:` | Host; `*` wildcard allowed (`host:*.example.com`) |
| `path:/users` | Path substring |
| `type:json` / `t:json` | Response content-type substring |
| `larger-than:10k` | `responseSize` greater than n bytes (`k`/`m` suffixes supported) |
| `slower-than:500` | Duration greater than n milliseconds |
| `is:replay` | Entry is a replay of another call (`replayOf != null`) |
| `is:mocked` | Entry was served by a mock rule |
| `is:graphql` | Entry carries GraphQL operation metadata |
| `is:subscription` | `operationType == 'subscription'` |
| `is:ws` | WebSocket connection entries (`matchesWs` only) |
| `op:<name>` | GraphQL `operationName`; `*` wildcard allowed |
| `body:token` | Substring of the captured request or response body text |
| bare word | Substring of `method + " " + full URL` |
| `-<any term above>` | Negates that term |

Example: `method:get status:4xx larger-than:10k -host:*.cdn.com`.

## Usage without Flutter

```dart
import 'package:jala_core/jala_core.dart';

final config = JalaConfig(enabled: true);
JalaBinding.instance.initialize(config: config);

JalaBinding.instance.throttleRegistry.setActive(JalaThrottleProfile.slow3g);

JalaBinding.instance.bus.emit(NetworkRequestEvent(/* ... */));
// ...
final entries = JalaBinding.instance.store.entries;
final filter = JalaFilter.parse('method:post s:error');
final matches = entries.where(filter.matches);

print(CurlExporter.export(matches.first));
print(HarExporter.exportSession(entries));

// Session share — prefer headers-only outside trusted eng channels
final encoded = JalaSessionCodec.encode(
  JalaBinding.instance.store,
  options: JalaSessionExportOptions.headersOnly,
);
JalaBinding.instance.store.importSession(JalaSessionCodec.decode(encoded));
```

Security defaults (redaction, export modes): [docs/SECURITY.md](../../docs/SECURITY.md).  
Original v0.1 contract: [docs/SPEC-v0.1.md](../../docs/SPEC-v0.1.md).
