import 'package:dio/dio.dart';
import 'package:jala_core/jala_core.dart';

import 'jala_dio_interceptor.dart';
import 'jala_dio_replayer.dart';

/// Convenience entry point for wiring a [Dio] instance into Jala.
class JalaDio {
  const JalaDio._();

  /// Adds a [JalaDioInterceptor] to [dio] and registers a
  /// [JalaDioReplayer] for it with `JalaBinding.instance.replayRegistry`,
  /// so the inspector UI's Replay action can re-issue calls made through
  /// [dio].
  ///
  /// Plain `dio.interceptors.add(JalaDioInterceptor())` also works and
  /// captures calls identically — it just skips replay registration, so the
  /// Replay button stays disabled (no replayer registered) for calls made
  /// through that [Dio] instance.
  static void attach(Dio dio) {
    dio.interceptors.add(JalaDioInterceptor());
    JalaBinding.instance.replayRegistry.register(JalaDioReplayer(dio));
  }
}
