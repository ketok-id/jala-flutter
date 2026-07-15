import 'dart:math';

/// Generates process-unique, roughly-sortable ids for network calls.
///
/// Ketok deliberately avoids a `uuid` dependency (see SPEC v0.1 §ketok_core
/// dependencies). Instead an id is composed of a monotonically increasing
/// counter, the current microsecond timestamp, and a short random suffix.
/// This keeps ids unique within a single isolate run (which is all Ketok
/// ever needs: ids are never persisted across app launches) while remaining
/// cheap to generate on every request.
class KetokIdGenerator {
  KetokIdGenerator._();

  static int _counter = 0;
  static final Random _random = Random();

  /// Returns the next id, e.g. `1737000000000000-000042-a1b2c3`.
  static String next() {
    final int counter = _counter++;
    final int timestamp = DateTime.now().microsecondsSinceEpoch;
    final String suffix = _random
        .nextInt(0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0');
    final String counterPart = counter.toRadixString(16).padLeft(6, '0');
    return '$timestamp-$counterPart-$suffix';
  }
}
