import 'model/captured_body.dart';
import 'redact/jala_redactor.dart';

/// Configuration for a Jala session, passed to `JalaBinding.initialize`.
class JalaConfig {
  /// Creates a config.
  ///
  /// [enabled] defaults to `false` here in pure-Dart core; the `jala`
  /// facade package defaults it to `kDebugMode` instead. Keeping the core
  /// default `false` means an unconfigured binding is always a true no-op
  /// (production safety by default).
  JalaConfig({
    this.enabled = false,
    this.maxEntries = 300,
    this.maxBodyBytes = CapturedBody.defaultMaxBytes,
    this.captureImageBodies = true,
    this.maxWsConnections = 20,
    this.maxWsFramesPerConnection = 200,
    this.maxSubscriptionPayloads = 50,
    JalaRedactor? redactor,
  }) : redactor = redactor ?? JalaRedactor();

  /// Whether Jala captures anything at all. When false every capture
  /// path is a synchronous no-op.
  final bool enabled;

  /// Maximum number of entries retained by the store (ring buffer size).
  final int maxEntries;

  /// Maximum number of WebSocket connections retained by the store (ring
  /// buffer size for `JalaStore.wsConnections`). Oldest-closed (or errored)
  /// connections are evicted first; see `JalaStore` for eviction order.
  final int maxWsConnections;

  /// Maximum number of frames retained per WebSocket connection (a
  /// per-connection ring buffer). `WsConnectionEntry.frameCount` still
  /// reflects the total number of frames ever observed, even once older
  /// frames have been evicted from `WsConnectionEntry.frames`.
  final int maxWsFramesPerConnection;

  /// Maximum number of GraphQL subscription payloads retained per call (a
  /// per-call ring buffer, mirroring [maxWsFramesPerConnection]).
  /// `NetworkCallEntry.payloadCount` still reflects the total number of
  /// payloads ever observed, even once older ones have been evicted from
  /// `NetworkCallEntry.payloads`.
  final int maxSubscriptionPayloads;

  /// Hard cap, in bytes, on each captured request/response body.
  final int maxBodyBytes;

  /// Whether image response bodies (content-type `image/*`) within
  /// [maxBodyBytes] are kept as raw bytes ([BodyKind.image]) for inline
  /// preview in the inspector. When false, image bodies fall back to the
  /// existing metadata-only [BodyKind.bytes] capture.
  final bool captureImageBodies;

  /// The redactor applied to headers and bodies at capture time.
  final JalaRedactor redactor;
}
