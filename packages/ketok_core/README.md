# ketok_core

Pure-Dart core for [Ketok](https://github.com/setilanaji/ketok), the in-app
Flutter network inspector: the captured-call model, event bus, ring-buffer
store, capture-time redaction, DevTools-style filter grammar, and exporters
(cURL, Dart/Dio snippet, HAR 1.2).

**Zero Flutter dependency.** This package only depends on `dart:core` /
`dart:convert` and is tested with `dart test`, so it can be reused outside
Flutter (CLI tooling, server-side log tooling, etc.) as well as inside it.

> **Building an app?** Install [`ketok`](../ketok) instead — it pulls in
> this package plus `ketok_ui` and gives you `Ketok.initialize()` and
> `KetokOverlay` out of the box. `ketok_core` is for people building client
> integrations or plugins (like `ketok_dio`), or anyone who wants the model/
> store/filter/exporter primitives without any UI.

## Main classes

| Class | Role |
|---|---|
| `KetokBinding` | Process-wide singleton wiring config, event bus, store, and replay registry. Client integrations read `KetokBinding.instance` instead of taking constructor parameters. |
| `KetokReplayRegistry` / `KetokReplayer` | Connects the inspector UI's Replay action to whichever client integration can re-issue a call. |
| `KetokEvent` / `KetokEventBus` | Sealed event types (`NetworkRequestEvent`, `NetworkResponseEvent`, `NetworkErrorEvent`, `NetworkCancelEvent`) and the broadcast bus clients emit them into. A true no-op (no allocation) when Ketok is disabled. |
| `KetokStore` | Ring-buffer store (default 300 entries) that correlates request/response/error events by call id into immutable `NetworkCallEntry` values, exposed as `entries` and a `watch` stream. |
| `NetworkCallEntry` / `CapturedBody` | The immutable model of one captured call, and its request/response bodies with a hard 512 KB capture cap. |
| `KetokRedactor` | Case-insensitive header redaction (`Authorization`, `Cookie`, `X-Api-Key`, etc. by default) and body pattern redaction, meant to run **at capture time** so secrets never enter the store. |
| `KetokFilter` | `KetokFilter.parse(query)` compiles a DevTools-style query into a `matches(NetworkCallEntry)` predicate. |
| `CurlExporter` | Renders an entry as a runnable, shell-escaped `curl` command. |
| `DartSnippetExporter` | Renders an entry as a runnable `dio.request(...)` snippet. |
| `HarExporter` | Renders one call or a whole session as HAR 1.2 JSON. |
| `KetokConfig` | `enabled`, `maxEntries`, `maxBodyBytes`, `redactor` — passed to `KetokBinding.instance.initialize(config: ...)`. |

## Filter grammar

`KetokFilter.parse(String query)` splits the query on whitespace into terms
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
| `body:token` | Substring of the captured request or response body text |
| bare word | Substring of `method + " " + full URL` |
| `-<any term above>` | Negates that term |

Example: `method:get status:4xx larger-than:10k -host:*.cdn.com`.

## Usage without Flutter

```dart
import 'package:ketok_core/ketok_core.dart';

final config = KetokConfig(enabled: true);
KetokBinding.instance.initialize(config: config);

KetokBinding.instance.bus.emit(NetworkRequestEvent(/* ... */));
// ...
final entries = KetokBinding.instance.store.entries;
final filter = KetokFilter.parse('method:post s:error');
final matches = entries.where(filter.matches);

print(CurlExporter.export(matches.first));
print(HarExporter.exportSession(entries));
```

See [docs/SPEC-v0.1.md](../../docs/SPEC-v0.1.md) for the full v0.1 contract.
