import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jala_core/jala_core.dart';

import '../theme/jala_theme.dart';
import '../util/format.dart';
import '../widgets/jala_json_tree.dart';
import '../widgets/jala_themed_page.dart';

/// Detail screen for a single captured WebSocket connection: a header
/// (uri, status, open/close times, close code/reason, frame count) and a
/// frame timeline with a substring filter.
///
/// Re-watches `JalaBinding.instance.store.watchWs` so a still-open
/// connection updates live as new frames/close/error events arrive.
///
/// Unlike [JalaCallDetailScreen], there are no cURL/Dart/HAR/Replay actions
/// here — none of those are representable for a WebSocket connection (see
/// docs/plans/track-d-v0.4.md D4). The only actions are copying a single
/// frame's preview and copying a JSON summary of the whole connection.
class JalaWsDetailScreen extends StatefulWidget {
  /// Creates the detail screen for the connection identified by
  /// [connectionId].
  const JalaWsDetailScreen({required this.connectionId, super.key});

  /// The id of the [WsConnectionEntry] to display.
  final String connectionId;

  /// Builds a route pushing the detail screen for [connectionId].
  static Route<void> route(String connectionId) {
    return MaterialPageRoute<void>(
      builder: (BuildContext context) =>
          JalaWsDetailScreen(connectionId: connectionId),
    );
  }

  @override
  State<JalaWsDetailScreen> createState() => _JalaWsDetailScreenState();
}

class _JalaWsDetailScreenState extends State<JalaWsDetailScreen> {
  final TextEditingController _frameFilterController = TextEditingController();
  String _frameFilter = '';

  @override
  void dispose() {
    _frameFilterController.dispose();
    super.dispose();
  }

  Future<void> _copy(BuildContext context, String label, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Copied $label')));
  }

