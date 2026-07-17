import '../model/network_call_entry.dart';
import '../model/ws_connection_entry.dart';

/// A decoded snapshot produced by `JalaSessionCodec.decode` — the
/// in-memory counterpart of the versioned JSON envelope written by
/// `JalaSessionCodec.encode` (see docs/plans/track-e-v0.5.md E1).
class JalaSession {
  /// Creates a session snapshot.
  const JalaSession({
    required this.version,
    required this.exportedAt,
    required this.entries,
    required this.wsConnections,
  });

  /// The envelope version this session was decoded from (see
  /// `JalaSessionCodec.currentVersion`).
  final int version;

  /// When the session was exported (`JalaSessionCodec.encode` time), not
  /// when it was later imported.
  final DateTime exportedAt;

  /// Captured network calls, in the same order as `JalaStore.entries`
  /// (newest first) at export time.
  final List<NetworkCallEntry> entries;

  /// Captured WebSocket connections, in the same order as
  /// `JalaStore.wsConnections` at export time.
  final List<WsConnectionEntry> wsConnections;
}

/// Thrown by `JalaSessionCodec.decode` for anything that isn't a
/// well-formed, understood Jala session — malformed JSON, a missing or
/// wrong format marker, an unsupported version, or any other parsing
/// failure. `JalaSessionCodec.decode` never throws any other exception
/// type, so callers (e.g. the import dialog in `jala_ui`) only ever need
/// to catch this one type to show a friendly error.
class JalaSessionFormatException implements Exception {
  /// Creates the exception with a human-readable [message].
  const JalaSessionFormatException(this.message);

  /// Explains what was wrong with the input.
  final String message;

  @override
  String toString() => 'JalaSessionFormatException: $message';
}
