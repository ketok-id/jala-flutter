# jala_websocket

**WebSocket** adapter for Jala (`web_socket_channel`): captures connection
lifecycle (connect / open / close / error) and every frame sent or received.

> [What is Jala?](../../README.md) · [Package map](../../docs/packages.md) ·
> [Doc index](../../docs/README.md)

| | |
|---|---|
| **Audience** | Apps using `WebSocketChannel` |
| **Depends on** | `jala_core`, `web_socket_channel` |
| **Lockstep** | `0.8.x` — [COMPAT.md](../../docs/COMPAT.md) |
| **Requires** | Dart `^3.11` |

Wire the facade with [`jala`](../jala). Brownfield:
[ADOPTION.md](../../docs/ADOPTION.md).

**Note:** WebSocket frames are **not** throttled (HTTP adapters only).

---

## Install

```yaml
dependencies:
  jala: ^0.8.2
  jala_websocket: ^0.8.2
```

## Setup

```dart
import 'package:jala_websocket/jala_websocket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final uri = Uri.parse('wss://echo.websocket.events');
final channel = JalaWebSocketChannel.wrap(
  WebSocketChannel.connect(uri),
  uri: uri, // required for a meaningful inspector URL
);

channel.sink.add('hello');
channel.stream.listen((message) { /* ... */ });
```

### Why pass `uri`?

`WebSocketChannel` does not expose the connect URL. Omit `uri` and Jala
stores placeholder `unknown://unknown`; frames and lifecycle still capture.

---

## Public API

| API | Role |
|---|---|
| `JalaWebSocketChannel.wrap(channel, {Uri? uri})` | Tee lifecycle + frames into the store |

When disabled, `wrap` returns the **same** channel instance (no wrapper).

---

## What gets captured

Connections are **`WsConnectionEntry`** rows (parallel store collection —
not HTTP `NetworkCallEntry`). UI merges them in the call list.

| Data | Notes |
|---|---|
| Lifecycle | connect → open → close/error; close code/reason |
| Frames | direction, size; text preview redacted, cap 4 KB; binary metadata only |
| Rings | `maxWsFramesPerConnection` (default 200); `maxWsConnections` (default 20) |

Filter: `is:ws` (and host/status text on WS rows).

---

## Limitations

- No frame-level mock/replay  
- No HAR export for WS timelines (no standard format)  
- No throttle on frames  

---

## Production safety

- No-op when disabled (returns original channel)
- Capture never throws into app `stream` / `sink`
- Text previews redacted at capture — [CONFIG.md](../../docs/CONFIG.md)

---

## See also

- [docs/overview.md](../../docs/overview.md) — WS vs HTTP store  
- [docs/TROUBLESHOOTING.md](../../docs/TROUBLESHOOTING.md)  
- [CHANGELOG.md](CHANGELOG.md)
