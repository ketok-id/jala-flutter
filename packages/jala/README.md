# jala

Facade package for Jala, the in-app Flutter network inspector —
`Jala.initialize()` plus `JalaOverlay` wire up capture, storage, and the
inspector UI in two lines.

See the [repo README](../../README.md) for the full pitch (replay, filter
grammar, redaction-by-default, throttling, session share), the comparison
vs. alice/chucker_flutter/talker, and the roadmap.

**Existing app?** Prefer the brownfield guide:
[docs/ADOPTION.md](../../docs/ADOPTION.md) (multi-Dio, GraphQL
double-capture, Alice/Chucker migration, debug bootstrap, PR checklist).

**Requirements:** Dart `^3.11`, Flutter `>=3.35`. Use **lockstep** versions
with adapters (`jala` / `jala_dio` / … all `^0.5.1`). Compatibility notes:
[docs/COMPAT.md](../../docs/COMPAT.md).

## Quick start

```yaml
dependencies:
  jala: ^0.5.1
  jala_dio: ^0.5.1   # if you use Dio
  dio: ^5.0.0
```

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
`enabled` defaults to `kDebugMode`, and `JalaOverlay` returns `child`
unchanged when disabled — see [Production safety](#production-safety)
below and the [repo README](../../README.md#production-safety).

### Other adapters

| Client | Package | Setup |
|---|---|---|
| `package:http` | [`jala_http`](../jala_http) `^0.5.1` | `JalaHttp.wrap(http.Client())` |
| GraphQL (`gql_link`) | [`jala_graphql`](../jala_graphql) `^0.5.1` | `JalaGraphQLLink(endpoint: uri)` before terminating link |
| WebSocket | [`jala_websocket`](../jala_websocket) `^0.5.1` | `JalaWebSocketChannel.wrap(channel, uri: uri)` |

### v0.5 power tools (in the inspector)

- **Throttle** (AppBar speed icon): Slow 3G / Fast 3G / Flaky / Offline +
  custom profiles and host glob.
- **Session share** (AppBar overflow): export/import a versioned JSON
  session via clipboard (`JalaSessionCodec` under the hood).
- **Subscriptions**: GraphQL payload timeline on the Response tab;
  filter with `is:subscription`.

## Production safety

- **Off by default in release** — `Jala.initialize()` uses `enabled:
  kDebugMode` unless you override it.
- **True no-op when disabled** — overlay returns `child` unchanged;
  adapters skip capture on the hot path.
- **Redaction at capture time** — sensitive headers are masked before they
  enter the in-memory store (nothing to leak in screenshots of the
  inspector).
- **Hard body size caps** — default 512 KB per captured body.

Leave the dependency wired in release builds; that is intentional and safe.

## See also

- [docs/ADOPTION.md](../../docs/ADOPTION.md) — existing apps
- [docs/COMPAT.md](../../docs/COMPAT.md) — 0.x / lockstep policy
- [docs/SPEC-v0.1.md](../../docs/SPEC-v0.1.md) — original v0.1 contract
