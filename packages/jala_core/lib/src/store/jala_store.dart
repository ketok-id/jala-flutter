import 'dart:async';

import '../event/jala_event.dart';
import '../event/jala_event_bus.dart';
import '../model/captured_body.dart';
import '../model/jala_call_status.dart';
import '../model/network_call_entry.dart';
import '../model/ws_connection_entry.dart';
import '../model/ws_frame.dart';

/// An in-memory ring buffer of [NetworkCallEntry] (plus a parallel one of
/// [WsConnectionEntry]) built by correlating [JalaEvent]s from a
/// [JalaEventBus].
///
/// Entries are ordered newest-first. Once [entries] would exceed
/// [maxEntries], the oldest *completed* entry (success/error/cancelled) is
/// evicted first; only once there are no completed entries left does the
/// oldest *pending* entry get evicted. Events for an id that has already
/// been evicted (or was never seen) are silently ignored.
///
/// WebSocket connections (see [wsConnections]) are a separate collection
/// with independent capacity/eviction rules — they are never merged into
/// [entries]; see docs/plans/track-d-v0.4.md D1.
class JalaStore {
  JalaStore({
    required JalaEventBus bus,
    this.maxEntries = 300,
    this.maxWsConnections = 20,
    this.maxWsFramesPerConnection = 200,
  }) {
    _subscription = bus.events.listen(_onEvent);
  }

  /// Maximum number of entries retained before eviction kicks in.
  final int maxEntries;

  /// Maximum number of WebSocket connections retained before eviction
  /// kicks in.
  final int maxWsConnections;

  /// Maximum number of frames retained per WebSocket connection.
  final int maxWsFramesPerConnection;

  StreamSubscription<JalaEvent>? _subscription;

  // Newest-first.
  final List<NetworkCallEntry> _entries = <NetworkCallEntry>[];

  final StreamController<List<NetworkCallEntry>> _updates =
      StreamController<List<NetworkCallEntry>>.broadcast();

  // Newest-first.
  final List<WsConnectionEntry> _wsConnections = <WsConnectionEntry>[];

  final StreamController<List<WsConnectionEntry>> _wsUpdates =
      StreamController<List<WsConnectionEntry>>.broadcast();

  /// Current entries, newest first. A fresh unmodifiable snapshot.
  List<NetworkCallEntry> get entries => List.unmodifiable(_entries);

  /// Current WebSocket connections, newest first. A fresh unmodifiable
  /// snapshot.
  List<WsConnectionEntry> get wsConnections =>
      List.unmodifiable(_wsConnections);

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

