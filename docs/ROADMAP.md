# Jala roadmap

Working plan after the 0.1.0 release (2026-07-16). Three tracks, executed in
order. Each track has a detailed execution plan in `docs/plans/`.

| Track | Goal | Ships as | Plan |
|---|---|---|---|
| A | Launch & adoption | 0.1.1 (metadata only) | [track-a-launch.md](plans/track-a-launch.md) |
| B | Capture-surface growth | 0.2.0 | [track-b-v0.2.md](plans/track-b-v0.2.md) |
| C | Mocking & edit-and-resend | 0.3.0 | [track-c-v0.3-mocking.md](plans/track-c-v0.3-mocking.md) |

Ordering rationale: v0.1 is technically strong but has zero eyeballs — the
cheapest wins right now are adoption (Track A), not features. Track B widens
reach (`package:http` is the most-used client) and closes the known v0.1 gaps.
Track C is the category-changing bet: rule-based mocking is the most-loved
feature of Charles/Proxyman and no Flutter package does it well.

## Horizon (v0.4+, not yet planned in detail)

- GraphQL support (operation-aware UI: query/variables panes, operation
  grouping) — every incumbent lags here.
- WebSocket frame inspection — essentially greenfield in Flutter.
- Storage explorers (Hive/Isar/Drift/SharedPreferences) — first non-network
  plugin; validates the Ketok plugin ecosystem vision.
- Throttling / network-condition simulation — exists in no in-app tool.
- Desktop companion (remote debug) — only after in-app surface is saturated.

## Standing rules

- Every release: CHANGELOG entries, `dart pub publish --dry-run` clean on all
  packages, full test suite green, live smoke test on at least one real
  device or simulator before `pub publish`.
- Version all `jala_*` packages in lockstep.
- Packages stay under the pub.dev verified publisher `ketok.id`.
- `ketok_core` on pub.dev is a reserved brand name — never publish product
  code to it.
