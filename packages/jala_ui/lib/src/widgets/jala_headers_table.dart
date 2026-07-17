import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Renders a header map as stacked name/value pairs with search, collapse of
/// common noise headers, and a collapsed "Sensitive" group (cookie / auth).
class JalaHeadersTable extends StatefulWidget {
  /// Creates a headers table for [headers].
  const JalaHeadersTable({required this.headers, super.key});

  /// Header name/value pairs, already redacted at capture time.
  final Map<String, String> headers;

  /// Headers treated as noise and collapsed by default (case-insensitive).
  static const Set<String> secondaryNames = <String>{
    'date',
    'server',
    'connection',
    'keep-alive',
    'transfer-encoding',
    'content-length',
    'vary',
    'via',
    'age',
    'alt-svc',
    'x-powered-by',
    'pragma',
    'nel',
    'report-to',
    'expect-ct',
    'cf-ray',
    'cf-cache-status',
    'cf-request-id',
    'x-cache',
    'x-amz-cf-id',
    'x-amz-cf-pop',
  };

  /// Headers collapsed under "Sensitive" (often long / secret-shaped).
  static const Set<String> sensitiveNames = <String>{
    'cookie',
    'set-cookie',
    'authorization',
    'proxy-authorization',
  };

  static bool isSecondary(String name) {
    final String n = name.toLowerCase();
    if (secondaryNames.contains(n)) return true;
    if (n.startsWith('cf-')) return true;
    return false;
  }

  static bool isSensitive(String name) =>
      sensitiveNames.contains(name.toLowerCase());

  @override
  State<JalaHeadersTable> createState() => _JalaHeadersTableState();
}

class _JalaHeadersTableState extends State<JalaHeadersTable> {
  final TextEditingController _search = TextEditingController();
  bool _showSecondary = false;
  bool _showSensitive = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.headers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('No headers'),
      );
    }

    final String q = _search.text.trim().toLowerCase();
    final List<MapEntry<String, String>> all = widget.headers.entries.toList();
    final List<MapEntry<String, String>> matched = q.isEmpty
        ? all
        : all
              .where(
                (MapEntry<String, String> e) =>
                    e.key.toLowerCase().contains(q) ||
                    e.value.toLowerCase().contains(q),
              )
              .toList();

    final List<MapEntry<String, String>> sensitive = matched
        .where((MapEntry<String, String> e) => JalaHeadersTable.isSensitive(e.key))
        .toList();
    final List<MapEntry<String, String>> secondary = matched
        .where(
          (MapEntry<String, String> e) =>
              !JalaHeadersTable.isSensitive(e.key) &&
              JalaHeadersTable.isSecondary(e.key),
        )
        .toList();
    final List<MapEntry<String, String>> primary = matched
        .where(
          (MapEntry<String, String> e) =>
              !JalaHeadersTable.isSensitive(e.key) &&
              !JalaHeadersTable.isSecondary(e.key),
        )
        .toList();

    // While searching, show every match expanded (no collapse surprises).
    final bool searching = q.isNotEmpty;
    final List<MapEntry<String, String>> visible = <MapEntry<String, String>>[
      ...primary,
      if (searching || _showSecondary) ...secondary,
      if (searching || _showSensitive) ...sensitive,
    ];

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final TextStyle keyStyle = (textTheme.labelMedium ?? const TextStyle())
        .copyWith(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        );
    final TextStyle valueStyle = (textTheme.bodyMedium ?? const TextStyle())
        .copyWith(fontFamily: 'monospace', height: 1.35);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          style: textTheme.bodySmall,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search headers…',
            hintStyle: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
            ),
            prefixIcon: Icon(
              Icons.search,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
            suffixIcon: q.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: 'Clear search',
                    onPressed: () {
                      _search.clear();
                      setState(() {});
                    },
                  ),
            filled: true,
            fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No headers match "$q"',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (int i = 0; i < visible.length; i++) ...<Widget>[
            _HeaderPair(
              name: visible[i].key,
              value: visible[i].value,
              keyStyle: keyStyle,
              valueStyle: valueStyle,
              onSurfaceVariant: scheme.onSurfaceVariant,
            ),
            if (i < visible.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
          ],
        if (!searching && secondary.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => setState(() => _showSecondary = !_showSecondary),
            icon: Icon(
              _showSecondary ? Icons.expand_less : Icons.expand_more,
              size: 18,
            ),
            label: Text(
              _showSecondary
                  ? 'Hide ${secondary.length} common headers'
                  : 'Show ${secondary.length} common headers '
                        '(date, server, …)',
            ),
          ),
        ],
        if (!searching && sensitive.isNotEmpty) ...<Widget>[
          TextButton.icon(
            onPressed: () => setState(() => _showSensitive = !_showSensitive),
            icon: Icon(
              _showSensitive ? Icons.expand_less : Icons.expand_more,
              size: 18,
            ),
            label: Text(
              _showSensitive
                  ? 'Hide sensitive headers'
                  : 'Show ${sensitive.length} sensitive '
                        '(cookie, authorization, …)',
            ),
          ),
        ],
      ],
    );
  }
}

class _HeaderPair extends StatelessWidget {
  const _HeaderPair({
    required this.name,
    required this.value,
    required this.keyStyle,
    required this.valueStyle,
    required this.onSurfaceVariant,
  });

  final String name;
  final String value;
  final TextStyle keyStyle;
  final TextStyle valueStyle;
  final Color onSurfaceVariant;

  Future<void> _copyValue(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text('Copied $name')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: SelectableText(name, style: keyStyle)),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Copy value',
                icon: Icon(
                  Icons.copy_outlined,
                  size: 16,
                  color: onSurfaceVariant,
                ),
                onPressed: () => _copyValue(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(value, style: valueStyle),
        ],
      ),
    );
  }
}
