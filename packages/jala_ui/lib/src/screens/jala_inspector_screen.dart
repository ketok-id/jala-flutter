import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jala_core/jala_core.dart';

import '../theme/jala_theme_controller.dart';
import '../widgets/jala_call_list_tile.dart';
import '../widgets/jala_filter_help_sheet.dart';
import '../widgets/jala_themed_page.dart';
import '../widgets/jala_ws_list_tile.dart';
import 'jala_call_detail_screen.dart';
import 'jala_mocks_screen.dart';
import 'jala_throttle_screen.dart';
import 'jala_ws_detail_screen.dart';

/// Session actions offered from the inspector AppBar overflow menu (see
/// docs/plans/track-e-v0.5.md E3).
enum _SessionAction { export, import }

/// One row of the chronologically-interleaved merged list: either a
/// [NetworkCallEntry] or a [WsConnectionEntry], ordered newest-first by
/// [NetworkCallEntry.startTime] / [WsConnectionEntry.openedAt] (see
/// docs/plans/track-d-v0.4.md D4). `jala_core` deliberately keeps these two
/// entities in separate collections (`watch`/`watchWs`) — merging only
/// happens here, in the UI layer.
sealed class _MergedEntry {
  DateTime get time;
}

class _CallEntry extends _MergedEntry {
  _CallEntry(this.entry);

  final NetworkCallEntry entry;

  @override
  DateTime get time => entry.startTime;
}

class _WsEntry extends _MergedEntry {
  _WsEntry(this.entry);

  final WsConnectionEntry entry;

  @override
  DateTime get time => entry.openedAt;
}

List<_MergedEntry> _mergeEntries(
  List<NetworkCallEntry> calls,
  List<WsConnectionEntry> wsConnections,
) {
  final List<_MergedEntry> merged = <_MergedEntry>[
    for (final NetworkCallEntry e in calls) _CallEntry(e),
    for (final WsConnectionEntry e in wsConnections) _WsEntry(e),
  ];
  merged.sort((_MergedEntry a, _MergedEntry b) => b.time.compareTo(a.time));
  return merged;
}

/// Root screen of the Jala inspector: filter bar, call list, and app bar
/// actions (clear, copy session HAR, theme toggle).
class JalaInspectorScreen extends StatefulWidget {
  /// Creates the inspector screen.
  const JalaInspectorScreen({this.onClose, super.key});

  /// Called when the user taps the close button. When null, no close
  /// button is shown (e.g. when the screen is pushed on a host navigator
  /// that provides its own back affordance).
  final VoidCallback? onClose;

  @override
  State<JalaInspectorScreen> createState() => _JalaInspectorScreenState();
}

