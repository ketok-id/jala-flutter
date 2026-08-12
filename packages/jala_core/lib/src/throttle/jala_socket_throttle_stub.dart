/// Socket-level throttling on platforms without `dart:io` — i.e. web.
///
/// There is nothing to hook: `HttpClient`, `HttpOverrides` and
/// `connectionFactory` are all `dart:io`. Web therefore keeps the
/// adapter-level throttle path, which is exactly why replacing the adapter
/// path on `dart:io` costs no "web fallback" — see
/// docs/plans/track-i-v0.8.3-socket-throttle.md, Open question 3.
///
/// [isSupported] is false here, so callers degrade rather than break.
class JalaSocketThrottle {
  const JalaSocketThrottle._();

  /// Whether socket-level throttling can work on this platform.
  static bool get isSupported => false;

  // No `connectionFactory` here on purpose. It would have to be typed
  // `Object?` — web cannot name `ConnectionTask` or `Socket` — and shared
  // code analyses against *this* file, so an untyped stand-in would silently
  // become the type every caller sees. Anything needing the real factory is
  // `dart:io`-only and imports `jala_socket_throttle_io.dart` directly.
}
