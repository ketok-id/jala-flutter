import 'dart:io';

import 'package:jala_ui/jala_ui.dart';

/// Writes exports to a directory on disk (`dart:io` platforms), **and still
/// copies to the clipboard whenever the payload is small enough to survive
/// it**.
///
/// The clipboard is the default export destination, but it has a hard
/// ceiling on Android (~1 MB Binder transaction buffer, shared across the
/// process) that a full session export clears easily. A file has no such
/// limit and, unlike the clipboard, gives testers something they can pull
/// off the device with `adb pull` and attach to a bug report.
///
/// Writing to the file *instead of* the clipboard would break the workflow
/// the clipboard exists for — QA pasting a session straight into a ticket
/// or chat. So this sink does both: the file is the durable copy and always
/// written, and the clipboard is attempted as well below
/// [JalaExportSink.clipboardWarnBytes]. Above that the clipboard is skipped
/// rather than attempted-and-failed, because that is exactly the size range
/// where it silently drops the payload.
class FileJalaExportSink extends JalaExportSink {
  /// Creates a sink writing into [directory].
  const FileJalaExportSink(this.directory);

  /// Directory exports are written to. Created on demand.
  final String directory;

  @override
  Future<JalaExportOutcome> deliver({
    required String payload,
    required String fileName,
  }) async {
    final int bytes = payload.length;
    final bool alsoCopied = bytes < JalaExportSink.clipboardWarnBytes &&
        await jalaCopyToClipboard(payload);
    try {
      final Directory parent = Directory(directory);
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }
      // Timestamp the name so repeated exports in one session don't clobber
      // each other — testers routinely export several times per bug.
      final String stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(RegExp(r'[:.]'), '-');
      final int dot = fileName.lastIndexOf('.');
      final String stamped = dot <= 0
          ? '$fileName-$stamp'
          : '${fileName.substring(0, dot)}-$stamp${fileName.substring(dot)}';
      final File file = File('$directory${Platform.pathSeparator}$stamped');
      await file.writeAsString(payload);
      return JalaExportOutcome(
        ok: true,
        bytes: bytes,
        destination: alsoCopied ? 'clipboard + ${file.path}' : file.path,
      );
    } on Object catch (e) {
      // Capture invariants forbid letting a Jala failure reach the host.
      // The clipboard copy may still have succeeded — say so rather than
      // reporting a total loss, since it is the pasteable one.
      if (alsoCopied) {
        return JalaExportOutcome(
          ok: true,
          bytes: bytes,
          destination: 'clipboard (file write failed: $e)',
        );
      }
      return JalaExportOutcome(
        ok: false,
        bytes: bytes,
        destination: directory,
        error: e,
      );
    }
  }
}
