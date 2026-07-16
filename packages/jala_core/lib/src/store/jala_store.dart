import 'dart:async';

import '../event/jala_event.dart';
import '../event/jala_event_bus.dart';
import '../model/captured_body.dart';
import '../model/jala_call_status.dart';
import '../model/network_call_entry.dart';

/// An in-memory ring buffer of [NetworkCallEntry] built by correlating
/// [JalaEvent]s from a [JalaEventBus].
///
/// Entries are ordered newest-first. Once [entries] would exceed
/// [maxEntries], the oldest *completed* entry (success/error/cancelled) is
/// evicted first; only once there are no completed entries left does the
/// oldest *pending* entry get evicted. Events for an id that has already
/// been evicted (or was never seen) are silently ignored.
class JalaStore {
  JalaStore({required JalaEventBus bus, this.maxEntries = 300}) {
    _subscription = bus.events.listen(_onEvent);
  }

  /// Maximum number of entries retained before eviction kicks in.
  final int maxEntries;

  StreamSubscription<JalaEvent>? _subscription;

  // Newest-first.
  final List<NetworkCallEntry> _entries = <NetworkCallEntry>[];

  final StreamController<List<NetworkCallEntry>> _updates =
      StreamController<List<NetworkCallEntry>>.broadcast();

  /// Current entries, newest first. A fresh unmodifiable snapshot.
  List<NetworkCallEntry> get entries => List.unmodifiable(_entries);

  /// Emits a fresh snapshot of [entries] on every change, and immediately
  /// replays the current snapshot to each new listener.
  late final Stream<List<NetworkCallEntry>> watch =
      Stream<List<NetworkCallEntry>>.multi((controller) {
        controller.add(List.unmodifiable(_entries));
        final StreamSubscription<List<NetworkCallEntry>> sub = _updates.stream
            .listen(
              controller.add,
              onError: controller.addError,
              onDone: controller.close,
            );
        controller.onCancel = sub.cancel;
      });

  /// Looks up an entry by its id. Returns null if absent (never seen, or
  /// already evicted).
  NetworkCallEntry? byId(String id) {
    for (final NetworkCallEntry entry in _entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// Removes every entry.
  void clear() {
    _entries.clear();
    _notify();
  }

  /// Stops listening to the event bus and closes the [watch] stream.
  /// Safe to call multiple times.
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _updates.close();
  }

  void _onEvent(JalaEvent event) {
    switch (event) {
      case final NetworkRequestEvent e:
        _onRequest(e);
      case final NetworkResponseEvent e:
        _onResponse(e);
      case final NetworkErrorEvent e:
        _onError(e);
      case final NetworkCancelEvent e:
        _onCancel(e);
      case final NetworkProgressEvent e:
        _onProgress(e);
    }
    _notify();
  }

  void _onRequest(NetworkRequestEvent e) {
    final NetworkCallEntry entry = NetworkCallEntry(
      id: e.callId,
      startTime: e.timestamp,
      method: e.method.toUpperCase(),
      uri: e.uri,
      requestHeaders: e.headers,
      requestBody: e.body,
      responseHeaders: const <String, String>{},
      responseBody: CapturedBody.none,
      status: JalaCallStatus.pending,
      client: e.client,
      requestSize: e.size,
      replayOf: e.replayOf,
      mockRuleId: e.mockRuleId,
    );
    _entries.insert(0, entry);
    _enforceCapacity();
  }

  void _onResponse(NetworkResponseEvent e) {
    final int index = _entries.indexWhere((entry) => entry.id == e.callId);
    if (index == -1) return; // evicted or unknown; ignore per spec.
    final NetworkCallEntry updated = _entries[index].copyWith(
      statusCode: e.statusCode,
      statusMessage: e.statusMessage,
      responseHeaders: e.headers,
      responseBody: e.body,
      duration: e.duration,
      responseSize: e.size,
      status: JalaCallStatus.success,
    );
    _entries[index] = updated;
  }

  void _onError(NetworkErrorEvent e) {
    final int index = _entries.indexWhere((entry) => entry.id == e.callId);
    if (index == -1) return;
    final NetworkCallEntry current = _entries[index];
    final NetworkCallEntry updated = current.copyWith(
      statusCode: e.statusCode ?? current.statusCode,
      responseHeaders: e.headers ?? current.responseHeaders,
      responseBody: e.body ?? current.responseBody,
      duration: e.duration,
      status: JalaCallStatus.error,
      errorMessage: e.errorMessage,
    );
    _entries[index] = updated;
  }

  void _onCancel(NetworkCancelEvent e) {
    final int index = _entries.indexWhere((entry) => entry.id == e.callId);
    if (index == -1) return;
    _entries[index] = _entries[index].copyWith(
      status: JalaCallStatus.cancelled,
    );
  }

  void _onProgress(NetworkProgressEvent e) {
    final int index = _entries.indexWhere((entry) => entry.id == e.callId);
    if (index == -1) return; // evicted or unknown; ignore per spec.
    _entries[index] = _entries[index].copyWith(progress: e);
  }

  void _enforceCapacity() {
    while (_entries.length > maxEntries) {
      final int completedIndex = _entries.lastIndexWhere(
        (entry) => entry.status != JalaCallStatus.pending,
      );
      if (completedIndex != -1) {
        _entries.removeAt(completedIndex);
      } else {
        _entries.removeLast(); // oldest pending
      }
    }
  }

  void _notify() {
    if (_updates.isClosed) return;
    _updates.add(List.unmodifiable(_entries));
  }
}
