# jala_dio

**Dio** adapter for Jala: captures request / response / error / cancel /
progress, supports one-tap **replay**, and applies network **throttling**.

> [What is Jala?](../../README.md) · [Package map](../../docs/packages.md) ·
> [Doc index](../../docs/README.md)

| | |
|---|---|
| **Audience** | Apps using Dio |
| **Depends on** | `jala_core`, `dio` |
| **Lockstep** | `0.7.x` with `jala` / `jala_core` — [COMPAT.md](../../docs/COMPAT.md) |
| **Requires** | Dart `^3.11` |

Wire the facade with [`jala`](../jala) (`Jala.initialize` + `JalaOverlay`).
Brownfield: [ADOPTION.md](../../docs/ADOPTION.md).

---

## Install

```yaml
dependencies:
  jala: ^0.7.0
  jala_dio: ^0.7.0
  dio: ^5.0.0
```

## Setup

```dart
import 'package:dio/dio.dart';
import 'package:jala_dio/jala_dio.dart';

final dio = Dio();

// Auth (and other header mutators) BEFORE Jala so capture sees final headers.
dio.interceptors.add(AuthInterceptor());
JalaDio.attach(dio); // interceptor + replay registration
```

### Interceptor order (common footgun)

Jala snapshots `options.headers` in `onRequest`. If auth runs **after**
Jala, `Authorization` is **missing** from the inspector (not even
`••••••`).

```dart
// BAD
JalaDio.attach(dio);
dio.interceptors.add(AuthInterceptor());

// GOOD
dio.interceptors.add(AuthInterceptor());
JalaDio.attach(dio);
```

Details: [TROUBLESHOOTING.md](../../docs/TROUBLESHOOTING.md).

### Capture only (no replay)

```dart
dio.interceptors.add(JalaDioInterceptor());
```

Replay stays disabled until something registers a replayer via
`JalaDio.attach`.

---

## Public API

| API | Role |
|---|---|
| `JalaDio.attach(dio)` | Add interceptor + register `JalaDioReplayer` |
| `JalaDioInterceptor` | Capture-only interceptor |
| `JalaDioReplayer` | Re-issue stored calls through the same `Dio` |

Reads `JalaBinding.instance` at call time (configured by `Jala.initialize`).

---

## Behavior notes

### Replay

Rebuilds `RequestOptions` and re-issues through the same `Dio` (interceptors
run again). New entry gets `replayOf` set. **Masked** headers and query
params are not resent.

**Multiple clients:** last `JalaDio.attach` / `JalaHttp.wrap` wins for the
Replay button. Attach every Dio you want **captured**; attach the **primary**
API client last.
[ADOPTION — multiple Dio](../../docs/ADOPTION.md#multiple-dio-instances-very-common).

### Throttling

Uses `JalaThrottleRegistry` when a profile is active and the host matches:

- **Drop** (e.g. Offline) → connection-error `DioException` before the adapter
- **Latency** (± jitter) before forward
- **Download bandwidth** only for `ResponseType.stream` — default buffered
  responses never see the stream, so they get latency/drop only

### Production safety

- No-op when `!isEnabled`
- Capture in `try`/`catch`; always forward exactly once
- Redaction + body caps via `JalaConfig` — [CONFIG.md](../../docs/CONFIG.md)

---

## See also

- [docs/TROUBLESHOOTING.md](../../docs/TROUBLESHOOTING.md)  
- [docs/CONFIG.md](../../docs/CONFIG.md) · [docs/SECURITY.md](../../docs/SECURITY.md)  
- [CHANGELOG.md](CHANGELOG.md)
