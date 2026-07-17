# jala_websocket

`package:web_socket_channel` integration for Jala, the in-app Flutter network
inspector: captures a WebSocket connection's lifecycle (connect, open,
close, error) and every frame sent or received through it.

See the [repo README](../../README.md) for what Jala is and why (filter
grammar, redaction-by-default) and the [`jala`](../jala) package for the
facade that wires this up in an app.

**Lockstep** with `jala` / `jala_core` `0.5.x`. Brownfield:
[docs/ADOPTION.md](../../docs/ADOPTION.md). WebSocket frames are **not**
throttled (HTTP adapters only).

## Install

```yaml
dependencies:
  jala_websocket: ^0.5.2   # requires jala_core ^0.5.2
```

## Wrap

```dart
import 'package:jala_websocket/jala_websocket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final uri = Uri.parse('wss://echo.websocket.events');
final channel = JalaWebSocketChannel.wrap(
  WebSocketChannel.connect(uri),
  uri: uri,
);

channel.sink.add('hello');
channel.stream.listen((message) => print(message));
```

`JalaWebSocketChannel.wrap` reads `JalaBinding.instance` (wired up by
`Jala.initialize()` from the `jala` facade package), and returns a
`WebSocketChannel` that behaves exactly like the one you passed in — same
`stream`/`sink` semantics — while teeing every frame and lifecycle
transition into Jala's store.

### Why the `uri` parameter?

`WebSocketChannel` has no way to report the URL it was connected with
(`WebSocketChannel.connect(uri)` returns synchronously and doesn't retain
or expose `uri` anywhere on the interface). Pass the same `Uri` you connect
with so the inspector's connection list and detail screen have something
meaningful to show. If you omit it, Jala captures a placeholder
`unknown://unknown` URI instead — everything else (frames, status,
close code/reason) is still captured normally.

## What gets captured

A `WsConnectionEntry` (see `jala_core`) tracks, per connection:

- **Lifecycle**: a `WsConnectEvent` is emitted the instant you call `wrap`
  (status `connecting`); once `channel.ready` resolves, a `WsOpenEvent`
  promotes it to `open`. A `WsCloseEvent` (status `closed`, with close
  code/reason) fires when either side closes the sink, or the underlying
  stream completes on its own. A `WsErrorEvent` (status `error`) fires if
  the stream errors — e.g. a dropped connection.
- **Frames**: every `sink.add(...)` (direction `sent`) and every value
  delivered on `stream` (direction `received`) is captured as a `WsFrame` —
  timestamp, direction, size, and (for text frames) a redacted preview
  capped at 4 KB. Binary frames are metadata-only: size is recorded, but
  the payload itself is never retained.
- **Ring buffer**: each connection keeps its most recent
  `JalaConfig.maxWsFramesPerConnection` frames (default 200); older frames
  fall out silently, but `WsConnectionEntry.frameCount` keeps counting the
  true total ever observed. Connections themselves are capped at
  `JalaConfig.maxWsConnections` (default 20), oldest-closed evicted first.

## Throttling

WebSocket frames are **not** throttled. `JalaThrottleRegistry` applies to
HTTP adapters (`jala_dio`, `jala_http`) only — frames still pass through
`JalaWebSocketChannel` at full speed regardless of the active profile.
(WS throttling is intentionally out of scope for v0.5.)

## Production safety

- `wrap()` checks `JalaBinding.instance.isEnabled` once, up front. When
  Jala is disabled (or never initialized), `wrap()` returns the exact same
  `channel` you passed in, untouched — no wrapper object, no capture code
  on the path at all. Safe to leave `JalaWebSocketChannel.wrap(...)` in
  release builds.
- Every capture call site (frame capture, connect/open/close/error
  emission) is wrapped in `try`/`catch`: a bug in Jala's own capture logic
  can never throw into your app's `stream` or block `sink.add`/`close`.
  The original data, error, or done event is always forwarded to your app
  exactly once, regardless of whether capture succeeded.
- Text frame previews are redacted at capture time via
  `JalaConfig.redactor`'s body patterns, before anything enters the
  in-memory store.

## Limitations

- Frame-level mocking (intercepting/replaying individual WS frames) is out
  of scope — a candidate for a future release.
- There is no HAR export for WebSocket connections — no standard format
  exists for representing a frame timeline.
- Network-condition simulation (latency / drop / bandwidth) does not apply
  to WebSocket frames — see [Throttling](#throttling) above.
