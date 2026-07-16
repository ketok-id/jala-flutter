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
