import 'package:flutter/services.dart';

/// Where a session/HAR export is delivered.
///
/// Exports used to go straight to the clipboard with no error handling and
/// an unconditional "copied" snackbar, so an oversized payload reported
/// success while delivering nothing — on Android the clipboard rides the
/// Binder transaction buffer (~1 MB, shared process-wide), and a full
/// session export routinely exceeds it. A sink lets the host swap in a
/// destination that has no such ceiling (a file, a share sheet) without
/// `jala_ui` taking a `dart:io` or plugin dependency.
///
/// Install one via [JalaExportSink.install]; `package:jala` ships a
/// file-backed sink (`Jala.enableFileExport`).
abstract class JalaExportSink {
  /// Creates a sink.
  const JalaExportSink();

  /// Payload size above which the Android clipboard is unreliable. Android's
  /// Binder transaction buffer is ~1 MB for *all* in-flight transactions in
  /// the process, so a payload approaching it can fail — sometimes silently,
  /// sometimes as a partial write. Warn well below the hard ceiling.
  static const int clipboardWarnBytes = 512 * 1024;

  /// The active sink. Defaults to [JalaClipboardExportSink].
  static JalaExportSink get instance => _instance;
  static JalaExportSink _instance = const JalaClipboardExportSink();

  /// Replaces the active sink. Pass null to restore the clipboard default.
  static void install(JalaExportSink? sink) {
    _instance = sink ?? const JalaClipboardExportSink();
  }

  /// Delivers [payload]. [fileName] is a suggested name for sinks that
  /// persist (ignored by the clipboard). Must not throw — failures come
  /// back as an unsuccessful [JalaExportOutcome] so the UI can report them.
  Future<JalaExportOutcome> deliver({
    required String payload,
    required String fileName,
  });
}

/// What happened to an export, and what to tell the user.
class JalaExportOutcome {
  /// Creates an outcome.
  const JalaExportOutcome({
    required this.ok,
    required this.bytes,
    required this.destination,
    this.error,
  });

  /// Whether the payload was delivered.
  final bool ok;

  /// Size of the payload in bytes (UTF-16 code units — close enough for a
  /// size warning, and free to compute).
  final int bytes;

  /// Human-readable destination, e.g. `clipboard` or a file path.
  final String destination;

  /// Failure cause when [ok] is false.
  final Object? error;

  /// Whether the payload is large enough that the clipboard may drop it.
  bool get isRisky => bytes >= JalaExportSink.clipboardWarnBytes;

  /// Rounded size for display.
  String get sizeLabel {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Default sink: copies to the system clipboard.
class JalaClipboardExportSink extends JalaExportSink {
  /// Creates a clipboard sink.
  const JalaClipboardExportSink();

  @override
  Future<JalaExportOutcome> deliver({
    required String payload,
    required String fileName,
  }) async {
    final int bytes = payload.length;
    try {
      await Clipboard.setData(ClipboardData(text: payload));
      return JalaExportOutcome(
        ok: true,
        bytes: bytes,
        destination: 'clipboard',
      );
    } on Object catch (e) {
      // Android throws TransactionTooLargeException through the platform
      // channel once the payload outgrows the Binder buffer. Never let an
      // export failure escape into the host app.
      return JalaExportOutcome(
        ok: false,
        bytes: bytes,
        destination: 'clipboard',
        error: e,
      );
    }
  }
}
