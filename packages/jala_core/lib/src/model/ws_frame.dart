import 'dart:convert';

import '../redact/jala_redactor.dart';

/// Direction of a captured WebSocket frame, relative to the app process
/// doing the capturing.
enum WsDirection {
  /// The app sent this frame to the server.
  sent,

  /// The app received this frame from the server.
  received,
}

/// An immutable, point-in-time snapshot of one WebSocket frame.
///
/// Instances are appended to a [WsConnectionEntry]'s per-connection ring
/// buffer by `JalaStore` as `WsFrameEvent`s arrive — see
/// `src/store/jala_store.dart`.
class WsFrame {
  /// Creates a frame snapshot. Callers normally reach this via [capture]
  /// (used by the `jala_websocket` binding); this constructor is exposed
  /// directly for tests and advanced callers that already have a
  /// pre-computed preview.
  const WsFrame({
    required this.timestamp,
    required this.direction,
    required this.isBinary,
    required this.size,
    this.preview,
  });

  /// Captures [data] (either decoded text or raw bytes, matching how
  /// `web_socket_channel` represents a frame) into a [WsFrame].
  ///
  /// - `String` -> a text frame; [preview] is [redactor]-redacted and
  ///   capped at [maxPreviewBytes].
  /// - `List<int>` (raw bytes, e.g. `Uint8List`) -> a binary frame;
  ///   [preview] is left null (metadata-only capture).
  /// - Anything else -> best-effort `toString()`, treated as text, so this
  ///   never throws for an unanticipated runtime type.
  factory WsFrame.capture({
    required DateTime timestamp,
    required WsDirection direction,
    required dynamic data,
    required JalaRedactor redactor,
  }) {
    if (data is List<int>) {
      return WsFrame(
        timestamp: timestamp,
        direction: direction,
        isBinary: true,
        size: data.length,
        preview: null,
      );
    }

    final String text = data is String ? data : data.toString();
    final int originalSize = utf8.encode(text).length;
    final String redacted = redactor.redactBody(text);
    return WsFrame(
      timestamp: timestamp,
      direction: direction,
      isBinary: false,
      size: originalSize,
      preview: _capPreview(redacted),
    );
  }

  /// Hard cap, in bytes, on [preview] text for a text frame. Mirrors the
  /// `CapturedBody` capture-cap philosophy, sized smaller than the default
  /// body cap because WebSocket frames tend to be small, high-frequency
  /// payloads (see docs/plans/track-d-v0.4.md D1).
  static const int maxPreviewBytes = 4 * 1024;

  /// When this frame was observed.
  final DateTime timestamp;

  /// Whether the app sent or received this frame.
  final WsDirection direction;

  /// Whether the frame payload is binary (as opposed to text).
  final bool isBinary;

  /// Size of the frame payload in bytes (the *original* size — never
  /// truncated by the [maxPreviewBytes] cap).
  final int size;

  /// Redacted, capped preview of a text frame's content.
  ///
  /// Null when [isBinary] is true — binary frames are metadata-only, the
  /// payload itself is never retained.
  final String? preview;

  static String _capPreview(String text) {
    final List<int> encoded = utf8.encode(text);
    if (encoded.length <= maxPreviewBytes) return text;
    final List<int> cut = encoded.sublist(0, maxPreviewBytes);
    return utf8.decode(cut, allowMalformed: true);
  }

  @override
  String toString() =>
      'WsFrame(direction: $direction, isBinary: $isBinary, size: $size)';
}
