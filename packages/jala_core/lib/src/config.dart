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
    JalaRedactor? redactor,
  }) : redactor = redactor ?? JalaRedactor();

  /// Whether Jala captures anything at all. When false every capture
  /// path is a synchronous no-op.
  final bool enabled;

  /// Maximum number of entries retained by the store (ring buffer size).
  final int maxEntries;

  /// Hard cap, in bytes, on each captured request/response body.
  final int maxBodyBytes;

  /// The redactor applied to headers and bodies at capture time.
  final JalaRedactor redactor;
}
