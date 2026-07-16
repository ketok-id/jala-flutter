import 'package:http/http.dart' as http;
import 'package:jala_core/jala_core.dart';

import 'jala_http_client.dart';
import 'jala_http_replayer.dart';

/// Convenience entry point for wrapping a `http.Client` into Jala.
class JalaHttp {
  const JalaHttp._();

  /// Wraps [inner] (a fresh `http.Client()` when omitted) in a
  /// [JalaHttpClient] and registers a [JalaHttpReplayer] for the returned
  /// client with `JalaBinding.instance.replayRegistry`, so the inspector
  /// UI's Replay action can re-issue calls made through it.
  ///
  /// Plain `JalaHttpClient(inner: http.Client())` also works and captures
  /// calls identically — it just skips replay registration, so the Replay
  /// button stays disabled (no replayer registered) for calls made through
  /// that client.
  ///
  /// SPEC-NOTE: `JalaReplayRegistry` keeps a single active replayer —
  /// calling `JalaHttp.wrap` after `JalaDio.attach` (or vice versa) makes
  /// the most-recently-registered one win; Replay only re-issues through
  /// whichever client/library was wired up last.
  static http.Client wrap([http.Client? inner]) {
    final JalaHttpClient client = JalaHttpClient(inner: inner);
    JalaBinding.instance.replayRegistry.register(JalaHttpReplayer(client));
    return client;
  }
}
