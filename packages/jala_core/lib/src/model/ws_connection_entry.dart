import 'ws_frame.dart';

/// Sentinel used by [WsConnectionEntry.copyWith] so nullable fields can be
/// distinguished from "leave unchanged" (omitted) vs. "explicitly set to
/// null" — same pattern as `NetworkCallEntry.copyWith`.
const Object _unset = Object();

/// Lifecycle status of a captured WebSocket connection.
enum WsConnectionStatus {
  /// A connection attempt has started but is not yet confirmed live.
  connecting,

  /// At least one frame has been observed on this connection.
  open,

  /// The connection closed normally (`WsCloseEvent`).
  closed,

  /// The connection failed at the transport level (`WsErrorEvent`).
  error,
}

/// An immutable, point-in-time snapshot of one captured WebSocket
/// connection.
///
/// Instances are materialized and replaced (never mutated) by `JalaStore`
/// as connect/frame/close/error events for the same connection id arrive —
/// see `src/store/jala_store.dart`. WebSocket connections are a distinct
/// entity from `NetworkCallEntry`; they are not merged into one list type
/// in core (that happens, if at all, in the UI layer).
class WsConnectionEntry {
  /// Creates a new entry. Callers normally only construct the initial
  /// (connecting) entry directly; subsequent states are produced via
  /// [copyWith].
  const WsConnectionEntry({
    required this.id,
    required this.uri,
    required this.status,
    required this.openedAt,
    required this.frameCount,
    required this.frames,
    this.closedAt,
    this.closeCode,
    this.closeReason,
  });

  /// Process-unique id for this connection. Also the correlation key
  /// shared by every WS `JalaEvent` belonging to this connection (carried
  /// as `JalaEvent.callId` — see `WsConnectEvent.connectionId` and
  /// siblings).
  final String id;

  /// The full WebSocket URI (`ws://` or `wss://`).
  final Uri uri;

  /// Current lifecycle status of the connection.
  final WsConnectionStatus status;

  /// When the connection attempt started.
  final DateTime openedAt;

  /// When the connection closed or errored, or null while still
  /// connecting/open.
  final DateTime? closedAt;

  /// The close code reported by `WsCloseEvent`, if any.
  final int? closeCode;

  /// The close reason reported by `WsCloseEvent`, if any.
  ///
  /// SPEC-NOTE: also used to carry the error message when [status] is
  /// [WsConnectionStatus.error] — `WsConnectionEntry` has no separate
  /// `errorMessage` field in the D1 spec, and this is the only free-text
  /// field available for the UI to surface *why* a connection failed.
  final String? closeReason;

  /// Total number of frames ever observed on this connection — unlike
  /// [frames], this is never reduced by the per-connection ring-buffer
  /// eviction (`JalaConfig.maxWsFramesPerConnection`).
  final int frameCount;

  /// The most recent frames on this connection, oldest first, capped at
  /// `JalaConfig.maxWsFramesPerConnection`. An immutable snapshot list.
  final List<WsFrame> frames;

  /// Returns a copy of this entry with the given fields replaced.
  ///
  /// Nullable fields ([closedAt], [closeCode], [closeReason]) use an
  /// internal sentinel so that passing an explicit `null` clears the
  /// field, while omitting the argument entirely leaves the current value
  /// intact.
  WsConnectionEntry copyWith({
    String? id,
    Uri? uri,
    WsConnectionStatus? status,
    DateTime? openedAt,
    Object? closedAt = _unset,
    Object? closeCode = _unset,
    Object? closeReason = _unset,
    int? frameCount,
    List<WsFrame>? frames,
  }) {
    return WsConnectionEntry(
      id: id ?? this.id,
      uri: uri ?? this.uri,
      status: status ?? this.status,
      openedAt: openedAt ?? this.openedAt,
      closedAt: identical(closedAt, _unset)
          ? this.closedAt
          : closedAt as DateTime?,
      closeCode: identical(closeCode, _unset)
          ? this.closeCode
          : closeCode as int?,
      closeReason: identical(closeReason, _unset)
          ? this.closeReason
          : closeReason as String?,
      frameCount: frameCount ?? this.frameCount,
      frames: frames ?? this.frames,
    );
  }

  @override
  String toString() =>
      'WsConnectionEntry(id: $id, uri: $uri, status: $status, '
      'frameCount: $frameCount)';
}
