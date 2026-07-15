/// Formatting helpers shared by Jala UI widgets.
library;

/// Humanizes a byte count as `B`/`KB`/`MB`. Returns `--` when [bytes] is
/// null.
String humanizeBytes(int? bytes) {
  if (bytes == null) return '--';
  if (bytes < 1024) return '$bytes B';
  final double kb = bytes / 1024;
  if (kb < 1024) {
    return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
  }
  final double mb = kb / 1024;
  return '${mb.toStringAsFixed(mb < 10 ? 2 : 1)} MB';
}

/// Humanizes a [Duration] in milliseconds. Returns `--` when [duration] is
/// null.
String humanizeDuration(Duration? duration) {
  if (duration == null) return '--';
  return '${duration.inMilliseconds} ms';
}