  /// Emits a fresh snapshot of [wsConnections] on every change, and
  /// immediately replays the current snapshot to each new listener.
  /// Mirrors [watch].
  late final Stream<List<WsConnectionEntry>> watchWs =
      Stream<List<WsConnectionEntry>>.multi((controller) {
        controller.add(List.unmodifiable(_wsConnections));
        final StreamSubscription<List<WsConnectionEntry>> sub = _wsUpdates
            .stream
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

  /// Looks up a WebSocket connection by its id. Returns null if absent
  /// (never seen, or already evicted).
  WsConnectionEntry? wsById(String id) {
    for (final WsConnectionEntry entry in _wsConnections) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// Removes every entry (both [entries] and [wsConnections]).
  void clear() {
    _entries.clear();
    _wsConnections.clear();
    _notify();
    _notifyWs();
  }

  /// Stops listening to the event bus and closes the [watch]/[watchWs]
  /// streams. Safe to call multiple times.
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _updates.close();
    await _wsUpdates.close();
  }

  void _onEvent(JalaEvent event) {
    switch (event) {
      case final NetworkRequestEvent e:
        _onRequest(e);
        _notify();
      case final NetworkResponseEvent e:
        _onResponse(e);
        _notify();
      case final NetworkErrorEvent e:
        _onError(e);
        _notify();
      case final NetworkCancelEvent e:
        _onCancel(e);
        _notify();
      case final NetworkProgressEvent e:
        _onProgress(e);
        _notify();
      case final WsConnectEvent e:
        _onWsConnect(e);
        _notifyWs();
      case final WsOpenEvent e:
        _onWsOpen(e);
        _notifyWs();
      case final WsFrameEvent e:
        _onWsFrame(e);
        _notifyWs();
      case final WsCloseEvent e:
        _onWsClose(e);
        _notifyWs();
      case final WsErrorEvent e:
        _onWsError(e);
        _notifyWs();
    }
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
      operationName: e.operationName,
      operationType: e.operationType,
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

  void _onWsConnect(WsConnectEvent e) {
    final WsConnectionEntry entry = WsConnectionEntry(
      id: e.connectionId,
      uri: e.uri,
      status: WsConnectionStatus.connecting,
      openedAt: e.timestamp,
      frameCount: 0,
      frames: const <WsFrame>[],
    );
    _wsConnections.insert(0, entry);
    _enforceWsCapacity();
  }

  void _onWsOpen(WsOpenEvent e) {
    final int index = _wsConnections.indexWhere(
      (entry) => entry.id == e.connectionId,
    );
    if (index == -1) return; // evicted or unknown; ignore per spec.
    final WsConnectionEntry current = _wsConnections[index];
    if (current.status != WsConnectionStatus.connecting) {
      return; // already open/closed/error — never downgrade a terminal
      // state, and promoting an already-open entry again is a no-op.
    }
    _wsConnections[index] = current.copyWith(status: WsConnectionStatus.open);
  }

  void _onWsFrame(WsFrameEvent e) {
    final int index = _wsConnections.indexWhere(
      (entry) => entry.id == e.connectionId,
    );
    if (index == -1) return; // evicted or unknown; ignore per spec.
    final WsConnectionEntry current = _wsConnections[index];
    final List<WsFrame> frames = List<WsFrame>.of(current.frames)
      ..add(e.frame);
    if (frames.length > maxWsFramesPerConnection) {
      frames.removeAt(0); // oldest frame falls out of the ring buffer.
    }
    _wsConnections[index] = current.copyWith(
      status: current.status == WsConnectionStatus.connecting
          ? WsConnectionStatus.open
          : current.status,
      frameCount: current.frameCount + 1,
      frames: List.unmodifiable(frames),
    );
  }

  void _onWsClose(WsCloseEvent e) {
    final int index = _wsConnections.indexWhere(
      (entry) => entry.id == e.connectionId,
    );
    if (index == -1) return; // evicted or unknown; ignore per spec.
    _wsConnections[index] = _wsConnections[index].copyWith(
      status: WsConnectionStatus.closed,
      closedAt: e.timestamp,
      closeCode: e.code,
      closeReason: e.reason,
    );
  }

  void _onWsError(WsErrorEvent e) {
    final int index = _wsConnections.indexWhere(
      (entry) => entry.id == e.connectionId,
    );
    if (index == -1) return; // evicted or unknown; ignore per spec.
    _wsConnections[index] = _wsConnections[index].copyWith(
      status: WsConnectionStatus.error,
      closedAt: e.timestamp,
      closeReason: e.errorMessage,
    );
  }

  void _enforceWsCapacity() {
    while (_wsConnections.length > maxWsConnections) {
      // Oldest-closed (or errored — both terminal states) evicted first;
      // only once none remain do we fall back to the oldest connection
      // overall, regardless of live status. Mirrors `_enforceCapacity`.
      final int terminalIndex = _wsConnections.lastIndexWhere(
        (entry) =>
            entry.status == WsConnectionStatus.closed ||
            entry.status == WsConnectionStatus.error,
      );
      if (terminalIndex != -1) {
        _wsConnections.removeAt(terminalIndex);
      } else {
        _wsConnections.removeLast(); // oldest overall (connecting/open)
      }
    }
  }

  void _notify() {
    if (_updates.isClosed) return;
    _updates.add(List.unmodifiable(_entries));
  }

  void _notifyWs() {
    if (_wsUpdates.isClosed) return;
    _wsUpdates.add(List.unmodifiable(_wsConnections));
  }
}
