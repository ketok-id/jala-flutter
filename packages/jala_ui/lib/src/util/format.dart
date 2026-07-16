/// Formatting helpers shared by Jala UI widgets.
library;

import 'package:jala_core/jala_core.dart';

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

/// Formats [dt] as a local `HH:mm:ss` clock time (zero-padded) — compact
/// enough for a list tile's trailing label (see `JalaWsListTile`'s
/// last-activity time).
String humanizeClockTime(DateTime dt) {
  final DateTime local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

/// Formats the elapsed time from [start] to [at] as a short, "+"-prefixed
/// duration label (e.g. `+120ms`, `+1.4s`) — used to anchor a WebSocket
/// frame timeline to its connection's `openedAt`.
String humanizeElapsed(DateTime start, DateTime at) {
  final int ms = at.difference(start).inMilliseconds;
  if (ms < 1000) return '+${ms}ms';
  final double secs = ms / 1000;
  return '+${secs.toStringAsFixed(secs < 10 ? 2 : 1)}s';
}

/// The overall completion fraction (0.0–1.0) for [progress], or null when
/// no total is known yet — callers should fall back to an indeterminate
/// indicator in that case.
///
/// Prefers the response side once its total is known (a call is, from the
/// UI's perspective, "mostly" a download): falls back to the request side
/// otherwise. Either side being 0/null just means that side hasn't been (or
/// can't be) measured for this call — see `NetworkProgressEvent`.
double? progressFraction(NetworkProgressEvent? progress) {
  if (progress == null) return null;
  final int? receivedTotal = progress.receivedTotal;
  if (receivedTotal != null && receivedTotal > 0) {
    return (progress.receivedBytes / receivedTotal).clamp(0.0, 1.0);
  }
  final int? sentTotal = progress.sentTotal;
  if (sentTotal != null && sentTotal > 0) {
    return (progress.sentBytes / sentTotal).clamp(0.0, 1.0);
  }
  return null;
}