class _JalaInspectorScreenState extends State<JalaInspectorScreen> {
  final TextEditingController _filterController = TextEditingController();
  JalaFilter _filter = JalaFilter.parse('');
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _filterController.dispose();
    super.dispose();
  }

  void _onFilterChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      setState(() => _filter = JalaFilter.parse(value));
    });
  }

  Future<void> _confirmClear(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Clear all captured calls?'),
        content: const Text(
          'This removes every entry from the inspector. This cannot be '
          'undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      JalaBinding.instance.store.clear();
    }
  }

  Future<void> _copySessionHar(
    BuildContext context,
    List<NetworkCallEntry> entries,
  ) async {
    final String har = HarExporter.exportSession(entries);
    await Clipboard.setData(ClipboardData(text: har));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied HAR for ${entries.length} '
          '${entries.length == 1 ? 'call' : 'calls'}',
        ),
      ),
    );
  }

  Future<void> _exportSession(BuildContext context) async {
    final JalaStore store = JalaBinding.instance.store;
    final int count = store.entries.length;
    final String json = JalaSessionCodec.encode(store);
    await Clipboard.setData(ClipboardData(text: json));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Exported session — $count ${count == 1 ? 'entry' : 'entries'} '
          'copied to clipboard',
        ),
      ),
    );
  }

  Future<void> _importSession(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => const _ImportSessionDialog(),
    );
  }

  Future<void> _handleSessionAction(
    BuildContext context,
    _SessionAction action,
  ) async {
    switch (action) {
      case _SessionAction.export:
        await _exportSession(context);
      case _SessionAction.import:
        await _importSession(context);
    }
  }

  void _openHelp(BuildContext context) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (BuildContext ctx) => const JalaFilterHelpSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return JalaThemedPage(
      child: StreamBuilder<List<NetworkCallEntry>>(
        stream: JalaBinding.instance.store.watch,
        initialData: JalaBinding.instance.store.entries,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<NetworkCallEntry>> callsSnapshot,
            ) => StreamBuilder<List<WsConnectionEntry>>(
              stream: JalaBinding.instance.store.watchWs,
              initialData: JalaBinding.instance.store.wsConnections,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<WsConnectionEntry>> wsSnapshot,
                  ) => _buildScaffold(
                    context,
                    callsSnapshot.data ?? const <NetworkCallEntry>[],
                    wsSnapshot.data ?? const <WsConnectionEntry>[],
                  ),
            ),
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    List<NetworkCallEntry> calls,
    List<WsConnectionEntry> wsConnections,
  ) {
    final List<_MergedEntry> all = _mergeEntries(calls, wsConnections);
    final List<_MergedEntry> filtered = _filter.isEmpty
        ? all
        : all
              .where(
                (_MergedEntry merged) => switch (merged) {
                  _CallEntry(:final NetworkCallEntry entry) => _filter.matches(
                    entry,
                  ),
                  _WsEntry(:final WsConnectionEntry entry) => _filter.matchesWs(
                    entry,
                  ),
                },
              )
              .toList();
    return Scaffold(
      appBar: AppBar(
        leading: widget.onClose == null
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close inspector',
                onPressed: widget.onClose,
              ),
        title: const Text('Jala'),
        actions: <Widget>[
          StreamBuilder<List<JalaMockRule>>(
            stream: JalaBinding.instance.mockRegistry.watch,
            initialData: JalaBinding.instance.mockRegistry.rules,
            builder:
                (BuildContext context, AsyncSnapshot<List<JalaMockRule>> snap) {
                  final int enabled = (snap.data ?? const <JalaMockRule>[])
                      .where((JalaMockRule r) => r.enabled)
                      .length;
                  return IconButton(
                    tooltip: enabled > 0 ? 'Mocks ($enabled enabled)' : 'Mocks',
                    onPressed: () {
                      Navigator.of(context).push(JalaMocksScreen.route());
                    },
                    // Avoid Badge animations that hang pumpAndSettle.
                    icon: enabled > 0
                        ? Stack(
                            clipBehavior: Clip.none,
                            children: <Widget>[
                              const Icon(Icons.rule),
                              Positioned(
                                right: -6,
                                top: -4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.error,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$enabled',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onError,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const Icon(Icons.rule),
                  );
                },
          ),
          StreamBuilder<JalaThrottleProfile?>(
            stream: JalaBinding.instance.throttleRegistry.watch,
            initialData: JalaBinding.instance.throttleRegistry.activeProfile,
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<JalaThrottleProfile?> snap,
                ) {
                  final JalaThrottleProfile? active = snap.data;
                  return IconButton(
                    tooltip: active != null
                        ? 'Throttling: ${active.name}'
                        : 'Throttle',
                    onPressed: () {
                      Navigator.of(context).push(JalaThrottleScreen.route());
                    },
                    // Avoid Badge animations that hang pumpAndSettle.
                    icon: active != null
                        ? Stack(
                            clipBehavior: Clip.none,
                            children: <Widget>[
                              const Icon(Icons.speed),
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.error,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const Icon(Icons.speed),
                  );
                },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear',
            onPressed: all.isEmpty ? null : () => _confirmClear(context),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Copy session as HAR',
            onPressed: calls.isEmpty
                ? null
                : () => _copySessionHar(context, calls),
          ),
          PopupMenuButton<_SessionAction>(
            tooltip: 'Session',
            onSelected: (_SessionAction action) =>
                _handleSessionAction(context, action),
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<_SessionAction>>[
                  PopupMenuItem<_SessionAction>(
                    value: _SessionAction.export,
                    child: Text('Export session'),
                  ),
                  PopupMenuItem<_SessionAction>(
                    value: _SessionAction.import,
                    child: Text('Import session'),
                  ),
                ],
          ),
          const _ThemeToggleButton(),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _filterController,
              onChanged: _onFilterChanged,
              decoration: InputDecoration(
                hintText: 'method:get status:4xx host:api.* …',
                prefixIcon: const Icon(Icons.filter_alt_outlined),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.help_outline),
                  tooltip: 'Filter grammar',
                  onPressed: () => _openHelp(context),
                ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const _ThrottleBanner(),
          if (JalaBinding.instance.store.isViewingImport)
            _ImportBanner(entryCount: calls.length),
          Expanded(
            child: all.isEmpty
                ? const _EmptyState(message: 'No network calls captured yet.')
                : filtered.isEmpty
                ? _EmptyState(
                    message: 'No calls match "${_filterController.text}".',
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const Divider(height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      return switch (filtered[index]) {
                        _CallEntry(:final NetworkCallEntry entry) =>
                          JalaCallListTile(
                            entry: entry,
                            onTap: () => Navigator.of(
                              context,
                            ).push(JalaCallDetailScreen.route(entry.id)),
                          ),
                        _WsEntry(:final WsConnectionEntry entry) =>
                          JalaWsListTile(
                            entry: entry,
                            onTap: () => Navigator.of(
                              context,
                            ).push(JalaWsDetailScreen.route(entry.id)),
                          ),
                      };
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context) {
    final JalaThemeController controller = JalaThemeScope.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? _) {
        final IconData icon = switch (controller.mode) {
          JalaThemeMode.system => Icons.brightness_auto,
          JalaThemeMode.light => Icons.light_mode,
          JalaThemeMode.dark => Icons.dark_mode,
        };
        return IconButton(
          icon: Icon(icon),
          tooltip: 'Theme: ${controller.mode.name}',
          onPressed: controller.cycle,
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Persistent banner shown below the filter field while a throttle profile
/// is active — tapping it opens [JalaThrottleScreen] (see
/// docs/plans/track-e-v0.5.md E3).
class _ThrottleBanner extends StatelessWidget {
  const _ThrottleBanner();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<JalaThrottleProfile?>(
      stream: JalaBinding.instance.throttleRegistry.watch,
      initialData: JalaBinding.instance.throttleRegistry.activeProfile,
      builder:
          (BuildContext context, AsyncSnapshot<JalaThrottleProfile?> snap) {
            final JalaThrottleProfile? active = snap.data;
            if (active == null) return const SizedBox.shrink();
            final ColorScheme scheme = Theme.of(context).colorScheme;
            return Material(
              color: scheme.tertiaryContainer,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(JalaThrottleScreen.route());
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.speed, size: 18, color: scheme.onTertiaryContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Throttling: ${active.name} — tap to change',
                          style: TextStyle(color: scheme.onTertiaryContainer),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: scheme.onTertiaryContainer,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
    );
  }
}

/// Banner shown below the filter field (and below [_ThrottleBanner], if
/// also active) while `JalaStore.isViewingImport` is true — offers a way
/// back to live capture via [JalaStore.clear].
class _ImportBanner extends StatelessWidget {
  const _ImportBanner({required this.entryCount});

  final int entryCount;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.upload_file,
              size: 18,
              color: scheme.onSecondaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Imported session ($entryCount '
                '${entryCount == 1 ? 'entry' : 'entries'}) — Clear to '
                'return to live capture',
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
            TextButton(
              onPressed: JalaBinding.instance.store.clear,
              child: const Text('Clear'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for [_SessionAction.import]: paste-JSON field, Replace/Append
/// choice, and inline decode-error text (never a crash — see
/// `JalaSessionFormatException`).
class _ImportSessionDialog extends StatefulWidget {
  const _ImportSessionDialog();

  @override
  State<_ImportSessionDialog> createState() => _ImportSessionDialogState();
}

class _ImportSessionDialogState extends State<_ImportSessionDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _append = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _import() {
    final String text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Paste a session JSON to import');
      return;
    }
    try {
      final JalaSession session = JalaSessionCodec.decode(text);
      JalaBinding.instance.store.importSession(session, append: _append);
      Navigator.of(context).pop();
    } on JalaSessionFormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import session'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: _controller,
              minLines: 6,
              maxLines: 12,
              decoration: const InputDecoration(
                hintText: 'Paste exported session JSON here…',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(value: false, label: Text('Replace')),
                ButtonSegment<bool>(value: true, label: Text('Append')),
              ],
              selected: <bool>{_append},
              onSelectionChanged: (Set<bool> s) =>
                  setState(() => _append = s.first),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _import, child: const Text('Import')),
      ],
    );
  }
}
