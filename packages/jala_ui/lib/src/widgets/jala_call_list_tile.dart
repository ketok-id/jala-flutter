import 'package:flutter/material.dart';
import 'package:jala_core/jala_core.dart';

import '../theme/jala_theme.dart';
import '../util/clipboard.dart';
import '../util/format.dart';
import 'jala_method_chip.dart';
import 'jala_status_indicator.dart';

/// One row of the call list: method chip, status indicator, path (host as
/// secondary), status code, duration, response size, and a replay badge
/// when applicable.
class JalaCallListTile extends StatelessWidget {
  /// Creates a list tile for [entry].
  const JalaCallListTile({
    required this.entry,
    super.key,
    this.onTap,
    this.dense = false,
  });

  /// The entry this tile represents.
  final NetworkCallEntry entry;

  /// Invoked when the tile is tapped (typically opens the detail screen).
  final VoidCallback? onTap;

  /// Tighter vertical padding when the inspector list is in compact mode.
  final bool dense;

  String _statusText() {
    // A gRPC call always reports HTTP 200, so the useful status is its gRPC
    // code — shown by name (`NOT_FOUND`), which is how gRPC tooling and
    // error messages refer to it.
    final int? grpcCode = entry.grpcStatusCode;
    if (grpcCode != null) return JalaGrpcStatus.nameOf(grpcCode);
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

  /// `pkg.Service/Method` from a gRPC path, for the primary line.
  static String grpcLabel(Uri uri) {
    final String path = uri.path.startsWith('/')
        ? uri.path.substring(1)
        : uri.path;
    return path.isEmpty ? '/' : path;
  }

  /// Path (+ query) for the primary line — what developers scan for.
  static String pathLabel(Uri uri) {
    final String path = uri.path.isEmpty ? '/' : uri.path;
    if (uri.hasQuery && uri.query.isNotEmpty) {
      return '$path?${uri.query}';
    }
    return path;
  }

  Future<void> _copyUrl(BuildContext context) async {
    final String url = entry.uri.toString();
    final bool ok = await jalaCopyToClipboard(url);
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(jalaCopyMessage(ok: ok, label: 'URL', text: url)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Uri uri = entry.uri;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String? operationName = entry.operationName;
    final String? rpcKind = entry.rpcKind;
    final bool isGrpc = rpcKind != null;
    // gRPC entries also carry `operationName` (the method), but they get
    // their own presentation, so the GraphQL branch must not claim them.
    final bool isGraphQl = !isGrpc && operationName != null;
    final bool isOperation = isGrpc || isGraphQl;
    final String chipLabel = isGrpc
        ? rpcKind.toUpperCase()
        : (isGraphQl
              ? (entry.operationType?.toUpperCase() ?? entry.method)
              : entry.method);
    final String titleText = isGrpc
        ? grpcLabel(uri)
        : (isGraphQl ? operationName : pathLabel(uri));
    final bool longTitle = titleText.length > 36;
    final Color statusColor = JalaTheme.statusColorFor(entry);

    return ListTile(
      onTap: onTap,
      onLongPress: () => _copyUrl(context),
      dense: dense,
      visualDensity: dense
          ? VisualDensity.compact
          : VisualDensity.standard,
      isThreeLine: !dense && longTitle && !isOperation,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          JalaStatusIndicator(entry: entry),
          const SizedBox(width: 8),
          JalaMethodChip(method: chipLabel),
        ],
      ),
      title: Text(
        titleText,
        maxLines: isOperation || dense ? 1 : 2,
        overflow: TextOverflow.ellipsis,
        style: textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          // gRPC paths read as code, like URLs — GraphQL operation names
          // are prose-ish identifiers and stay in the body font.
          fontFamily: isGraphQl ? null : 'monospace',
          fontSize: isGraphQl ? null : (dense ? 12 : 13),
          height: 1.25,
        ),
      ),
      subtitle: Text(
        isGraphQl ? '${uri.host}${uri.path}' : uri.host,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontSize: dense ? 11 : null,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (entry.mockRuleId != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Tooltip(
                    message: 'Mocked',
                    child: Icon(
                      Icons.bolt,
                      size: 14,
                      color: textTheme.bodySmall?.color,
                    ),
                  ),
                ),
              if (entry.replayOf != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.replay,
                    size: 14,
                    color: textTheme.bodySmall?.color,
                  ),
                ),
              // Confirms per call that a throttle profile actually applied.
              // The inspector's throttle banner only says a profile is
              // active — not whether it touched this request (it may be
              // scoped to a host glob this call didn't match).
              if (entry.throttledBy != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Tooltip(
                    message: 'Throttled by ${entry.throttledBy}',
                    child: Icon(
                      Icons.speed,
                      size: 14,
                      color: textTheme.bodySmall?.color,
                    ),
                  ),
                ),
              Text(
                _statusText(),
                style: textTheme.bodySmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Text(
            '${humanizeDuration(entry.duration)} · '
            '${humanizeRelativeTime(entry.startTime)}',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: dense ? 10 : null,
            ),
          ),
        ],
      ),
    );
  }
}
