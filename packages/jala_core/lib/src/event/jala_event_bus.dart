import 'dart:async';

import 'jala_event.dart';

/// A broadcast bus for [JalaEvent]s.
///
/// [emit] is a synchronous, zero-allocation no-op (beyond the enabled
/// check itself) whenever [isEnabled] returns false, so a disabled Jala
/// costs callers essentially nothing on the hot networking path.
class JalaEventBus {
  JalaEventBus({required bool Function() isEnabled}) : _isEnabled = isEnabled;

  final bool Function() _isEnabled;
  final StreamController<JalaEvent> _controller =
      StreamController<JalaEvent>.broadcast();

  /// Broadcast stream of every emitted event, in emission order.
  Stream<JalaEvent> get events => _controller.stream;

  /// Emits [event] to all current listeners of [events].
  ///
  /// Does nothing (synchronously) if [isEnabled] currently returns false.
  void emit(JalaEvent event) {
    if (!_isEnabled()) return;
    _controller.add(event);
  }

  /// Releases the underlying stream controller. After calling this, no
  /// further events will be delivered.
  Future<void> dispose() => _controller.close();
}
