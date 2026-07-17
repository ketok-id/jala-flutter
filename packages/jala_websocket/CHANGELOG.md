## 0.5.1

- Pub metadata: `homepage`, `issue_tracker`, description notes frames are
  not throttled (docs-only).

## 0.5.0

- Lockstep release; no functional changes. Bumped for the `jala_core`
  0.5.0 dependency (throttling / session codec / subscription payloads
  are orthogonal to this package — WS frames still pass through
  unthrottled).

## 0.4.0

- First release of the `package:web_socket_channel` adapter for Jala.
- `JalaWebSocketChannel.wrap(channel, {uri})` — wraps any `WebSocketChannel`,
  returning one with identical `stream`/`sink` behavior that also captures:
  - Connection lifecycle: `WsConnectEvent` immediately on wrap, `WsOpenEvent`
    once `channel.ready` completes, `WsCloseEvent` (code/reason) on either
    side closing or the stream completing on its own, `WsErrorEvent` on a
    stream error.
  - Every frame sent (`sink.add`) or received (`stream`), as a `WsFrame`:
    direction, size, and — for text frames — a redacted preview capped at
    4 KB. Binary frames are captured as metadata-only (size, no payload).
- Disabled Jala (or an uninitialized binding) makes `wrap()` a true no-op:
  it returns the exact same `channel` instance, untouched.
- Capture is wrapped in `try`/`catch` throughout, so a bug in Jala's own
  logic can never break the app's WebSocket traffic — the original data,
  error, or done event is always forwarded exactly once.
