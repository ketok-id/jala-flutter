## 0.1.0

- `KetokInspectorScreen` — DevTools-style filter bar with live filtering,
  call list, and clear/copy-HAR/theme-toggle app bar actions.
- `KetokCallDetailScreen` — Overview / Request / Response tabs with a
  headers table, body viewer, and copy body/cURL/Dart snippet/HAR/replay
  actions.
- `KetokBodyView` + `KetokJsonTree` — collapsible pretty-JSON tree with
  in-body search, plain-text view, and a binary/too-large fallback.
- `KetokOverlayButton` — draggable floating bubble with a pending/error
  count badge, meant to be dropped into a host app's root `Overlay`.
- `KetokTheme` / `KetokThemeController` — explicit Material 3 light/dark/
  system theming that never inherits the host app's `Theme`.
- `KetokFilterHelpSheet` popover documenting the filter grammar.
- Status color coding: pending spinner, 2xx green, 3xx blue, 4xx orange,
  5xx/error red, cancelled grey.
