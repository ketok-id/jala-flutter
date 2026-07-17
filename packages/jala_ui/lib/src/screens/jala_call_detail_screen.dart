import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jala_core/jala_core.dart';

import '../util/format.dart';
import '../widgets/jala_body_view.dart';
import '../widgets/jala_headers_table.dart';
import '../widgets/jala_json_tree.dart';
import '../widgets/jala_themed_page.dart';
import 'jala_mock_editor_screen.dart';
import 'jala_request_composer_screen.dart';

/// Detail screen for a single call: Overview / Request / Response tabs and
/// a bottom action bar (copy body / cURL / Dart snippet / HAR, replay).
///
/// Re-watches `JalaBinding.instance.store` so a still-pending entry
/// updates live as its response arrives.
class JalaCallDetailScreen extends StatefulWidget {
  /// Creates the detail screen for the entry identified by [entryId].
  const JalaCallDetailScreen({required this.entryId, super.key});

  /// The id of the [NetworkCallEntry] to display.
  final String entryId;

  /// Builds a route pushing the detail screen for [entryId].
  static Route<void> route(String entryId) {
    return MaterialPageRoute<void>(
      builder: (BuildContext context) => JalaCallDetailScreen(entryId: entryId),
    );
  }

  @override
  State<JalaCallDetailScreen> createState() => _JalaCallDetailScreenState();
}

