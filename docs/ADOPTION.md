# Add Jala to an existing Flutter app

This guide is for **brownfield** projects: you already have Dio / `http` /
GraphQL / WebSockets, maybe Alice or Chucker, and you want Jala without
rewiring the app.

Target readers: mid-level implementers *and* seniors reviewing the PR.

Lockstep version for this doc: **0.6.0** (requires Dart `^3.11`, Flutter
`>=3.35` for `jala` / `jala_ui`).

---

## Why teams add it (30 seconds)

| Need | Jala answer |
|---|---|
| See traffic on a real device without Charles/Proxyman | In-app inspector + floating bubble |
| Re-hit a failing call after a fix | One-tap **Replay** through the live client |
| Find “only 4xx from the auth host” | DevTools-style filter grammar |
| Don’t leak tokens in screenshots | Redaction **at capture time** |
| Safe in release by default | `enabled` defaults to `kDebugMode`; true no-op when off |
| QA shares a bad session with eng | Session export / import (clipboard JSON) |
| Simulate Slow 3G on device | In-app throttle profiles |

If you already standardize on a desktop proxy + structured logging and
never need on-device inspection, you may not need Jala. That’s fine.

---

## 5-minute path (single Dio app)

### 1. Dependencies

```yaml
dependencies:
  jala: ^0.6.0
  jala_dio: ^0.6.0
  # dio: you already have this
```

### 2. Wire once at the edge of the app

Prefer a single debug bootstrap file so production code review is one
delete/revert away:

```dart
// lib/debug/jala_bootstrap.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jala/jala.dart';
import 'package:jala_dio/jala_dio.dart';

/// Call from main() before runApp. Safe to leave in release: when
/// [kDebugMode] is false, Jala stays a no-op unless you pass enabled: true.
void installJala(Dio dio) {
  Jala.initialize(); // enabled: kDebugMode
  JalaDio.attach(dio);
}

Widget wrapWithJala(Widget app) => JalaOverlay(child: app);
```

```dart
// lib/main.dart
void main() {
  final dio = createAppDio(); // your existing factory
  installJala(dio);
  runApp(wrapWithJala(MyApp(dio: dio)));
}
```

### 3. Open the inspector

- Tap the floating **J** bubble, or  
- Call `Jala.open()` from a debug drawer / hidden gesture.

### 4. Confirm it works

1. Fire any authenticated API call.  
2. Open Jala → entry appears.  
3. Request headers: `Authorization` should show as `***` (redacted).  
4. Tap **Replay** — a second entry appears with a replay badge.

Done. Everything below is for multi-client, senior architecture, or
migration.

---

## Which packages do I need?

Install **only** what you use. All versions lockstep at `^0.6.0`.

| You use… | Add | Setup |
|---|---|---|
| Facade + UI (almost everyone) | `jala` | `Jala.initialize()` + `JalaOverlay` |
| Dio | `jala_dio` | `JalaDio.attach(dio)` per instance |
| `package:http` | `jala_http` | `JalaHttp.wrap(client)` |
| GraphQL (`gql_link` / ferry / graphql_flutter) | `jala_graphql` | `JalaGraphQLLink` **before** terminating link |
| WebSockets (`web_socket_channel`) | `jala_websocket` | `JalaWebSocketChannel.wrap(ch, uri: uri)` |

`jala` already depends on `jala_core` + `jala_ui`. You do **not** need to
depend on `jala_core` or `jala_ui` directly unless you are building a
custom adapter or embedding only the UI.

---

## Senior-friendly layout (recommended)

Keep network tooling out of domain / data layers:

```text
lib/
  main.dart                 → create Dio, installJala, runApp(wrapWithJala(...))
  debug/
    jala_bootstrap.dart     → only file that imports package:jala*
  core/network/
    dio_client.dart         → pure Dio setup (interceptors for auth/logging OK)
  features/...              → never imports jala
```

Rules that pass architecture review:

