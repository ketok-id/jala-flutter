# Track F — v0.6.0: inspect deeper (call diff, JSON virtualization, cURL/HAR import)

Scope decision (user, 2026-07-24): stay in the network lane, no new
packages, no new brand surface. Three features, each leveraging capture that
already exists plus the type-colored JSON tree shipped in 0.5.x. One
(call diff) is a category-first — no in-app Flutter inspector diffs calls.

Execution order (proven A–E pattern): **F1 core alone** (one executor) →
**F2 UI as two parallel executors** (virtualization is independent of
diff+import; both depend only on F1/core) → **F3 example/smoke/release**.
No new packages → no publisher transfers this time.

## F1. Core (`jala_core`) — one executor, runs alone

**Import codecs** — new `jala_core/lib/src/import/`, mirroring `src/export/`.

- `JalaCurlCodec.decode(String) -> ImportedRequest {method, uri, headers,
  body}`. Parse a `curl` command: bare-arg URL, `-X/--request`, repeated
  `-H/--header`, `-d/--data/--data-raw/--data-binary/--data-urlencode`,
  `-u` (basic auth → `Authorization`), `--compressed` (accepted, ignored),
  shell line-continuations (`\`), single- and double-quoted args. Method
  defaults to GET, or POST when data is present and no `-X` given.
- `JalaHarCodec.decode(String harJson) -> JalaSession`. Parse HAR 1.2
  `log.entries[]` → `NetworkCallEntry` (request method/url/headers/postData,
  response status/headers/content, `time` → duration), every entry flagged
  `imported: true`. Reuse the field mapping from the existing HAR *exporter*
  in reverse; factor a shared `_HarShapes` helper if it reads cleanly.
- Failure is always typed, never a crash: cURL → `JalaImportFormatException`;
  HAR → the existing `JalaSessionFormatException` (reused from Track E).

**Diff model** — pure and UI-agnostic so it unit-tests without a widget tree.

- `JalaJsonDiff.diff(dynamic a, dynamic b) -> DiffNode`. Recursive structural
  diff. `DiffNode {key, kind: added|removed|changed|unchanged, before,
  after, children}`. Maps diff key-wise; lists diff positionally in v1 (note
  LCS/keyed-list diff as a future refinement); a type change counts as
  `changed`.
- `JalaEntryDiff.of(NetworkCallEntry a, b) -> {statusDiff, headerDiffs
  (added/removed/changed, case-insensitive keys), requestBodyDiff?,
  responseBodyDiff?}`. Body diffs only when both sides decode as JSON;
  otherwise fall back to a text/"changed" marker.

Tests: cURL variants (quotes, multiline `\`, `--data-raw`, repeated `-H`,
`-u`, `-X` inference); HAR export→import round-trip preserves entries and
sets `imported`; diff correctness (nested add/remove/change, type change,
list-length change, unchanged subtree short-circuits); malformed input →
typed exceptions. Target D1/E1-level coverage.

## F2. UI (`jala_ui`) — after F1; two independent executors

**(a) JSON tree virtualization** — independent of diff/import; touches only
the tree.

- Replace the eager recursive `Column` in `JalaJsonTree` with a flattened,
  lazily built model: compute `List<_FlatRow {node, depth, kind}>` from
  `data` + `_expanded` + `query`, and feed a `ListView.builder` / sliver so
  only visible rows are constructed. Large payloads stop janking.
- Preserve everything 0.5.x added: search filter + theme-aware highlight,
  match count, expand-all / collapse-all, per-type leaf colors
  (`_JsonLeafStyle`), long-string tap-to-expand. The existing tree widget
  tests are the parity guardrail — they must stay green with minimal edits.
- Riskiest item in the track: behavioral parity with the current widget.
  Land it behind its own PR and re-run the full `jala_ui` suite.

**(b) Call diff + import** — depends on F1.

- `JalaCallDiffScreen` — takes two entries, renders a unified diff: status
  line, a header table with add/remove/change chips, and request/response
  body diff via the tree in "diff mode" (green added / red removed / amber
  changed, from the same theme-aware palette). Entry points: multi-select in
  the inspector list ("Compare (2)") and a "Compare with…" action on a call
  detail.
- Import entry points: inspector overflow → "Import" → paste-cURL dialog
  (routes into the request composer, prefilled for edit-and-resend) and
  paste-or-pick HAR (→ `JalaStore.importSession`, same imported-session
  banner + replay-disabled UX as session import).

Tests (widget): flattened tree renders/expands/searches identically (port
the current tree tests); diff screen colors add/remove/change rows; cURL
import prefills the composer; HAR import populates the list with replay
disabled.

## F3. Example + smoke + release

- Example (`jala_example`): add "Import cURL (sample)" and "Import HAR
  (sample)" buttons and a "Compare last two" action to the QA rig.
- Smoke on a real device or simulator (standing rule); then lockstep
  **0.6.0** across all seven packages — CHANGELOG entries,
  `dart pub publish --dry-run` clean, full suite green,
  `dart analyze --fatal-infos` clean before push.
- If Track H (localization) rides along, fold its string extraction into F2
  and bump together in the same 0.6.0.

## Notes

- Delegation (standing rule): Fable/Opus plans, reviews, and gates; Sonnet
  executes features; Haiku executes mechanical fixes.
- No new packages this track, so no pub.dev publisher assignment step.
- Track G (`jala_grpc`) and the desktop companion epic are unaffected by F —
  F deliberately keeps the in-app surface as the only runtime.
