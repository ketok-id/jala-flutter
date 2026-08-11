# jala

Facade for **Jala**, the in-app Flutter network inspector —
`Jala.initialize()` plus `JalaOverlay` wire up capture, storage, and the
inspector UI in two lines.

> [What is Jala?](../../README.md) · [Package map](../../docs/packages.md) ·
> [Doc index](../../docs/README.md)

| | |
|---|---|
| **Audience** | Flutter apps (install this, not `jala_ui` alone) |
| **Depends on** | `jala_ui`, `jala_core` |
| **Lockstep** | `0.8.x` with all Jala packages — [COMPAT.md](../../docs/COMPAT.md) |
| **Requires** | Dart `^3.11`, Flutter `>=3.35` |

**Existing app?** [ADOPTION.md](../../docs/ADOPTION.md) ·
**Config / redaction:** [CONFIG.md](../../docs/CONFIG.md) ·
**Missing traffic:** [TROUBLESHOOTING.md](../../docs/TROUBLESHOOTING.md)

---

## Install

```yaml
dependencies:
  jala: ^0.8.1
  jala_dio: ^0.8.1   # or jala_http / jala_graphql / jala_websocket
  dio: ^5.0.0
```

## Setup

```dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jala/jala.dart';
import 'package:jala_dio/jala_dio.dart';

void main() {
  Jala.initialize(); // enabled: kDebugMode by default
  final dio = Dio();
  JalaDio.attach(dio);
  runApp(JalaOverlay(child: MyApp(dio: dio)));
}
```

Tap the floating **J** bubble (or call `Jala.open()`) to inspect traffic.
When disabled, `JalaOverlay` returns `child` unchanged.

### Other adapters

| Client | Package | Setup |
|---|---|---|
| `package:http` | [`jala_http`](../jala_http) | `JalaHttp.wrap(http.Client())` |
| GraphQL (`gql_link`) | [`jala_graphql`](../jala_graphql) | `JalaGraphQLLink(endpoint: uri)` before terminating link |
| WebSocket | [`jala_websocket`](../jala_websocket) | `JalaWebSocketChannel.wrap(channel, uri: uri)` |

Full map: [docs/packages.md](../../docs/packages.md).

---

## Public API

| API | Role |
|---|---|
| `Jala.initialize({JalaConfig? config})` | Idempotent bind; default `enabled: kDebugMode` |
| `Jala.open()` / `Jala.close()` | Show / hide inspector |
| `JalaOverlay` | Root wrapper + floating bubble |
| `Jala.enableMockPersistence(directory)` | Optional file-backed mock rules (`jala_mock_rules.json`) |
| `Jala.controller` / `Jala.themeController` | Overlay open state and inspector theme |

---

## What you get in the inspector

- Call list with DevTools-style **filter grammar**
- Detail: headers (sensitive collapsed), query params, bodies, GraphQL/WS
- **Replay**, mock, edit & resend (live clients only; not imported rows)
- **Throttle** presets, **session** export/import, **cURL/HAR** import
- **Call diff**, virtualized JSON tree, image/multipart/progress where captured

Feature history and roadmap: [docs/ROADMAP.md](../../docs/ROADMAP.md).

---

## Language (English / Indonesian)

The inspector chrome ships in **English** and **Indonesian**. It is
**opt-in**, and unset means English — Jala does **not** follow the device
locale:

```dart
Jala.initialize(
  config: JalaConfig(enabled: kDebugMode, locale: 'id-ID'),
);
```

An app on an Indonesian phone renders exactly as it did before this setting
existed unless you pass `locale`. That is deliberate: following the platform
locale automatically would change behaviour for existing hosts. `'id'` and
`'id-ID'` both select Indonesian; anything unsupported falls back to English
rather than throwing.

**No new dependencies.** The tables are hand-rolled rather than generated
from ARB, so Jala never pins an `intl` version onto your app.

Deliberately left in English, so a half-translated UI doesn't read as a bug:
the filter DSL (`status:`, `is:ws`, `op:`), HTTP method names, gRPC status
names, byte/duration formatting, every exported artifact (HAR, cURL, session
JSON), and the handful of Flutter framework strings inside the inspector
("Back", "Close"). Indonesian also keeps the developer vocabulary its
audience already speaks in English — `request`, `response`, `header`,
`payload`, `replay`, `mock`.

Details: [CONFIG.md](../../docs/CONFIG.md).

---

## Production safety

- Off by default in release (`enabled: kDebugMode`)
- True no-op when disabled (overlay + adapters)
- Redaction at capture time — [SECURITY.md](../../docs/SECURITY.md),
  [CONFIG.md](../../docs/CONFIG.md)
- Hard body size caps (default 512 KB)
- Session export modes: full / no bodies / headers only

Leave the dependency wired in release builds; that is intentional and safe.

---

## See also

- [docs/README.md](../../docs/README.md) — documentation index  
- [docs/ADOPTION.md](../../docs/ADOPTION.md) — brownfield install  
- [docs/overview.md](../../docs/overview.md) — architecture  
- [docs/COMPAT.md](../../docs/COMPAT.md) — lockstep policy  
- [CHANGELOG.md](CHANGELOG.md)