1. **One bootstrap** — `installJala` is the only place that calls
   `Jala.initialize` / `JalaDio.attach` / wraps GraphQL or WS.  
2. **No Jala in domain** — repositories stay pure.  
3. **Attach every client that hits the network** — see multi-Dio below.  
4. **Leave it wired in release** — defaults make it a no-op; no
   conditional `import` gymnastics required (though a debug-only import
   is fine if your linter prefers it).

---

## Multiple Dio instances (very common)

Jala does **not** magically discover every `Dio()`. You must attach each
instance that should appear in the inspector:

```dart
void installJala({
  required Dio apiDio,
  required Dio uploadDio,
  Dio? analyticsDio, // optional: skip if you don't want noise
}) {
  Jala.initialize();
  JalaDio.attach(apiDio);
  JalaDio.attach(uploadDio);
  // analyticsDio intentionally not attached
}
```

### Replay ownership

The **last** `JalaDio.attach` / `JalaHttp.wrap` registers the active
replayer. If you attach both Dio and `http`:

- Capture works for both.  
- **Replay** uses whichever client was registered last.

For multi-client apps: attach the “primary” API client **last**, or accept
that Replay is best-effort for secondary clients. (Improving multi-replayer
routing is a future enhancement — today, document which client is primary
in your team’s debug notes.)

### Flavors / environments

Same code path for `dev` / `staging` / `prod` binaries is fine:

```dart
Jala.initialize(
  config: JalaConfig(
    enabled: kDebugMode || appFlavor == Flavor.stagingQa,
  ),
);
```

Use explicit `enabled: true` only for **internal QA builds** that must
inspect traffic outside debug. Never enable on public store builds unless
you have a compliance-approved reason.

---

## package:http

```dart
import 'package:http/http.dart' as http;
import 'package:jala_http/jala_http.dart';

final client = JalaHttp.wrap(http.Client());
```

Prefer one shared client from your DI graph (same as Dio). Wrapping a
throwaway `http.Client()` per request works for capture but is wasteful
and confuses Replay.

---

## GraphQL

```dart
final link = Link.from([
  JalaGraphQLLink(endpoint: graphqlUri),
  HttpLink(graphqlUri.toString()),
]);
```

### Double-capture (the #1 footgun)

If `HttpLink` (or ferry’s transport) uses a `Dio` / `http.Client` that you
**also** wrapped with Jala, the same operation appears twice:

1. GraphQL entry (`client: graphql`, operation name, query panes)  
2. Raw HTTP POST from the transport adapter  

**Pick one:**

| Goal | Do this |
|---|---|
| GraphQL-aware UI | Use `JalaGraphQLLink`; do **not** attach Jala to that transport’s Dio/http |
| Raw HTTP only | Attach Dio/http; skip `JalaGraphQLLink` |
| Both (debug noise OK) | Keep both; filter with `is:graphql` or `-is:graphql` |

Filter tips:

- `is:graphql` — operation-aware rows only  
- `is:subscription` — subscription streams  
- `op:Login*` — by operation name  

---

## WebSockets

```dart
final uri = Uri.parse('wss://api.example.com/ws');
final channel = JalaWebSocketChannel.wrap(
  WebSocketChannel.connect(uri),
  uri: uri, // required for a useful inspector URL
);
```

Notes:

- Pass the same `uri` you connected with (the channel API does not expose it).  
- WS rows merge into the inspector list with a `WS` chip; open for the
  frame timeline.  
- **Throttle does not apply to WebSocket frames** (HTTP only in v0.5).  
- Frame-level mock/replay is out of scope.

---

## Overlay placement (navigator / modular / add-to-app)

```dart
runApp(JalaOverlay(child: MyApp()));
// MyApp builds MaterialApp / CupertinoApp / Router
```

