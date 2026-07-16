/// `package:http` adapter for Jala, the in-app Flutter network inspector.
///
/// Wraps any `http.Client` to capture requests, responses, and errors made
/// through it into `JalaBinding.instance`, and supports one-tap replay via
/// [JalaHttpReplayer]. See [JalaHttp.wrap] for the recommended way to wire
/// an `http.Client` into Jala.
library;

export 'src/jala_http.dart';
export 'src/jala_http_client.dart';
export 'src/jala_http_replayer.dart';
