import 'package:jala_ui/jala_ui.dart';

/// Stub for platforms without `dart:io` (e.g. web), where there is no file
/// system to export to.
///
/// Falls back to the clipboard rather than failing: on web the clipboard has
/// no Binder-style ceiling, so it is a perfectly good destination, and a
/// host that called `enableFileExport` still gets a working export. The
/// destination string says plainly that no file was written.
class FileJalaExportSink extends JalaExportSink {
  /// Creates a clipboard-backed sink. [directory] is ignored on this
  /// platform.
  const FileJalaExportSink(this.directory);

  /// Ignored on this platform.
  final String directory;

  @override
  Future<JalaExportOutcome> deliver({
    required String payload,
    required String fileName,
  }) async {
    final bool ok = await jalaCopyToClipboard(payload);
    return JalaExportOutcome(
      ok: ok,
      bytes: payload.length,
      destination: 'clipboard (no file system on this platform)',
      error: ok ? null : UnsupportedError('Clipboard write failed.'),
    );
  }
}
