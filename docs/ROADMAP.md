# Jala roadmap

Status as of 2026-07-16. Detailed execution plans live in `docs/plans/`.

| Track | Goal | Shipped as | Status |
|---|---|---|---|
| A | Launch & adoption | 0.1.1 / 0.1.2 | ✅ DONE — [plan](plans/track-a-launch.md) |
| B | Capture-surface growth (jala_http, image preview, multipart, progress) | 0.2.0 | ✅ DONE — [plan](plans/track-b-v0.2.md) |
| C | Mocking & edit-and-resend | 0.3.0 | ✅ DONE — [plan](plans/track-c-v0.3-mocking.md) |
| D | Realtime & GraphQL (proposed next) | 0.4.0 | 📝 PLANNED — [plan](plans/track-d-v0.4.md) |

All five packages (`jala`, `jala_core`, `jala_dio`, `jala_http`, `jala_ui`)
are published on pub.dev at **0.3.0** in lockstep under the verified
publisher `ketok.id` (pending: `jala_http` publisher assignment — user
action, package Admin tab).

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

## Horizon (beyond v0.4, unplanned)

- Storage explorers (Hive/Isar/Drift/SharedPreferences) — first non-network
  plugin; validates the Ketok plugin ecosystem vision.
- Throttling / network-condition simulation — `MockDelay` (shipped in 0.3)
  is the seed; full profiles (slow 3G, loss) exist in no in-app tool.
- Desktop companion (remote debug) — after in-app surface saturates.
- In-flight breakpoints — explicitly rejected for in-app (deadlock-prone);
  revisit only with the desktop companion.

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
