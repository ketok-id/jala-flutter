# Jala roadmap

Status as of 2026-08-05. Detailed execution plans live in `docs/plans/`.

| Track | Goal | Shipped as | Status |
|---|---|---|---|
| A | Launch & adoption | 0.1.1 / 0.1.2 | ✅ DONE — [plan](plans/track-a-launch.md) |
| B | Capture-surface growth (jala_http, image preview, multipart, progress) | 0.2.0 | ✅ DONE — [plan](plans/track-b-v0.2.md) |
| C | Mocking & edit-and-resend | 0.3.0 | ✅ DONE — [plan](plans/track-c-v0.3-mocking.md) |
| D | Realtime & GraphQL | 0.4.0 | ✅ DONE — [plan](plans/track-d-v0.4.md) |
| E | Power tools: throttling, session share, subscription payloads | 0.5.0 | ✅ DONE — [plan](plans/track-e-v0.5.md) |
| F | Inspect deeper: call diff, JSON virtualization, cURL/HAR import | 0.6.0 | ✅ DONE — [plan](plans/track-f-v0.6-inspect-deeper.md) |
| — | Read the URL: decoded query-param table, capture-time URL redaction | 0.7.0 | ✅ DONE |
| — | Capture-integrity hardening: body redaction across all adapters, Dio bandwidth throttling, replay/HAR/bubble fixes | 0.8.0 | ✅ DONE |
| G | `jala_grpc` adapter (gRPC / gRPC-web) | 0.8.0 | ✅ DONE (capture-only — see below) — [plan](plans/track-g-v0.8-grpc.md) |
| — | Android input/back fixes, honest export reporting, file-backed export | 0.8.1 | ✅ DONE |
| H | Localization (en + id-ID) | 0.8.2 | ✅ DONE — [plan](plans/track-h-v0.8.2-l10n.md) |
| I | Socket-level throttling (real byte pacing, covers all `dart:io` traffic) | 0.8.3 | 📋 PROPOSED — [plan](plans/track-i-v0.8.3-socket-throttle.md) |

Eight packages (`jala`, `jala_core`, `jala_dio`, `jala_http`, `jala_ui`,
`jala_graphql`, `jala_websocket`, `jala_grpc`) are published on pub.dev in
lockstep under the verified publisher `ketok.id`. `jala_grpc` was new in
0.8.0 and its publisher assignment is done — the standing-rule step that was
missed for `jala_http`.

**0.8.0 shipped 2026-08-04**, all eight packages. Both release gates were
met: device smokes passed on real hardware (track_g, track_e, track_d, and
track_b after an assertion fix), and the gRPC-web claim in `jala_grpc`'s
README is verified structurally — interceptors are applied by `Client`,
above the channel, so the transport underneath is irrelevant.

**0.8.1 (2026-08-11)** is an unlettered bug-fix release from user reports,
all four verified on a Xiaomi (Android 13 / API 33): Backspace was dead in
every inspector text field on Android, Escape/Tab/Enter did nothing, system
back went to the host app instead of the inspector, and exports reported
success when the clipboard had silently dropped them. Root cause of the
first three is one thing — the inspector is a *sibling* of the host app, so
it inherits nothing `WidgetsApp` provides and must install the
shortcut/action chain and its own back handling itself. Adds
`Jala.enableFileExport`.

The back-handling change is a **behavior** change shipped in a patch. That
is a deliberate exception (it replaces plainly broken behavior nobody could
have depended on), called out prominently in the `jala` changelog rather
than signalled by the version number.

**Track H (localization) was deliberately NOT in 0.8.1** — at the time only
1 of 12 screens was migrated, and shipping `JalaConfig.locale` half-done
would have burned the README/changelog mention that is the opt-in feature's
only discovery path. It ships as **0.8.2** instead.

The H5 device pass (Xiaomi, Android 13) found three things a diff review
would not have: the filter help sheet had never been migrated at all — H1
wrote its keys but the plan's own 12-file table omits the file — that sheet
then overflowed once translated because its column was never scrollable,
and the throttle bandwidth labels ellipsized away the very clause that says
what an empty field means. The opt-in guarantee was verified on hardware
whose system locale really is `id-ID`: with `JalaConfig.locale` unset the
inspector renders English.

## Track D — v0.4.0 proposal: GraphQL + WebSocket

The two capture surfaces every incumbent handles badly (research: Chucker's
GraphQL lags Apollo 4; only requests_inspector has purpose-built GraphQL;
WebSocket frame inspection is effectively greenfield in Flutter).

- `jala_graphql`: link/wrapper for `graphql_flutter` — operation-aware
  capture (operation name, query/variables/response as separate panes),
  operation-based grouping in the list, batched-query breakdown.
- `jala_websocket`: `WebSocketChannel` wrapper — connection entries with a
  frame timeline (per-frame direction/size/preview), text + binary frames,
  close codes. New UI surface: frame list under a connection detail screen.
- Filter grammar additions: `op:<name>`, `is:ws`, `is:graphql`.

Detailed execution plan: [plans/track-d-v0.4.md](plans/track-d-v0.4.md)
(written 2026-07-16). If launch feedback lands before Track D starts,
re-check its scope against the actual issues first.