| Setup | Guidance |
|---|---|
| Standard single `MaterialApp` | `JalaOverlay` **above** `MaterialApp` (as in the quick start) |
| `MaterialApp.router` | Same — wrap the app widget that owns the `Router` |
| Multiple engines / add-to-app | Install Jala only in the Flutter engine that owns the network clients you care about; overlay must sit in that engine’s widget tree |
| Own root `Navigator` + overlays | Bubble uses the host overlay; inspector uses its **own** theme and route so it won’t inherit your app `Theme` |

If the bubble doesn’t show: you wrapped a subtree that isn’t under the root
overlay, or Jala is disabled (`enabled: false` / release without opt-in).

Android back closes the inspector instead of popping your app — that is
intentional.

---

## Migrating from Alice / Chucker / talker

You can run them side by side briefly, then remove the old interceptor.

### Alice

| Alice | Jala |
|---|---|
| `Alice()` + `AliceDioAdapter` / navigator key | `Jala.initialize()` + `JalaDio.attach` + `JalaOverlay` |
| Shake / notification to open | Bubble or `Jala.open()` |
| Mobile-focused | Mobile + desktop + web |

Remove Alice’s Dio adapter and navigator-key wiring once the team is
comfortable. Keep any custom logging interceptors that aren’t Alice.

### chucker_flutter

Chucker is Android/OkHttp-oriented. On Flutter, replace its interceptor
with `JalaDio.attach`. You gain desktop/web, replay, mocking, GraphQL/WS
depth, and throttle — you keep cURL/HAR-style export via Jala’s actions.

### talker

Talker is a **logger / error tracker**, not a network inspector UI. Keep
Talker for logs/crashes; add Jala for request inspection. They solve
different jobs — not a 1:1 swap.

### Checklist

- [ ] Remove old network inspector interceptor from Dio  
- [ ] `JalaDio.attach` on every Dio that should appear  
- [ ] `JalaOverlay` at root  
- [ ] Confirm redaction on a real auth call  
- [ ] Confirm Replay on the primary client  
- [ ] Delete Alice/Chucker dependencies when unused  

---

## Production safety checklist (paste into the PR)

Full model: [SECURITY.md](SECURITY.md).

- [ ] `Jala.initialize()` uses default or `enabled: kDebugMode` for store builds  
- [ ] No `enabled: true` on public release flavors without privacy review  
- [ ] Default redactor covers your auth headers — extend
      `JalaRedactor.defaultRedactedHeaders` for company-specific names  
- [ ] Body secrets: defaults mask common `password` / `*_token` / `api_key`
      JSON + form fields; add org-specific `redactedBodyPatterns` if needed  
- [ ] Body cap acceptable (`maxBodyBytes`, default 512 KB) for your traffic  
- [ ] GraphQL transport not double-wrapped (or team accepts double rows)  
- [ ] Session export: prefer **headers only** / **no bodies** for tickets;
      treat full export like a log dump  
- [ ] Optional: `Jala.enableMockPersistence` only on developer machines /
      internal builds (plaintext `jala_mock_rules.json`)

When disabled, `JalaOverlay` returns `child` unchanged and adapters skip
capture work on the hot path. Leaving the dependency in `pubspec` for
release is intentional and safe.

---

## Team workflows (v0.5 power tools)

### Throttle (device QA without a proxy)

Inspector → **speed** icon → Slow 3G / Fast 3G / Flaky / Offline / custom +
optional host glob (`*.example.com`).

- Banner shows while active.  
- Dio: latency + drop always; bandwidth pacing only for
  `ResponseType.stream`.  
- `package:http`: latency + drop + upload/download pacing.  
- WebSocket frames: not throttled.

### Session share (QA → eng)

1. QA reproduces the bug with Jala open.  
2. Overflow → export mode:
   - **full** — complete capture (trusted channels only)  
   - **no bodies** — metadata + headers  
   - **headers only** — safest for tickets  
3. Paste into a ticket / chat (treat as a **log dump**).  
4. Eng: Overflow → **Import session** → inspect offline
   (paste max ~8 MiB).  
