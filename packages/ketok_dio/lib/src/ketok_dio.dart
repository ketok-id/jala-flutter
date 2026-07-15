import 'package:dio/dio.dart';
import 'package:ketok_core/ketok_core.dart';

import 'ketok_dio_interceptor.dart';
import 'ketok_dio_replayer.dart';

/// Convenience entry point for wiring a [Dio] instance into Ketok.
class KetokDio {
  const KetokDio._();

  /// Adds a [KetokDioInterceptor] to [dio] and registers a
  /// [KetokDioReplayer] for it with `KetokBinding.instance.replayRegistry`,
  /// so the inspector UI's Replay action can re-issue calls made through
  /// [dio].
  ///
  /// Plain `dio.interceptors.add(KetokDioInterceptor())` also works and
  /// captures calls identically — it just skips replay registration, so the
  /// Replay button stays disabled (no replayer registered) for calls made
  /// through that [Dio] instance.
  static void attach(Dio dio) {
    dio.interceptors.add(KetokDioInterceptor());
    KetokBinding.instance.replayRegistry.register(KetokDioReplayer(dio));
  }
}
