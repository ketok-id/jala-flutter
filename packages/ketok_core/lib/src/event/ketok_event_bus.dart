import 'dart:async';

import 'ketok_event.dart';

/// A broadcast bus for [KetokEvent]s.
///
/// [emit] is a synchronous, zero-allocation no-op (beyond the enabled
/// check itself) whenever [isEnabled] returns false, so a disabled Ketok
/// costs callers essentially nothing on the hot networking path.
class KetokEventBus {
  KetokEventBus({required bool Function() isEnabled}) : _isEnabled = isEnabled;

  final bool Function() _isEnabled;
  final StreamController<KetokEvent> _controller =
      StreamController<KetokEvent>.broadcast();

  /// Broadcast stream of every emitted event, in emission order.
  Stream<KetokEvent> get events => _controller.stream;

  /// Emits [event] to all current listeners of [events].
  ///
  /// Does nothing (synchronously) if [isEnabled] currently returns false.
  void emit(KetokEvent event) {
    if (!_isEnabled()) return;
    _controller.add(event);
  }

  /// Releases the underlying stream controller. After calling this, no
  /// further events will be delivered.
  Future<void> dispose() => _controller.close();
}
