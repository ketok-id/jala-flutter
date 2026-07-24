# Jala roadmap

Status as of 2026-07-24. Detailed execution plans live in `docs/plans/`.

| Track | Goal | Shipped as | Status |
|---|---|---|---|
| A | Launch & adoption | 0.1.1 / 0.1.2 | ✅ DONE — [plan](plans/track-a-launch.md) |
| B | Capture-surface growth (jala_http, image preview, multipart, progress) | 0.2.0 | ✅ DONE — [plan](plans/track-b-v0.2.md) |
| C | Mocking & edit-and-resend | 0.3.0 | ✅ DONE — [plan](plans/track-c-v0.3-mocking.md) |
| D | Realtime & GraphQL | 0.4.0 | ✅ DONE — [plan](plans/track-d-v0.4.md) |
| E | Power tools: throttling, session share, subscription payloads | 0.5.0 | ✅ DONE — [plan](plans/track-e-v0.5.md) |
| F | Inspect deeper: call diff, JSON virtualization, cURL/HAR import | 0.6.0 | 🔜 PLANNED — [plan](plans/track-f-v0.6-inspect-deeper.md) |
| G | `jala_grpc` adapter (gRPC / gRPC-web) | 0.7.0 | 📋 PROPOSED |
| H | Localization (en + id-ID) | 0.6.x | 📋 PROPOSED |

All five packages (`jala`, `jala_core`, `jala_dio`, `jala_http`, `jala_ui`)
plus `jala_graphql` and `jala_websocket` are published on pub.dev at
**0.5.x** in lockstep, all under the verified publisher `ketok.id`.

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
- **JSON tree virtualization** — the tree currently builds every expanded
  node eagerly (a `Column`), so large payloads jank. Flatten to a lazily
  built list so only visible rows are constructed. Correctness/perf debt
  carried over from the 0.5.x viewer work.
- **cURL + HAR import** — export already ships both; import closes the loop.
  cURL lands in the request composer (edit-and-resend); HAR loads as an
  imported session (replay disabled, reusing the `imported` flag from E).

Detailed execution plan:
[plans/track-f-v0.6-inspect-deeper.md](plans/track-f-v0.6-inspect-deeper.md)
(written 2026-07-24).

## Track G — v0.7.0 proposal: `jala_grpc`

Next capture-surface expansion — gRPC / gRPC-web is effectively greenfield
in Flutter, the same gap that GraphQL/WS were before Track D. New package
`jala_grpc`: a `package:grpc` `ClientInterceptor` capturing unary and
streaming RPCs — service/method, request/response messages (`toProto3Json`
where available, else byte metadata), status code + trailers, and a
streaming timeline reusing the WS/subscription frame UI. Filter grammar:
`is:grpc`; `op:` reuses the method name. New package → assign to `ketok.id`
after first publish (standing rule). Detailed plan written when the track
starts.

## Track H — v0.6.x proposal: localization

Internationalize the inspector chrome (labels, tooltips, empty states,
action names) via `flutter gen-l10n` / ARB with a host-overridable delegate,
shipping `en` + `id-ID` first. On-brand for Ketok and low-risk — UI-only,
non-blocking, so it can ride alongside Track F rather than gate a release.
Deliberately *not* localized: the filter DSL grammar, HTTP method names, and
other developer-facing technical tokens.

## Horizon (beyond v0.6)

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
