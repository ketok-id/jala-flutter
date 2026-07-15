/// Dio interceptor for Jala, the in-app Flutter network inspector.
///
/// Captures requests, responses, errors, and cancellations made through a
/// `Dio` instance into `JalaBinding.instance`, and supports one-tap replay
/// via [JalaDioReplayer]. See [JalaDio.attach] for the recommended way to
/// wire a `Dio` instance into Jala.
library;

export 'src/jala_dio.dart';
export 'src/jala_dio_interceptor.dart';
export 'src/jala_dio_replayer.dart';
