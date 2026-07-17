# jala

Facade package for Jala, the in-app Flutter network inspector —
`Jala.initialize()` plus `JalaOverlay` wire up capture, storage, and the
inspector UI in two lines.

See the [repo README](../../README.md) for the full pitch (replay, filter
grammar, redaction-by-default, throttling, session share), the comparison
vs. alice/chucker_flutter/talker, and the roadmap.

## Quick start

```yaml
dependencies:
  jala: ^0.5.0
  jala_dio: ^0.5.0   # if you use Dio
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
unchanged when disabled — see the [repo README](../../README.md#production-safety)
for the full production-safety story.

### Other adapters

| Client | Package | Setup |
|---|---|---|
| `package:http` | [`jala_http`](../jala_http) `^0.5.0` | `JalaHttp.wrap(http.Client())` |
| GraphQL (`gql_link`) | [`jala_graphql`](../jala_graphql) `^0.5.0` | `JalaGraphQLLink(endpoint: uri)` before terminating link |
| WebSocket | [`jala_websocket`](../jala_websocket) `^0.5.0` | `JalaWebSocketChannel.wrap(channel, uri: uri)` |

### v0.5 power tools (in the inspector)

- **Throttle** (AppBar speed icon): Slow 3G / Fast 3G / Flaky / Offline +
  custom profiles and host glob.
- **Session share** (AppBar overflow): export/import a versioned JSON
  session via clipboard (`JalaSessionCodec` under the hood).
- **Subscriptions**: GraphQL payload timeline on the Response tab;
  filter with `is:subscription`.

See [docs/SPEC-v0.1.md](../../docs/SPEC-v0.1.md) for the original v0.1
contract; later tracks extend the model without breaking those defaults.
