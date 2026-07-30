# jala_ui

Inspector **UI** for Jala: call list, detail screens, virtualized JSON tree,
call diff, cURL/HAR import, overlay bubble, throttle screen, and session
export/import. Pure presentation over `jala_core`.

> [What is Jala?](../../README.md) · [Package map](../../docs/packages.md) ·
> [Doc index](../../docs/README.md)

| | |
|---|---|
| **Audience** | Rarely direct — most apps install [`jala`](../jala) instead |
| **Depends on** | `jala_core` (Flutter) |
| **Lockstep** | `0.7.x` — [COMPAT.md](../../docs/COMPAT.md) |
| **Requires** | Flutter `>=3.35`, Dart `^3.11` |

---

## Install

Prefer the facade:

```yaml
dependencies:
  jala: ^0.7.0   # depends on jala_ui
```

Direct dependency only if you host the inspector yourself:

```yaml
dependencies:
  jala_ui: ^0.7.0
  jala_core: ^0.7.0
```

## Setup (via facade)

```dart
Jala.initialize();
runApp(JalaOverlay(child: MyApp()));
// Jala.open() or tap the bubble
```

### Embed without overlay

```dart
import 'package:jala_ui/jala_ui.dart';

Navigator.of(context).push(JalaInspector.route());
```

Widgets read `JalaBinding.instance.store.watch` / `watchWs` live.

---

## What’s here

| Surface | Role |
|---|---|
| `JalaInspectorScreen` | Filter bar, merged HTTP/WS list, AppBar actions |
| `JalaCallDetailScreen` | Overview / Request / Response; GraphQL/WS panes; actions |
| `JalaCallDiffScreen` / `JalaJsonDiffView` | Structural compare |
| `JalaWsDetailScreen` | Connection + frame timeline |
| `JalaThrottleScreen` | Presets + custom profile + host glob |
| `JalaOverlayButton` | Draggable bubble (pending/error badge) |
| `JalaInspector.route()` | Themed route for custom navigators |
| `JalaTheme` / `JalaThemeController` | Own light/dark Material 3 (not host Theme) |

**AppBar / overflow:** clear, HAR copy, theme, throttle, session
export/import (full / no bodies / headers only), import cURL / HAR.

**Request headers UI:** cookie/auth collapsed under **Sensitive** by default
(values already redacted at capture — [CONFIG.md](../../docs/CONFIG.md)).

**Imported entries:** replay / mock / edit disabled with tooltip.

---

## Invariants

- Does **not** inherit host `Theme`
- Private navigator + localizations under the overlay
- Filter grammar is core’s `JalaFilter` — see
  [jala_core README](../jala_core/README.md#filter-grammar)

Status colors: pending spinner; 2xx green; 3xx blue; 4xx orange; 5xx/error
red; cancelled grey. WS chips: connecting / open / closed / error.

---

## See also

- [jala](../jala) — recommended app entrypoint  
- [docs/ADOPTION.md](../../docs/ADOPTION.md)  
- [docs/SECURITY.md](../../docs/SECURITY.md) — export hygiene  
- [CHANGELOG.md](CHANGELOG.md)