## Track E — v0.5.0: power tools

Stay in the network lane while adoption grows. Three features, no new
packages: in-app throttling (category-first for Flutter inspectors),
session export/import (category-first), and GraphQL subscription payload
timelines. Detailed plan: [plans/track-e-v0.5.md](plans/track-e-v0.5.md).

## Track F — v0.6.0: inspect deeper

Scope decision (user, 2026-07-24): stay in the network lane, no new
packages. Three features that all leverage existing capture and the
type-colored JSON tree shipped in 0.5.x:

- **Call diff** — pick two entries (or "compare with…" from a call detail)
  and see a structural diff of status, headers, and JSON body, rendered in
  the JSON tree with add/remove/change coloring. Category-differentiating;
  no incumbent does it in-app.
- **JSON tree virtualization** — flatten expanded nodes into a
  `ListView.builder` so only viewport rows are built (large payloads no
  longer jank). Correctness/perf debt carried over from the 0.5.x viewer
  work; landed in 0.6.0.
- **cURL + HAR import** — export already ships both; import closes the loop.
  cURL lands in the request composer (edit-and-resend); HAR loads as an
  imported session (replay disabled, reusing the `imported` flag from E).

Detailed execution plan:
[plans/track-f-v0.6-inspect-deeper.md](plans/track-f-v0.6-inspect-deeper.md)
(written 2026-07-24).

## Track G — v0.8.0: `jala_grpc`

New capture surface — gRPC / gRPC-web was greenfield in Flutter, the same
gap GraphQL/WS were before Track D. New package `jala_grpc`: a
`package:grpc` `ClientInterceptor` capturing service/method, messages
(`toProto3Json` where available, else byte metadata), status codes and
trailers. Filter grammar: `is:grpc`; `op:` reuses the method name. Detailed
execution plan: [plans/track-g-v0.8-grpc.md](plans/track-g-v0.8-grpc.md)
(written 2026-08-03).

**Shipped narrower than proposed, verified against grpc 5.1.0.**
`ClientInterceptor` is a narrower hook than the other three adapters':

- Unary RPCs capture in full.
- **Streaming response messages cannot be captured.** `ResponseStream` is
  single-subscription and only constructible from a `ClientCall` private to
  the call site, so it can be neither tapped nor rebuilt. The original
  proposal's "streaming timeline reusing the WS/subscription frame UI" is
  therefore not buildable through this hook; a streaming RPC records its
  envelope plus request-side byte progress, and the detail screen says so.
- **Mocking and throttling do not apply to gRPC** — both need to fabricate
  or delay a response.

The escape routes (an upstream `grpc-dart` hook, or a `ClientChannel`
returning a tapping `ClientCall` subclass) are documented in the plan. The
channel route is **viable but fragile** — the exported concrete
`ClientChannel` is subclassable and `createCall` is overridable, but
starting the RPC needs `ClientConnection.dispatchCall`, and that type is
unexported, so it only works through `dynamic`.

**0.8.0 also carries the capture-integrity hardening** (decision: user,
2026-08-03 — it rides with Track G rather than taking its own release). Two
of those fixes constrain how any *future* adapter must be written:

- **Bodies are redacted through `CapturedBody.captureRedacted`, never
  `CapturedBody.capture`.** The old per-adapter "redact it if it's already
  a `String`" rule is what let `jala_http` ship with no body redaction at
  all and `jala_dio` skip its own default paths.
- **Throttling must cover the adapter's normal path, not just its streaming
  one.** Dio's bandwidth caps silently applied only to `ResponseType.stream`
  for two releases.

## Track H — v0.8.2: localization

Internationalize the inspector chrome (labels, tooltips, empty states,
snackbars, action names) behind a host-overridable delegate, shipping `en`
+ `id-ID` first. UI-only — no capture path, no adapter, no core model
change. Deliberately *not* localized: the filter DSL grammar, HTTP method
names, gRPC status names, byte/duration formatting, and the machine-read
export formats (HAR/cURL/session).

Two decisions the detailed plan makes, both departures from this section's
original sketch:

- **Hand-rolled delegate, not `flutter gen-l10n` / ARB.**
  `flutter_localizations` pins `intl` to an exact version, and `intl` is
  currently absent from the workspace lockfile — a debugging library
  should not dictate a host app's `intl` version. The usual reason to pay
  that (ICU plurals) doesn't apply: the UI has three plural sites, and
  Indonesian has no plural inflection.
- **0.8.x, strictly opt-in** (decision: user, 2026-08-05; now 0.8.2). The inspector
  does **not** follow the device locale — `JalaConfig.locale` unset means
  English, and an app on an Indonesian device renders exactly as it did
  before upgrading. That constraint is what keeps this inside
  `COMPAT.md`'s "sometimes patch if tiny" exception; the moment id-ID
  resolves without the host asking, it is a behaviour change and becomes
  0.9.0. Accepted cost: the translation is invisible until a host opts
  in, so the README and changelog entries are the feature's only
  discovery path.
