# jala_ui

Inspector UI for Jala, the in-app Flutter network inspector: the call
list, detail screens, JSON viewer, overlay bubble, throttle screen, and
session export/import. Pure UI over `package:jala_core` — no business
logic beyond display, filtering, and export/replay wiring.

See the [repo README](../../README.md) for what Jala is and why, and the
[`jala`](../jala) package for the facade most apps should install
instead of depending on this package directly.

Requires Flutter `>=3.35`. Lockstep `0.5.x` with `jala_core`. Brownfield:
[docs/ADOPTION.md](../../docs/ADOPTION.md).

## What's here

- `JalaInspectorScreen` — filter bar (DevTools-style grammar, live &
  debounced) + merged HTTP/WS call list + AppBar actions (clear, copy HAR,
  theme toggle, **throttle** speed icon, **session export/import** overflow).
- `JalaThrottleScreen` — Off / Slow 3G / Fast 3G / Flaky / Offline presets,
  custom profile editor, host-pattern glob. Active profile shows a list
  banner and a badge on the speed icon.
- Session share (inspector overflow) — **Export session** copies
  `JalaSessionCodec.encode` JSON to the clipboard; **Import session** is a
  paste-JSON dialog (replace/append). No `share_plus` / file-picker
  dependency in this package. While `isViewingImport`, an import banner
  offers Clear back to live capture.
- `JalaCallDetailScreen` — Overview / Request / Response tabs, expandable
  JSON tree, image preview, multipart parts, transfer progress, GraphQL
  query/variables panes, subscription payload timeline, and bottom actions
  (cURL / Dart / HAR / Replay / Mock this / Edit & resend). Imported entries
  disable replay/mock/edit with an explanatory tooltip.
- `JalaWsDetailScreen` — WebSocket connection header + frame timeline.
- `JalaOverlayButton` — draggable floating bubble with a pending/error
  badge, meant to be dropped into a host app's root `Overlay`.
- `JalaInspector.route()` — a `MaterialPageRoute` wrapping the inspector
  in its own theme, for embedders to push onto a root navigator.
- `JalaTheme` / `JalaThemeController` / `JalaThemeMode` — explicit
  light/dark Material 3 theming that never inherits the host app's
  `Theme`.

## Usage

```dart
import 'package:jala_ui/jala_ui.dart';

Navigator.of(context).push(JalaInspector.route());
```

All widgets read live data from `JalaBinding.instance.store.watch` (and
`watchWs` for WebSocket rows), so the UI updates in real time as calls
complete — including for calls already in flight when a detail screen is
opened.

## Status colors

pending = neutral + spinner, 2xx = green, 3xx = blue, 4xx = orange,
5xx/error = red, cancelled = grey. WebSocket rows use connecting/open/
closed/error colors on a `WS` chip.
