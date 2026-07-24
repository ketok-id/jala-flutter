## 0.6.0

- Call diff: `JalaCallDiffScreen` + `JalaJsonDiffView` (unified status /
  header chips / body tree with add/remove/change colors). Entry points:
  **Compare with…** on call detail, multi-select ready path via route
  helper.
- Import UI: inspector overflow **Import cURL…** (opens request composer
  prefilled) and **Import HAR…** (session import, same imported-session
  banner / replay-disabled UX as session import).
- JSON tree virtualization: `JalaJsonTree` flattens visible rows into a
  `ListView.builder` (true virtualization when height is bounded; flat
  shrink-wrap when nested in a parent scroll view). Search, expand-all /
  collapse-all, type colors, and long-string expand preserved.

## 0.5.3

- Session menu: export full / no bodies / headers only; import dialog warns
  about log-dump sensitivity and size limit (pairs with jala_core 0.5.3).

## 0.5.2

- Headers: stacked name/value layout (full-width wrapping values) with
  per-value copy — long names no longer crush the value column. Search
  within headers; collapse common noise (date/server/…); collapse
  cookie/authorization under Sensitive.
- Call list: path is primary (up to 2 lines, monospace); query string
  included; host stays secondary. Status code uses status color; trailing
  shows duration + relative time (`12s ago`); long-press copies full URL;
  compact density toggle in the AppBar.
- Filter: quick chips (`4xx`, `5xx`, `Errors`, `Mocked`, `GraphQL`, `WS`);
  clearer hint contrast / filled field.
- Detail AppBar: method + multi-line path; Overview Path row.

## 0.5.1

- Pub metadata: `homepage`, `issue_tracker`, description covers throttle
  screen and session export/import (docs-only).

## 0.5.0

- `JalaThrottleScreen` (inspector AppBar speed icon): preset radio list
  (Off + Slow 3G/Fast 3G/Flaky/Offline, humanized), a custom profile
  editor (latency/jitter/download/upload fields, drop-rate slider), and a
  host-pattern scope field. Applies via
  `JalaBinding.instance.throttleRegistry.setActive`/`clear`.
- Active-throttle banner above the inspector list ("Throttling: <name> —
  tap to change"); AppBar speed icon gets a dot badge while active.
- Session actions in an inspector AppBar overflow menu: **Export
  session** (copies `JalaSessionCodec.encode` output to the clipboard with
  an entry-count snackbar) and **Import session** (paste-JSON dialog with
  a Replace/Append choice; malformed input shows an inline error instead
  of crashing). While `JalaStore.isViewingImport`: a banner offers
  **Clear** back to live capture, and imported entries disable
  Replay/Mock this/Edit & resend on the detail screen with an explanatory
  tooltip.
- Call detail Response tab renders a subscription payload timeline (index,
  size; tap opens a body view reusing the WS frame preview-sheet pattern)
  above the regular body section for `is:subscription` entries, with a
  trimmed-count note when the ring buffer has dropped older payloads.
- Filter help documents `is:subscription`.

## 0.4.0

- Merged inspector list: `NetworkCallEntry` and `WsConnectionEntry`
  interleave chronologically. GraphQL entries show `operationName` as the
  title with a `QUERY`/`MUTATION` method chip; WS entries show a `WS`
  chip, uri, live status color (connecting/open/closed/error), and
  frame count, updating live from `watchWs`.
- `JalaWsDetailScreen`: connection header (uri, status, open/close times,
  close code/reason) plus a frame timeline (direction arrow, relative
  timestamp, size) with a substring filter box; tapping a text frame opens
  a body view that reuses the JSON tree when the frame parses as JSON.
- Call detail Request tab for GraphQL entries (`is:graphql`) becomes two
  panes: Query (monospace, selectable) and Variables (JSON tree).
- WS entries hide cURL/HAR export actions (not representable) and instead
  offer copy frame text / copy connection summary as JSON.
- Filter help documents `is:ws`, `is:graphql`, and `op:<name>`.

## 0.3.0

- Mocks screen (list / enable / delete) and mock rule editor.
- **Mock this** on call detail prefills a rule from a captured call.
- **Edit & resend** composer for modified replay.
- Call list bolt badge for mocked entries; filter help documents
  `is:mocked`; inspector app bar opens Mocks with enabled-count badge.

## 0.2.0

- Image preview: `BodyKind.image` renders an inline `Image.memory` with
  size/mime caption and full-screen pinch-zoom on tap.
- Multipart request bodies render as a Name / Filename / Content-Type /
  Size parts table instead of the raw `@multipart` JSON tree.
- Pending list tiles show a determinate progress bar when totals are known;
  call detail Overview shows a Transferred row (live while pending, final
  snapshot after completion).

## 0.1.1

- Add pub.dev topics.

## 0.1.0

- `JalaInspectorScreen` — DevTools-style filter bar with live filtering,
  call list, and clear/copy-HAR/theme-toggle app bar actions.
- `JalaCallDetailScreen` — Overview / Request / Response tabs with a
  headers table, body viewer, and copy body/cURL/Dart snippet/HAR/replay
  actions.
- `JalaBodyView` + `JalaJsonTree` — collapsible pretty-JSON tree with
  in-body search, plain-text view, and a binary/too-large fallback.
- `JalaOverlayButton` — draggable floating bubble with a pending/error
  count badge, meant to be dropped into a host app's root `Overlay`.
- `JalaTheme` / `JalaThemeController` — explicit Material 3 light/dark/
  system theming that never inherits the host app's `Theme`.
- `JalaFilterHelpSheet` popover documenting the filter grammar.
- Status color coding: pending spinner, 2xx green, 3xx blue, 4xx orange,
  5xx/error red, cancelled grey.
