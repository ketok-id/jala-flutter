# jala_http

**`package:http`** adapter for Jala: captures every request / response /
error through an `http.Client`, supports one-tap **replay**, and full
network **throttling** (latency, drop, upload + download pacing).

> [What is Jala?](../../README.md) · [Package map](../../docs/packages.md) ·
> [Doc index](../../docs/README.md)

| | |
|---|---|
| **Audience** | Apps using `package:http` |
| **Depends on** | `jala_core`, `http` |
| **Lockstep** | `0.7.x` — [COMPAT.md](../../docs/COMPAT.md) |
| **Requires** | Dart `^3.11` |

Wire the facade with [`jala`](../jala). Brownfield:
[ADOPTION.md](../../docs/ADOPTION.md).

---

## Install

```yaml
dependencies:
  jala: ^0.7.0
  jala_http: ^0.7.0
```

## Setup

```dart
import 'package:http/http.dart' as http;
import 'package:jala_http/jala_http.dart';

final client = JalaHttp.wrap(http.Client());
await client.get(Uri.parse('https://example.com'));
```

`JalaHttp.wrap` wraps the client (or a fresh one if omitted) and registers
a `JalaHttpReplayer` for the inspector Replay action.

### Capture only (no replay)

```dart
final client = JalaHttpClient(inner: http.Client());
```

---

## Public API

| API | Role |
|---|---|
| `JalaHttp.wrap([client])` | Wrap + register replayer |
| `JalaHttpClient` | Capture-only client |
| `JalaHttpReplayer` | Re-issue stored calls through the wrapped client |

---

## Behavior notes

### Stream tee

`send()` returns a `StreamedResponse`. Jala tees the body: every chunk is
forwarded to the app **unmodified**, while a separate buffer (capped at
`maxBodyBytes`) holds an inspector preview. Large downloads are delivered
in full to the app; only the preview truncates.

### Replay

Rebuilds `http.Request` through the same wrapped client; new entry has
`replayOf`. Masked headers / query params are not resent.

**Last replayer wins** if you also use `JalaDio.attach` — attach primary
client last ([ADOPTION.md](../../docs/ADOPTION.md)).

### Throttling

When a profile is active and the host matches:

- **Drop** → `ClientException` before the inner client  
- **Latency** before forward  
- **Bandwidth** in **both** directions (unlike Dio’s stream-only download
  pacing) — request and response streams are paced when configured  

### Production safety

- No-op when `!isEnabled`
- Capture never blocks or replaces the real request/response path
- Redaction + body caps — [CONFIG.md](../../docs/CONFIG.md)

---

## See also

- [docs/TROUBLESHOOTING.md](../../docs/TROUBLESHOOTING.md)  
- [docs/CONFIG.md](../../docs/CONFIG.md) · [docs/SECURITY.md](../../docs/SECURITY.md)  
- [CHANGELOG.md](CHANGELOG.md)
