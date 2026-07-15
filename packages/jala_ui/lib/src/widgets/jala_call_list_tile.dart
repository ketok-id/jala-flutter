import 'package:flutter/material.dart';
import 'package:jala_core/jala_core.dart';

import '../util/format.dart';
import 'jala_method_chip.dart';
import 'jala_status_indicator.dart';

/// One row of the call list: method chip, status indicator, path (host as
/// secondary), status code, duration, response size, and a replay badge
/// when applicable.
class JalaCallListTile extends StatelessWidget {
  /// Creates a list tile for [entry].
  const JalaCallListTile({required this.entry, super.key, this.onTap});

  /// The entry this tile represents.
  final NetworkCallEntry entry;

  /// Invoked when the tile is tapped (typically opens the detail screen).
  final VoidCallback? onTap;

  String _statusText() {
    switch (entry.status) {
      case JalaCallStatus.pending:
        return 'pending';
      case JalaCallStatus.cancelled:
        return 'cancelled';
      case JalaCallStatus.error:
        return entry.statusCode != null ? '${entry.statusCode}' : 'error';
      case JalaCallStatus.success:
        return '${entry.statusCode}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Uri uri = entry.uri;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return ListTile(
      onTap: onTap,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          JalaStatusIndicator(entry: entry),
          const SizedBox(width: 8),
          JalaMethodChip(method: entry.method),
        ],
      ),
      title: Text(
        uri.path.isEmpty ? '/' : uri.path,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(uri.host, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (entry.replayOf != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.replay,
                    size: 14,
                    color: textTheme.bodySmall?.color,
                  ),
                ),
              Text(_statusText(), style: textTheme.bodySmall),
            ],
          ),
          Text(
            '${humanizeDuration(entry.duration)} · '
            '${humanizeBytes(entry.responseSize)}',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
