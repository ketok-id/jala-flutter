# ketok_ui

Inspector UI for Ketok, the in-app Flutter network inspector: the call
list, detail screens, JSON viewer, and overlay bubble. Pure UI over
`package:ketok_core` — no business logic beyond display, filtering, and
export/replay wiring.

See the [repo README](../../README.md) for what Ketok is and why, and the
[`ketok`](../ketok) package for the facade most apps should install
instead of depending on this package directly.

## What's here

- `KetokInspectorScreen` — filter bar (DevTools-style grammar, live &
  debounced) + call list + clear/copy-HAR/theme-toggle app bar actions.
- `KetokCallDetailScreen` — Overview / Request / Response tabs, a
  hand-rolled expandable JSON tree with in-body search, and a bottom
  action bar (copy body/cURL/Dart snippet/HAR, replay).
- `KetokOverlayButton` — draggable floating bubble with a pending/error
  badge, meant to be dropped into a host app's root `Overlay`.
- `KetokInspector.route()` — a `MaterialPageRoute` wrapping the inspector
  in its own theme, for embedders to push onto a root navigator.
- `KetokTheme` / `KetokThemeController` / `KetokThemeMode` — explicit
  light/dark Material 3 theming that never inherits the host app's
  `Theme`.

## Usage

```dart
import 'package:ketok_ui/ketok_ui.dart';

Navigator.of(context).push(KetokInspector.route());
```

All widgets read live data from `KetokBinding.instance.store.watch`, so the
UI updates in real time as calls complete — including for calls already in
flight when a detail screen is opened.

## Status colors

pending = neutral + spinner, 2xx = green, 3xx = blue, 4xx = orange,
5xx/error = red, cancelled = grey.
