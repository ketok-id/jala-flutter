import 'package:flutter/material.dart';
import 'package:jala_core/jala_core.dart';

import '../widgets/jala_json_diff_view.dart';
import '../widgets/jala_themed_page.dart';

/// Side-by-side (unified) comparison of two captured calls: status line,
/// request/response header diffs, and structural body diffs when both sides
/// are JSON. Uses `JalaEntryDiff` for all the diffing.
class JalaCallDiffScreen extends StatelessWidget {
  /// Creates a diff screen comparing [a] (before) against [b] (after).
  const JalaCallDiffScreen({required this.a, required this.b, super.key});

  /// The "before" call.
  final NetworkCallEntry a;

  /// The "after" call.
  final NetworkCallEntry b;

  /// Builds a route pushing a comparison of [a] and [b].
  static Route<void> route(NetworkCallEntry a, NetworkCallEntry b) =>
      MaterialPageRoute<void>(
        builder: (BuildContext _) => JalaCallDiffScreen(a: a, b: b),
      );

  @override
  Widget build(BuildContext context) {
    final JalaEntryDiff diff = JalaEntryDiff.of(a, b);
    return JalaThemedPage(
      child: Scaffold(
        appBar: AppBar(title: const Text('Compare calls')),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            _identity(context, 'A', a),
            _identity(context, 'B', b),
            const SizedBox(height: 8),
            _section(context, 'Status', _statusRow(context, diff)),
            _section(
              context,
              'Request headers',
              _headerDiffs(context, diff.requestHeaders),
            ),
            _section(
              context,
              'Response headers',
              _headerDiffs(context, diff.responseHeaders),
            ),
            _bodySection(
              context,
              'Request body',
              comparable: diff.requestBodyComparable,
              bodyDiff: diff.requestBodyDiff,
            ),
            _bodySection(
              context,
              'Response body',
              comparable: diff.responseBodyComparable,
              bodyDiff: diff.responseBodyDiff,
            ),
          ],
        ),
      ),
    );
  }

  Widget _identity(BuildContext context, String tag, NetworkCallEntry e) {
    final String path = e.uri.path.isEmpty ? '/' : e.uri.path;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '$tag:  ${e.method} $path  ·  ${e.statusCode ?? '—'}',
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
    );
  }

  Widget _section(BuildContext context, String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _statusRow(BuildContext context, JalaEntryDiff diff) {
    final String text =
        '${diff.statusBefore ?? '—'}  →  ${diff.statusAfter ?? '—'}';
    if (!diff.statusChanged) {
      return Text(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Container(
      color: _amber(context).withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: Text(
        '~ $text',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _amber(context),
        ),
      ),
    );
  }

  Widget _headerDiffs(BuildContext context, List<HeaderDiff> diffs) {
    if (diffs.isEmpty) {
      return Text(
        'none',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final HeaderDiff d in diffs) _HeaderDiffRow(diff: d),
      ],
    );
  }

  Widget _bodySection(
    BuildContext context,
    String title, {
    required bool comparable,
    required JsonDiffNode? bodyDiff,
  }) {
    final Widget child;
    if (comparable && bodyDiff != null) {
      child = JalaJsonDiffView(root: bodyDiff);
    } else {
      child = Text(
        'Not a structural diff — one or both bodies are not JSON.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return _section(context, title, child);
  }

  static Color _amber(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFE0AF68)
          : const Color(0xFFB26A00);
}

/// One request/response header comparison row.
class _HeaderDiffRow extends StatelessWidget {
  const _HeaderDiffRow({required this.diff});

  final HeaderDiff diff;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color green = dark ? const Color(0xFF9ECE6A) : const Color(0xFF2E7D32);
    final Color amber = dark ? const Color(0xFFE0AF68) : const Color(0xFFB26A00);

    late final String marker;
    late final Color fg;
    Color? bg;
    switch (diff.kind) {
      case JsonDiffKind.added:
        marker = '+';
        fg = green;
        bg = green.withValues(alpha: 0.12);
      case JsonDiffKind.removed:
        marker = '-';
        fg = scheme.error;
        bg = scheme.error.withValues(alpha: 0.10);
      case JsonDiffKind.changed:
        marker = '~';
        fg = amber;
        bg = amber.withValues(alpha: 0.12);
      case JsonDiffKind.unchanged:
        marker = ' ';
        fg = scheme.onSurfaceVariant;
    }

    final TextStyle base =
        TextStyle(fontFamily: 'monospace', fontSize: 12.5, color: fg);
    final String value = switch (diff.kind) {
      JsonDiffKind.added => diff.after ?? '',
      JsonDiffKind.removed => diff.before ?? '',
      JsonDiffKind.changed => '${diff.before ?? ''}  →  ${diff.after ?? ''}',
      JsonDiffKind.unchanged => diff.after ?? diff.before ?? '',
    };

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Text.rich(
        TextSpan(
          children: <TextSpan>[
            TextSpan(
              text: '$marker ${diff.name}: ',
              style: base.copyWith(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value, style: base),
          ],
        ),
      ),
    );
  }
}
