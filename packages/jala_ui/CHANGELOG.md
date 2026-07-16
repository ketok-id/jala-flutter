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