5. Imported rows: Replay / Mock / Edit disabled (expected).  
6. **Clear** on the import banner returns to live capture.

Programmatic:

```dart
// Safer for tickets:
final json = JalaSessionCodec.encode(
  JalaBinding.instance.store,
  options: JalaSessionExportOptions.headersOnly,
);
// Full fidelity (trusted eng only):
// JalaSessionCodec.encode(store);
JalaBinding.instance.store.importSession(JalaSessionCodec.decode(json));
```

### Mocking / edit-and-resend

- Detail → **Mock this** for a canned rule  
- **Edit & resend** for one-off modified requests  
- Filter `is:mocked`  
- Optional: `Jala.enableMockPersistence(dir)` for rules across restarts  

---

## Useful filter cheat sheet

| Query | Meaning |
|---|---|
| `s:4xx` | Client errors |
| `s:error` | Failed / cancelled / HTTP error class |
| `host:api.example.com` | Exact host |
| `host:*.cdn.com` | Wildcard host |
| `slower-than:500` | Slow calls (ms) |
| `is:replay` | Replayed calls |
| `is:mocked` | Mock short-circuit |
| `is:graphql` / `is:subscription` / `is:ws` | Protocol surfaces |
| `op:GetUser` | GraphQL operation name |
| `-host:*.analytics.com` | Hide noise |

Help sheet in the inspector documents the full grammar.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| No bubble | Jala disabled, or overlay not at root | Check `enabled` / `kDebugMode`; wrap above `MaterialApp` |
| No entries | Client not attached | `JalaDio.attach` / `JalaHttp.wrap` / GraphQL link / WS wrap on **that** instance |
| Entries but Replay greyed out | No replayer, or imported session | Attach with `JalaDio.attach` / `JalaHttp.wrap`; clear import banner |
| Duplicate GraphQL + HTTP rows | Double-capture | See [GraphQL](#graphql) |
| Auth header visible as real token | Another interceptor logs it, or custom redactor removed defaults | Keep default header redaction; fix other loggers |
| “Works in debug, empty in release QA” | Default `enabled: kDebugMode` | Internal QA flavor: `JalaConfig(enabled: true)` |
| Large download not slow under throttle (Dio) | Non-stream response type | Use `ResponseType.stream` or test with `jala_http` |
| WS not slowing under Slow 3G | By design in v0.5 | Throttle is HTTP-only |
| Install prompt / blank screen on Android smoke | MIUI/vendor install UX; store-only tests have no UI | Approve install; blank screen during integration_test is expected |

---

## What not to do

- Don’t call `Jala.initialize()` from a widget `initState` on every rebuild.  
- Don’t expect Jala to find Dio instances created deep in feature code
  without `attach`.  
- Don’t enable Jala on public production to “debug a user issue” without a
  privacy review — use session export from an internal build, or logs.  
- Don’t put `share_plus` / file pickers into your app *for Jala* unless you
  want a custom recipe; clipboard export/import is enough for most teams.  
- Don’t treat talker removal as required — keep logging, add inspection.

---

## Minimal PR description (copy/paste)

```text
Add Jala (in-app network inspector) for debug/QA.

- jala + jala_dio ^0.6.0
- installJala() in debug bootstrap; JalaOverlay at root
- Attach primary Dio (and list any secondary clients)
- Default enabled: kDebugMode (no-op in store release)
- Redaction at capture; Replay via live Dio

Docs: https://github.com/ketok-id/jala-flutter/blob/main/docs/ADOPTION.md
```

---

## See also

- [Root README](../README.md) — pitch, comparison table, filter grammar  
- [Roadmap](ROADMAP.md) — shipped tracks and horizon  
- Package READMEs under `packages/*` — adapter-specific limits (e.g. Dio
  stream pacing, WS unthrottled)  
- Example QA rig: `examples/jala_example`  