  String _summaryJson(WsConnectionEntry entry) {
    final Map<String, dynamic> summary = <String, dynamic>{
      'uri': entry.uri.toString(),
      'status': entry.status.name,
      'openedAt': entry.openedAt.toIso8601String(),
      'closedAt': entry.closedAt?.toIso8601String(),
      'closeCode': entry.closeCode,
      'closeReason': entry.closeReason,
      'frameCount': entry.frameCount,
      'frames': <Map<String, dynamic>>[
        for (final WsFrame frame in entry.frames)
          <String, dynamic>{
            'timestamp': frame.timestamp.toIso8601String(),
            'direction': frame.direction.name,
            'isBinary': frame.isBinary,
            'size': frame.size,
          },
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(summary);
  }

  void _showFramePreview(BuildContext context, WsFrame frame) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext _) => _FramePreviewSheet(
        frame: frame,
        onCopy: () => _copy(context, 'frame preview', frame.preview ?? ''),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return JalaThemedPage(
      child: StreamBuilder<List<WsConnectionEntry>>(
        stream: JalaBinding.instance.store.watchWs,
        initialData: JalaBinding.instance.store.wsConnections,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<WsConnectionEntry>> snapshot,
            ) {
              final WsConnectionEntry? entry = JalaBinding.instance.store
                  .wsById(widget.connectionId);
              if (entry == null) {
                return Scaffold(
                  appBar: AppBar(title: const Text('WebSocket detail')),
                  body: const Center(
                    child: Text('This connection is no longer available.'),
                  ),
                );
              }

              final String query = _frameFilter.trim().toLowerCase();
              final List<WsFrame> frames = query.isEmpty
                  ? entry.frames
                  : entry.frames
                        .where(
                          (WsFrame f) =>
                              (f.preview ?? '').toLowerCase().contains(query),
                        )
                        .toList();

              return Scaffold(
                appBar: AppBar(
                  title: Text(
                    entry.uri.host.isEmpty
                        ? entry.uri.toString()
                        : entry.uri.host,
                    overflow: TextOverflow.ellipsis,
                  ),
                  actions: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.ios_share),
                      tooltip: 'Copy connection summary',
                      onPressed: () => _copy(
                        context,
                        'connection summary',
                        _summaryJson(entry),
                      ),
                    ),
                  ],
                ),
                body: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: _WsHeader(entry: entry),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: TextField(
                        controller: _frameFilterController,
                        onChanged: (String value) =>
                            setState(() => _frameFilter = value),
                        decoration: const InputDecoration(
                          hintText: 'Filter frames…',
                          prefixIcon: Icon(Icons.filter_alt_outlined),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    Expanded(
                      child: entry.frames.isEmpty
                          ? const _EmptyFrames(
                              message: 'No frames captured yet.',
                            )
                          : frames.isEmpty
                          ? _EmptyFrames(
                              message:
                                  'No frames match '
                                  '"${_frameFilterController.text}".',
                            )
                          : ListView.separated(
                              itemCount: frames.length,
                              separatorBuilder:
                                  (BuildContext context, int index) =>
                                      const Divider(height: 1),
                              itemBuilder: (BuildContext context, int index) {
                                final WsFrame frame = frames[index];
                                final bool hasPreview =
                                    !frame.isBinary && frame.preview != null;
                                return _WsFrameTile(
                                  frame: frame,
                                  openedAt: entry.openedAt,
                                  onTap: hasPreview
                                      ? () => _showFramePreview(context, frame)
                                      : null,
                                  onLongPress: hasPreview
                                      ? () => _copy(
                                          context,
                                          'frame preview',
                                          frame.preview!,
                                        )
                                      : null,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
      ),
    );
  }
}

class _WsHeader extends StatelessWidget {
  const _WsHeader({required this.entry});

  final WsConnectionEntry entry;

  String _statusLabel() {
    switch (entry.status) {
      case WsConnectionStatus.connecting:
        return 'Connecting…';
      case WsConnectionStatus.open:
        return 'Open';
      case WsConnectionStatus.closed:
        return 'Closed';
      case WsConnectionStatus.error:
        return 'Error';
    }
  }

  String _framesLabel() {
    if (entry.frameCount > entry.frames.length) {
      return '${entry.frameCount} (showing last ${entry.frames.length})';
    }
    return '${entry.frameCount}';
  }

  @override
  Widget build(BuildContext context) {
    final List<(String, Widget)> rows = <(String, Widget)>[
      ('URI', SelectableText(entry.uri.toString())),
      ('Status', Text(_statusLabel())),
      ('Opened', Text(entry.openedAt.toLocal().toString())),
      // "Closed at" (not "Closed") so the row label never collides with
      // the status value rendered just above.
      if (entry.closedAt != null)
        ('Closed at', Text(entry.closedAt!.toLocal().toString())),
      if (entry.closeCode != null) ('Close code', Text('${entry.closeCode}')),
      if (entry.closeReason != null) ('Close reason', Text(entry.closeReason!)),
      ('Frames', Text(_framesLabel())),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (String label, Widget value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 100,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Expanded(child: value),
              ],
            ),
          ),
      ],
    );
  }
}

class _WsFrameTile extends StatelessWidget {
  const _WsFrameTile({
    required this.frame,
    required this.openedAt,
    this.onTap,
    this.onLongPress,
  });

  final WsFrame frame;
  final DateTime openedAt;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final bool sent = frame.direction == WsDirection.sent;
    // Reuse the existing status-color palette rather than inventing new
    // colors: blue for sent (matches "open" WS status), green for received
    // (matches HTTP success) — distinct and theme-consistent.
    final Color color = sent ? JalaTheme.redirectColor : JalaTheme.successColor;
    final String arrow = sent ? '↑' : '↓';
    final String title = frame.isBinary
        ? 'binary — ${frame.size} bytes'
        : (frame.preview ?? '');
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: SizedBox(
        width: 24,
        child: Text(
          arrow,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
      subtitle: Text(humanizeElapsed(openedAt, frame.timestamp)),
      trailing: Text(humanizeBytes(frame.size)),
    );
  }
}

class _FramePreviewSheet extends StatelessWidget {
  const _FramePreviewSheet({required this.frame, required this.onCopy});

  final WsFrame frame;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final String text = frame.preview ?? '';
    Widget body;
    try {
      final dynamic decoded = jsonDecode(text);
      body = JalaJsonTree(data: decoded);
    } on FormatException {
      body = SelectableText(
        text,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      );
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Frame preview',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy frame preview',
                  onPressed: onCopy,
                ),
              ],
            ),
            const Divider(),
            Flexible(child: SingleChildScrollView(child: body)),
          ],
        ),
      ),
    );
  }
}

class _EmptyFrames extends StatelessWidget {
  const _EmptyFrames({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