- **Keep the common language in id-ID** (decision: user, 2026-08-05).
  Dev jargon Indonesian developers already speak in English — `request`,
  `response`, `header`, `payload`, `replay`, `mock` — stays English; the
  connective prose around it gets translated.

Track I renumbers to 0.8.3: 0.8.1 went to an unrelated bug-fix release and
H takes 0.8.2 as the one being built.

Detailed execution plan: [plans/track-h-v0.8.2-l10n.md](plans/track-h-v0.8.2-l10n.md)
(written 2026-08-05).

## Track I — v0.8.3 proposal: socket-level throttling

Today's throttle delays an already-decoded response inside an adapter Jala
was explicitly attached to. That has a scope problem and a fidelity problem:
`Image.network`, unattached `Dio` instances and raw `HttpClient`s ignore it
entirely (the most confusing thing about the feature — it reads as broken),
and connection setup plus the TLS handshake cost nothing.

`dart:io` exposes two hooks that move the simulation down to the socket
without native code or entitlements: `HttpClient.connectionFactory`
(supply the actual `Socket`) and `HttpOverrides.global` (cover clients Jala
never saw). Byte pacing on the real stream also makes drops fail as real
connection failures and latency behave like RTT.

Still out of reach, and to be stated plainly rather than implied: packet
loss, jitter and DNS delay; native HTTP stacks (`cronet_http`,
`cupertino_http`, native SDKs); and web, which has no `dart:io` and keeps
the adapter-level path. HTTP/2 is moot — `dart:io`'s client is HTTP/1.1
only. An on-device VPN would close the remaining gap and is **rejected**:
native code both platforms, an iOS Network Extension entitlement, store
review and a consent prompt make it a different product, the same reasoning
that put the desktop companion on the horizon.

Main cost is risk, not effort: `Socket` is a wide interface, and a decorator
that gets one member wrong breaks host networking — which the project's
capture invariants forbid.

Shipped as a **patch (0.8.3 — Track H took 0.8.2)** under `COMPAT.md`'s
"sometimes patch if tiny" exception for backward-compatible features —
which holds only while the
track stays strictly additive and opt-in (`Jala.enableSocketThrottling()`,
never `Jala.initialize`, defaults untouched). If socket mode ever becomes
the default, it is a behaviour change and the release becomes 0.9.0.

Detailed plan: [plans/track-i-v0.8.3-socket-throttle.md](plans/track-i-v0.8.3-socket-throttle.md)
(written 2026-08-04). Open question worth settling first: whether the scope
fix justifies the risk, or whether documenting "use Network Link Conditioner"
is the better trade.

## Horizon (beyond v0.8)

- **Desktop / remote companion** (epic, spec-first). Stream capture over a
  localhost WS/HTTP channel (debug builds only, opt-in, pairing token) to a
  desktop or web viewer, reusing `JalaSessionCodec` as the wire format. This
  is also the only safe home for in-flight breakpoints — out-of-process, so
  none of the in-app deadlock risk. Multi-release; write the security model
  (localhost bind, pairing, never in release builds) before any code.
- Storage explorers (Hive/Isar/Drift/SharedPreferences) — first non-network
  plugin; validates the Ketok plugin ecosystem vision.
- In-flight breakpoints — only via the desktop companion above; still
  rejected for in-app (deadlock-prone).

(HAR *import* promoted into Track F; desktop companion promoted from an
unplanned note to the epic above.)

## Performance & footprint

Memory is bounded by design, not by luck — treat these as invariants, not
tuning knobs:

- **Ring-buffer store.** `JalaConfig.maxEntries` (300),
  `maxWsFramesPerConnection`, and `maxSubscriptionPayloads` cap every
  retained collection, so capture runs indefinitely without unbounded growth.
- **Body truncation.** `CapturedBody` truncates at `defaultMaxBytes`
  (`BodyKind.truncated`), so no single payload can blow up the heap.
- **Baseline dominates at normal loads.** On-device snapshot (Xiaomi, light
  session, 2026-07-24): ~58 MB native-heap alloc / ~99 MB RSS — almost
  entirely the Flutter engine + Skia baseline; a dozen captured calls are
  negligible. Capture data only matters near the ring-buffer cap.

Open perf item: the JSON tree builds eagerly, so a large payload janks
(Track F2 virtualization). Measure large-payload frame times before/after
F2 rather than speculating — the same flattening also removes the
per-keystroke whole-tree search cost. No dedicated "optimization track" is
planned; these wins fold into F.

## Standing rules

- Every release: lockstep versions across all `jala_*` packages, CHANGELOG
  entries, `dart pub publish --dry-run` clean, full test suite green, and
  a live smoke test on at least one real device or simulator.
- CI runs `dart analyze --fatal-infos` — run it locally before pushing;
  plain `dart analyze` passing is NOT sufficient.
- Packages belong to pub.dev verified publisher `ketok.id`; new packages
  must be assigned to it after first publish (web UI, user action).
- `ketok_core` on pub.dev is a reserved brand name — never publish product
  code to it.
- Delegation model: Fable/Opus plans, reviews, and gates; Sonnet executes
  features; Haiku executes mechanical fixes.
