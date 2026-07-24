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
import 'jala_request_composer_screen.dart';
import 'jala_throttle_screen.dart';
import 'jala_ws_detail_screen.dart';

/// Session actions offered from the inspector AppBar overflow menu (see
/// docs/plans/track-e-v0.5.md E3, and Track F import codecs).
enum _SessionAction {
  exportFull,
  exportHeadersOnly,
  exportNoBodies,
  import,
  importHar,
  importCurl,
}

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
  bool _denseList = false;

  static const List<(String label, String query)> _quickFilters =
      <(String, String)>[
        ('4xx', 's:4xx'),
        ('5xx', 's:5xx'),
        ('Errors', 's:error'),
        ('Mocked', 'is:mocked'),
        ('GraphQL', 'is:graphql'),
        ('WS', 'is:ws'),
      ];

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

  void _applyQuickFilter(String query) {
    final String current = _filterController.text.trim();
    // Toggle off if the field is exactly this chip's query.
    if (current == query) {
      _filterController.clear();
      setState(() => _filter = JalaFilter.parse(''));
      return;
    }
    _filterController.text = query;
    _filterController.selection = TextSelection.collapsed(offset: query.length);
    setState(() => _filter = JalaFilter.parse(query));
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

  Future<void> _exportSession(
    BuildContext context, {
    required JalaSessionExportOptions options,
    required String modeLabel,
  }) async {
    final JalaStore store = JalaBinding.instance.store;
    final int count = store.entries.length;
    final String json = JalaSessionCodec.encode(store, options: options);
    await Clipboard.setData(ClipboardData(text: json));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Exported session ($modeLabel) — $count '
          '${count == 1 ? 'entry' : 'entries'} copied. '
          'May contain personal data; share carefully.',
        ),
      ),
    );
  }

  Future<void> _importSession(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => const _ImportSessionDialog(
        title: 'Import session',
        hint: 'Paste exported session JSON here…',
        note:
            'Treat pasted JSON like a log dump — it may contain personal or '
            'business data. Max size '
            '${JalaSessionCodec.defaultMaxDecodeChars ~/ (1024 * 1024)} MiB.',
        decode: JalaSessionCodec.decode,
      ),
    );
  }

  Future<void> _importHar(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => const _ImportSessionDialog(
        title: 'Import HAR',
        hint: 'Paste HAR 1.2 JSON here…',
        note:
            'Imports a HAR export (browser devtools, Charles, Proxyman, …) as '
            'a session. Imported calls have replay disabled.',
        decode: JalaHarCodec.decode,
      ),
    );
  }

  Future<void> _importCurl(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => const _ImportCurlDialog(),
    );
  }

  Future<void> _handleSessionAction(
    BuildContext context,
    _SessionAction action,
  ) async {
    switch (action) {
      case _SessionAction.exportFull:
        await _exportSession(
          context,
          options: JalaSessionExportOptions.full,
          modeLabel: 'full',
        );
      case _SessionAction.exportHeadersOnly:
        await _exportSession(
          context,
          options: JalaSessionExportOptions.headersOnly,
          modeLabel: 'headers only',
        );
      case _SessionAction.exportNoBodies:
        await _exportSession(
          context,
          options: JalaSessionExportOptions.noBodies,
          modeLabel: 'no bodies',
        );
      case _SessionAction.import:
        await _importSession(context);
      case _SessionAction.importHar:
        await _importHar(context);
      case _SessionAction.importCurl:
        await _importCurl(context);
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
            icon: Icon(
              _denseList ? Icons.density_medium : Icons.density_small,
            ),
            tooltip: _denseList ? 'Comfortable list' : 'Compact list',
            onPressed: () => setState(() => _denseList = !_denseList),
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
                    value: _SessionAction.exportFull,
                    child: Text('Export session (full)'),
                  ),
                  PopupMenuItem<_SessionAction>(
                    value: _SessionAction.exportNoBodies,
                    child: Text('Export session (no bodies)'),
                  ),
                  PopupMenuItem<_SessionAction>(
                    value: _SessionAction.exportHeadersOnly,
                    child: Text('Export session (headers only)'),
                  ),
                  PopupMenuItem<_SessionAction>(
                    value: _SessionAction.import,
                    child: Text('Import session'),
                  ),
                  PopupMenuItem<_SessionAction>(
                    value: _SessionAction.importHar,
                    child: Text('Import HAR…'),
                  ),
                  PopupMenuItem<_SessionAction>(
                    value: _SessionAction.importCurl,
                    child: Text('Import cURL…'),
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
            child: Builder(
              builder: (BuildContext context) {
                final ColorScheme scheme = Theme.of(context).colorScheme;
                // Placeholder must read as secondary text, not disabled —
                // default hintStyle is often too faint on light surfaces.
                final TextStyle? hintStyle = Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                    );
                return TextField(
                  controller: _filterController,
                  onChanged: _onFilterChanged,
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Filter: method:get  s:4xx  host:api.*',
                    hintStyle: hintStyle,
                    prefixIcon: Icon(
                      Icons.filter_alt_outlined,
                      color: scheme.onSurfaceVariant,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        Icons.help_outline,
                        color: scheme.onSurfaceVariant,
                      ),
                      tooltip: 'Filter grammar',
                      onPressed: () => _openHelp(context),
                    ),
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.45,
                    ),
                    border: const OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: scheme.outlineVariant,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: scheme.primary,
                        width: 1.5,
                      ),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (final (String label, String query) in _quickFilters)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(label),
                        selected: _filterController.text.trim() == query,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onSelected: (_) => _applyQuickFilter(query),
                      ),
                    ),
                ],
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
                    // Extra bottom pad so the last row isn't tight against
                    // the system gesture area (bubble is hidden when open).
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filtered.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const Divider(height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      return switch (filtered[index]) {
                        _CallEntry(:final NetworkCallEntry entry) =>
                          JalaCallListTile(
                            dense: _denseList,
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

/// Paste-to-import dialog for anything that decodes to a [JalaSession]:
/// exported Jala JSON ([JalaSessionCodec.decode]) or a HAR document
/// ([JalaHarCodec.decode]). Offers a Replace/Append choice and shows inline
/// decode-error text (never a crash — both decoders only throw
/// [JalaSessionFormatException]).
class _ImportSessionDialog extends StatefulWidget {
  const _ImportSessionDialog({
    required this.title,
    required this.hint,
    required this.note,
    required this.decode,
  });

  final String title;
  final String hint;
  final String note;
  final JalaSession Function(String) decode;

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
      setState(() => _error = 'Paste something to import');
      return;
    }
    try {
      final JalaSession session = widget.decode(text);
      JalaBinding.instance.store.importSession(session, append: _append);
      Navigator.of(context).pop();
    } on JalaSessionFormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(widget.note, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                minLines: 5,
                maxLines: 10,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  border: const OutlineInputBorder(),
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

/// Paste-a-`curl`-command dialog: parses via [JalaCurlCodec] and opens the
/// request composer prefilled for edit-and-resend. Shows inline errors and
/// never crashes ([JalaCurlCodec.decode] only throws
/// [JalaImportFormatException]).
class _ImportCurlDialog extends StatefulWidget {
  const _ImportCurlDialog();

  @override
  State<_ImportCurlDialog> createState() => _ImportCurlDialogState();
}

class _ImportCurlDialogState extends State<_ImportCurlDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _import() {
    final String text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Paste a curl command');
      return;
    }
    final ImportedRequest req;
    try {
      req = JalaCurlCodec.decode(text);
    } on JalaImportFormatException catch (e) {
      setState(() => _error = e.message);
      return;
    }
    final NetworkCallEntry draft = NetworkCallEntry(
      id: JalaIdGenerator.next(),
      startTime: DateTime.now(),
      method: req.method,
      uri: req.uri,
      requestHeaders: req.headers,
      requestBody: req.body == null
          ? CapturedBody.none
          : CapturedBody.capture(req.body, contentType: _contentType(req)),
      responseHeaders: const <String, String>{},
      responseBody: CapturedBody.none,
      status: JalaCallStatus.pending,
      client: 'import',
    );
    Navigator.of(context).pop();
    Navigator.of(context).push(JalaRequestComposerScreen.route(draft));
  }

  static String? _contentType(ImportedRequest req) {
    for (final MapEntry<String, String> h in req.headers.entries) {
      if (h.key.toLowerCase() == 'content-type') return h.value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import cURL'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Paste a curl command (e.g. copied from browser devtools). It '
                'opens in the composer to edit and send.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                minLines: 4,
                maxLines: 10,
                decoration: const InputDecoration(
                  hintText: "curl 'https://…' -H '…' -d '…'",
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
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _import, child: const Text('Open in composer')),
      ],
    );
  }
}
