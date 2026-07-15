import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ketok_core/ketok_core.dart';

import '../util/format.dart';
import '../widgets/ketok_body_view.dart';
import '../widgets/ketok_headers_table.dart';
import '../widgets/ketok_themed_page.dart';

/// Detail screen for a single call: Overview / Request / Response tabs and
/// a bottom action bar (copy body / cURL / Dart snippet / HAR, replay).
///
/// Re-watches `KetokBinding.instance.store` so a still-pending entry
/// updates live as its response arrives.
class KetokCallDetailScreen extends StatefulWidget {
  /// Creates the detail screen for the entry identified by [entryId].
  const KetokCallDetailScreen({required this.entryId, super.key});

  /// The id of the [NetworkCallEntry] to display.
  final String entryId;

  /// Builds a route pushing the detail screen for [entryId].
  static Route<void> route(String entryId) {
    return MaterialPageRoute<void>(
      builder: (BuildContext context) =>
          KetokCallDetailScreen(entryId: entryId),
    );
  }

  @override
  State<KetokCallDetailScreen> createState() => _KetokCallDetailScreenState();
}

class _KetokCallDetailScreenState extends State<KetokCallDetailScreen>
    with SingleTickerProviderStateMixin {
  // Created in initState (not as a lazy field) so dispose never constructs
  // a TabController after the element is deactivated — that path crashes
  // when the missing-entry early-return never touched the controller.
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _copy(BuildContext context, String label, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Copied $label')));
  }

  Future<void> _replay(BuildContext context, NetworkCallEntry entry) async {
    final bool ok = await KetokBinding.instance.replayRegistry.replay(entry);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Replay sent' : 'No replayer attached')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KetokThemedPage(
      child: StreamBuilder<List<NetworkCallEntry>>(
        stream: KetokBinding.instance.store.watch,
        initialData: KetokBinding.instance.store.entries,
        builder: (
          BuildContext context,
          AsyncSnapshot<List<NetworkCallEntry>> snapshot,
        ) {
          final NetworkCallEntry? entry = KetokBinding.instance.store.byId(
            widget.entryId,
          );
          if (entry == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Call detail')),
              body: const Center(
                child: Text('This call is no longer available.'),
              ),
            );
          }
          final bool hasReplayer =
              KetokBinding.instance.replayRegistry.hasReplayer;
          return Scaffold(
            appBar: AppBar(
              title: Text(
                '${entry.method} ${entry.uri.path}',
                overflow: TextOverflow.ellipsis,
              ),
              bottom: TabBar(
                controller: _tabController,
                tabs: const <Tab>[
                  Tab(text: 'Overview'),
                  Tab(text: 'Request'),
                  Tab(text: 'Response'),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: <Widget>[
                _OverviewTab(entry: entry),
                _HeadersBodyTab(
                  headers: entry.requestHeaders,
                  body: entry.requestBody,
                ),
                _HeadersBodyTab(
                  headers: entry.responseHeaders,
                  body: entry.responseBody,
                  errorMessage: entry.errorMessage,
                ),
              ],
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  children: <Widget>[
                    TextButton.icon(
                      onPressed: () => _copy(
                        context,
                        'body',
                        entry.responseBody.text ?? entry.requestBody.text ?? '',
                      ),
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Body'),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          _copy(context, 'cURL', CurlExporter.export(entry)),
                      icon: const Icon(Icons.terminal, size: 18),
                      label: const Text('cURL'),
                    ),
                    TextButton.icon(
                      onPressed: () => _copy(
                        context,
                        'Dart snippet',
                        DartSnippetExporter.export(entry),
                      ),
                      icon: const Icon(Icons.code, size: 18),
                      label: const Text('Dart'),
                    ),
                    TextButton.icon(
                      onPressed: () => _copy(
                        context,
                        'HAR',
                        HarExporter.exportCall(entry),
                      ),
                      icon: const Icon(Icons.description, size: 18),
                      label: const Text('HAR'),
                    ),
                    Tooltip(
                      message: hasReplayer
                          ? 'Replay this call'
                          : 'No replayer attached — use KetokDio.attach(dio)',
                      child: FilledButton.icon(
                        onPressed: hasReplayer
                            ? () => _replay(context, entry)
                            : null,
                        icon: const Icon(Icons.replay, size: 18),
                        label: const Text('Replay'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.entry});

  final NetworkCallEntry entry;

  static String _statusLabel(NetworkCallEntry entry) {
    switch (entry.status) {
      case KetokCallStatus.pending:
        return 'Pending…';
      case KetokCallStatus.cancelled:
        return 'Cancelled';
      case KetokCallStatus.error:
        return entry.statusCode != null
            ? 'Error (${entry.statusCode})'
            : 'Error';
      case KetokCallStatus.success:
        return '${entry.statusCode} ${entry.statusMessage ?? ''}'.trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<(String, Widget)> rows = <(String, Widget)>[
      ('Method', Text(entry.method)),
      ('URL', SelectableText(entry.uri.toString())),
      ('Status', Text(_statusLabel(entry))),
      ('Duration', Text(humanizeDuration(entry.duration))),
      ('Request size', Text(humanizeBytes(entry.requestSize))),
      ('Response size', Text(humanizeBytes(entry.responseSize))),
      ('Start time', Text(entry.startTime.toLocal().toString())),
      ('Client', Text(entry.client)),
      if (entry.errorMessage != null) ('Error', Text(entry.errorMessage!)),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        for (final (String label, Widget value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 120,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Expanded(child: value),
              ],
            ),
          ),
        if (entry.replayOf != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 120,
                  child: Text(
                    'Replay of',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final String replayOf = entry.replayOf!;
                    final NetworkCallEntry? original = KetokBinding.instance
                        .store
                        .byId(replayOf);
                    if (original != null) {
                      Navigator.of(
                        context,
                      ).push(KetokCallDetailScreen.route(replayOf));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Original call is no longer available.'),
                        ),
                      );
                    }
                  },
                  child: Text(entry.replayOf!),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HeadersBodyTab extends StatelessWidget {
  const _HeadersBodyTab({
    required this.headers,
    required this.body,
    this.errorMessage,
  });

  final Map<String, String> headers;
  final CapturedBody body;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        if (errorMessage != null) ...<Widget>[
          Text('Error', style: Theme.of(context).textTheme.titleSmall),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SelectableText(errorMessage!),
          ),
          const Divider(),
        ],
        Text('Headers', style: Theme.of(context).textTheme.titleSmall),
        KetokHeadersTable(headers: headers),
        const Divider(),
        Text('Body', style: Theme.of(context).textTheme.titleSmall),
        KetokBodyView(body: body),
      ],
    );
  }
}
