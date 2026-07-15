import 'package:flutter/material.dart';
import 'package:ketok_core/ketok_core.dart';

import '../util/format.dart';
import 'ketok_method_chip.dart';
import 'ketok_status_indicator.dart';

/// One row of the call list: method chip, status indicator, path (host as
/// secondary), status code, duration, response size, and a replay badge
/// when applicable.
class KetokCallListTile extends StatelessWidget {
  /// Creates a list tile for [entry].
  const KetokCallListTile({required this.entry, super.key, this.onTap});

  /// The entry this tile represents.
  final NetworkCallEntry entry;

  /// Invoked when the tile is tapped (typically opens the detail screen).
  final VoidCallback? onTap;

  String _statusText() {
    switch (entry.status) {
      case KetokCallStatus.pending:
        return 'pending';
      case KetokCallStatus.cancelled:
        return 'cancelled';
      case KetokCallStatus.error:
        return entry.statusCode != null ? '${entry.statusCode}' : 'error';
      case KetokCallStatus.success:
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
          KetokStatusIndicator(entry: entry),
          const SizedBox(width: 8),
          KetokMethodChip(method: entry.method),
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
