import 'package:flutter/material.dart';
import 'package:jala_core/jala_core.dart';

import '../theme/jala_theme.dart';
import '../util/format.dart';
import 'jala_method_chip.dart';

/// One row of the merged inspector list for a captured WebSocket
/// connection: a `WS` chip, uri (host as secondary line), a live status
/// indicator, and frame count + last-activity time.
///
/// Mirrors [JalaCallListTile]'s layout so the two tile kinds read as one
/// coherent list (see docs/plans/track-d-v0.4.md D4).
class JalaWsListTile extends StatelessWidget {
  /// Creates a list tile for [entry].
  const JalaWsListTile({required this.entry, super.key, this.onTap});

  /// The WebSocket connection this tile represents.
  final WsConnectionEntry entry;

  /// Invoked when the tile is tapped (typically opens the WS detail
  /// screen).
  final VoidCallback? onTap;

  String _statusText() {
    switch (entry.status) {
      case WsConnectionStatus.connecting:
        return 'connecting';
      case WsConnectionStatus.open:
        return 'open';
      case WsConnectionStatus.closed:
        return 'closed';
      case WsConnectionStatus.error:
        return 'error';
    }
  }

  /// The most recent point of activity on this connection: the last
  /// frame's timestamp when any frame has been observed, otherwise when the
  /// connection closed/errored, otherwise when it was opened.
  DateTime get _lastActivity {
    if (entry.frames.isNotEmpty) return entry.frames.last.timestamp;
    return entry.closedAt ?? entry.openedAt;
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return ListTile(
      onTap: onTap,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _JalaWsStatusDot(status: entry.status),
          const SizedBox(width: 8),
          const JalaMethodChip(method: 'WS'),
        ],
      ),
      title: Text(
        entry.uri.path.isEmpty ? entry.uri.toString() : entry.uri.path,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        entry.uri.host,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(_statusText(), style: textTheme.bodySmall),
          Text(
            '${entry.frameCount} '
            '${entry.frameCount == 1 ? 'frame' : 'frames'} · '
            '${humanizeClockTime(_lastActivity)}',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// A small dot colored by [status] (see [JalaTheme.wsStatusColorFor]); while
/// `connecting`, an indeterminate spinner instead — mirrors
/// [JalaStatusIndicator]'s pending-spinner convention for network calls.
class _JalaWsStatusDot extends StatelessWidget {
  const _JalaWsStatusDot({required this.status});

  final WsConnectionStatus status;

  /// Diameter of the dot/spinner; matches [JalaStatusIndicator]'s default.
  static const double size = 12;

  @override
  Widget build(BuildContext context) {
    if (status == WsConnectionStatus.connecting) {
      return const SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: JalaTheme.wsStatusColorFor(status),
        shape: BoxShape.circle,
      ),
    );
  }
}