class _JalaCallDetailScreenState extends State<JalaCallDetailScreen>
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
    final bool ok = await JalaBinding.instance.replayRegistry.replay(entry);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Replay sent' : 'No replayer attached')),
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
              AsyncSnapshot<List<NetworkCallEntry>> snapshot,
            ) {
              final NetworkCallEntry? entry = JalaBinding.instance.store.byId(
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
                  JalaBinding.instance.replayRegistry.hasReplayer;
              final bool imported = entry.imported;
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
                      graphQlRequest: _GraphQlRequest.tryParse(entry),
                    ),
                    _HeadersBodyTab(
                      headers: entry.responseHeaders,
                      body: entry.responseBody,
                      errorMessage: entry.errorMessage,
                      operationType: entry.operationType,
                      payloads: entry.payloads,
                      payloadCount: entry.payloadCount,
                    ),
                  ],
                ),
                bottomNavigationBar: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4,
                      children: <Widget>[
                        TextButton.icon(
                          onPressed: () => _copy(
                            context,
                            'body',
                            entry.responseBody.text ??
                                entry.requestBody.text ??
                                '',
                          ),
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Body'),
                        ),
                        TextButton.icon(
                          onPressed: () => _copy(
                            context,
                            'cURL',
                            CurlExporter.export(entry),
                          ),
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
                          message: imported
                              ? "Imported entries can't be mocked from"
                              : 'Prefill a mock rule from this call',
                          child: TextButton.icon(
                            onPressed: imported
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                      JalaMockEditorScreen.routeFromEntry(
                                        entry,
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.bolt, size: 18),
                            label: const Text('Mock this'),
                          ),
                        ),
                        Tooltip(
                          message: imported
                              ? "Imported entries can't be edited & resent"
                              : (hasReplayer
                                    ? 'Edit and resend this call'
                                    : 'No replayer attached'),
                          child: TextButton.icon(
                            onPressed: (!imported && hasReplayer)
                                ? () {
                                    Navigator.of(context).push(
                                      JalaRequestComposerScreen.route(entry),
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.edit_note, size: 18),
                            label: const Text('Edit & resend'),
                          ),
                        ),
                        Tooltip(
                          message: imported
                              ? "Imported entries can't be replayed"
                              : (hasReplayer
                                    ? 'Replay this call'
                                    : 'No replayer attached — use '
                                          'JalaDio.attach(dio)'),
                          child: FilledButton.icon(
                            onPressed: (!imported && hasReplayer)
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

  /// Renders a live "Sent X / Y · Received A / B" line for a still-pending
  /// call's latest [NetworkProgressEvent] — see B4 in
  /// docs/plans/track-b-v0.2.md.
  static String _transferredLabel(NetworkProgressEvent progress) {
    final String sent = progress.sentTotal != null
        ? '${humanizeBytes(progress.sentBytes)} / '
              '${humanizeBytes(progress.sentTotal)}'
        : humanizeBytes(progress.sentBytes);
    final String received = progress.receivedTotal != null
        ? '${humanizeBytes(progress.receivedBytes)} / '
              '${humanizeBytes(progress.receivedTotal)}'
        : humanizeBytes(progress.receivedBytes);
    return 'Sent $sent · Received $received';
  }

  static String _statusLabel(NetworkCallEntry entry) {
    switch (entry.status) {
      case JalaCallStatus.pending:
        return 'Pending…';
      case JalaCallStatus.cancelled:
        return 'Cancelled';
      case JalaCallStatus.error:
        return entry.statusCode != null
            ? 'Error (${entry.statusCode})'
            : 'Error';
      case JalaCallStatus.success:
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
      // GraphQL metadata (D4): operation name + type in one row.
      if (entry.operationName != null)
        (
          'Operation',
          Text(
            entry.operationType != null
                ? '${entry.operationName} (${entry.operationType})'
                : entry.operationName!,
          ),
        ),
      // Show whenever progress was observed — live while pending, and as a
      // final snapshot after the call completes (B4).
      if (entry.progress != null)
        ('Transferred', Text(_transferredLabel(entry.progress!))),
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
                    final NetworkCallEntry? original = JalaBinding
                        .instance
                        .store
                        .byId(replayOf);
                    if (original != null) {
                      Navigator.of(
                        context,
                      ).push(JalaCallDetailScreen.route(replayOf));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Original call is no longer available.',
                          ),
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

/// The parsed GraphQL request payload of a captured entry: the `query`
/// source string plus its (possibly absent) `variables` map.
///
/// The Request tab uses this to render dedicated Query/Variables sections
/// instead of the raw JSON body view — see docs/plans/track-d-v0.4.md D4.
class _GraphQlRequest {
  const _GraphQlRequest({required this.query, required this.variables});

  /// Parses [entry]'s request body as a GraphQL request payload
  /// (`{operationName, query, variables}` — the shape `jala_graphql`
  /// captures). Returns null when the entry carries no GraphQL metadata,
  /// or when the body text does not parse as a JSON object with a `query`
  /// string — in that case the tab falls back to the plain body view.
  static _GraphQlRequest? tryParse(NetworkCallEntry entry) {
    if (entry.operationName == null) return null;
    final String? text = entry.requestBody.text;
    if (text == null) return null;
    final dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final dynamic query = decoded['query'];
    if (query is! String) return null;
    final dynamic variables = decoded['variables'];
    return _GraphQlRequest(
      query: query,
      variables: variables is Map<String, dynamic> ? variables : null,
    );
  }

  final String query;
  final Map<String, dynamic>? variables;
}

class _HeadersBodyTab extends StatelessWidget {
  const _HeadersBodyTab({
    required this.headers,
    required this.body,
    this.errorMessage,
    this.graphQlRequest,
    this.operationType,
    this.payloads = const <CapturedBody>[],
    this.payloadCount = 0,
  });

  final Map<String, String> headers;
  final CapturedBody body;
  final String? errorMessage;

  /// When non-null, the Body section is replaced by Query/Variables
  /// sections rendered from this parsed GraphQL payload.
  final _GraphQlRequest? graphQlRequest;

  /// `NetworkCallEntry.operationType` — only populated for the Response
  /// tab, to drive the subscription payload timeline below.
  final String? operationType;

  /// `NetworkCallEntry.payloads` — see [operationType].
  final List<CapturedBody> payloads;

  /// `NetworkCallEntry.payloadCount` — see [operationType].
  final int payloadCount;

  @override
  Widget build(BuildContext context) {
    final _GraphQlRequest? graphQl = graphQlRequest;
    final bool showSubscriptionPayloads =
        operationType == 'subscription' && payloads.isNotEmpty;
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
        JalaHeadersTable(headers: headers),
        const Divider(),
        if (showSubscriptionPayloads) ...<Widget>[
          Text(
            'Subscription payloads',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          _SubscriptionPayloadList(
            payloads: payloads,
            payloadCount: payloadCount,
          ),
          const Divider(),
        ],
        if (graphQl != null) ...<Widget>[
          Text('Query', style: Theme.of(context).textTheme.titleSmall),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SelectableText(
              graphQl.query,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
          const Divider(),
          Text('Variables', style: Theme.of(context).textTheme.titleSmall),
          if (graphQl.variables == null || graphQl.variables!.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No variables'),
            )
          else
            JalaJsonTree(data: graphQl.variables),
        ] else ...<Widget>[
          Text('Body', style: Theme.of(context).textTheme.titleSmall),
          JalaBodyView(body: body),
        ],
      ],
    );
  }
}

/// Renders `NetworkCallEntry.payloads` for a GraphQL subscription (see
/// docs/plans/track-e-v0.5.md E1/E3): index within the (possibly
/// ring-buffer-trimmed) list and size, tapping into a body view sheet that
/// reuses [JalaBodyView] — mirroring the WS frame list/preview-sheet
/// pattern in `JalaWsDetailScreen`.
class _SubscriptionPayloadList extends StatelessWidget {
  const _SubscriptionPayloadList({
    required this.payloads,
    required this.payloadCount,
  });

  final List<CapturedBody> payloads;
  final int payloadCount;

  void _showPayload(BuildContext context, int index, CapturedBody body) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext _) => _PayloadSheet(index: index, body: body),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (payloadCount > payloads.length)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Showing last ${payloads.length} of $payloadCount payloads',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        for (int i = 0; i < payloads.length; i++)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: SizedBox(width: 32, child: Text('#$i')),
            title: Text(
              payloads[i].text ?? '(binary)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
            trailing: Text(humanizeBytes(payloads[i].originalSize)),
            onTap: () => _showPayload(context, i, payloads[i]),
          ),
      ],
    );
  }
}

/// Bottom sheet showing a single subscription payload's body, reusing
/// [JalaBodyView] (which already handles JSON/text/binary rendering).
class _PayloadSheet extends StatelessWidget {
  const _PayloadSheet({required this.index, required this.body});

  final int index;
  final CapturedBody body;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Payload #$index',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            Flexible(
              child: SingleChildScrollView(child: JalaBodyView(body: body)),
            ),
          ],
        ),
      ),
    );
  }
}
