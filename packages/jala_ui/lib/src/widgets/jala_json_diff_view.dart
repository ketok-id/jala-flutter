import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:jala_core/jala_core.dart';

/// Renders a [JsonDiffNode] tree (from `JalaJsonDiff.diff`) as an indented,
/// always-expanded unified diff: each row carries a gutter marker and is
/// colored by its [JsonDiffKind] — added (green), removed (red), changed
/// (amber), unchanged (muted). Diffs are typically small, so this builds
/// eagerly; large-payload virtualization is tracked separately (Track F2).
class JalaJsonDiffView extends StatelessWidget {
  /// Creates a diff view over [root] (the node returned by
  /// `JalaJsonDiff.diff`, whose own `$` label is not rendered).
  const JalaJsonDiffView({required this.root, super.key});

  /// The root diff node; its children are rendered at depth 0.
  final JsonDiffNode root;

  @override
  Widget build(BuildContext context) {
    final _DiffPalette palette = _DiffPalette.of(context);
    if (!root.hasChanges) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Identical',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: palette.unchangedFg,
          ),
        ),
      );
    }
    final List<Widget> rows = <Widget>[];
    if (root.children.isEmpty) {
      // A primitive-valued body that itself changed (rare) — render the root.
      _appendRows(rows, root, 0, palette);
    } else {
      for (final JsonDiffNode child in root.children) {
        _appendRows(rows, child, 0, palette);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  void _appendRows(
    List<Widget> out,
    JsonDiffNode node,
    int depth,
    _DiffPalette palette,
  ) {
    final bool isContainer = node.children.isNotEmpty;
    if (isContainer) {
      out.add(_DiffRow(node: node, depth: depth, palette: palette, header: true));
      for (final JsonDiffNode child in node.children) {
        _appendRows(out, child, depth + 1, palette);
      }
    } else {
      out.add(_DiffRow(node: node, depth: depth, palette: palette));
    }
  }
}

/// A single diff row: gutter marker, indented `key`, and a value rendering
/// that depends on [JsonDiffNode.kind].
class _DiffRow extends StatelessWidget {
  const _DiffRow({
    required this.node,
    required this.depth,
    required this.palette,
    this.header = false,
  });

  final JsonDiffNode node;
  final int depth;
  final _DiffPalette palette;

  /// Whether this is a container header row (renders `key {…}`/`[…]`) rather
  /// than a leaf value row.
  final bool header;

  @override
  Widget build(BuildContext context) {
    final _DiffStyle style = palette.forKind(node.kind);
    final TextStyle base = DefaultTextStyle.of(context).style.copyWith(
      fontFamily: 'monospace',
      fontSize: 13,
      color: style.fg,
    );

    return Container(
      color: style.bg,
      padding: EdgeInsets.only(
        left: 8.0 * depth + 4,
        top: 2,
        bottom: 2,
        right: 8,
      ),
      child: Text.rich(
        TextSpan(
          children: <TextSpan>[
            TextSpan(
              text: '${style.marker} ',
              style: base.copyWith(fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: header ? node.key : '${node.key}: ',
              style: base.copyWith(fontWeight: FontWeight.w600),
            ),
            ..._valueSpans(base),
          ],
        ),
      ),
    );
  }

  List<TextSpan> _valueSpans(TextStyle base) {
    if (header) {
      return <TextSpan>[TextSpan(text: _containerLabel(), style: base)];
    }
    switch (node.kind) {
      case JsonDiffKind.added:
        return <TextSpan>[TextSpan(text: _stringify(node.after), style: base)];
      case JsonDiffKind.removed:
        return <TextSpan>[TextSpan(text: _stringify(node.before), style: base)];
      case JsonDiffKind.changed:
        return <TextSpan>[
          TextSpan(
            text: _stringify(node.before),
            style: base.copyWith(
              decoration: TextDecoration.lineThrough,
              color: base.color?.withValues(alpha: 0.7),
            ),
          ),
          TextSpan(text: '  →  ', style: base),
          TextSpan(text: _stringify(node.after), style: base),
        ];
      case JsonDiffKind.unchanged:
        return <TextSpan>[TextSpan(text: _stringify(node.after), style: base)];
    }
  }

  String _containerLabel() {
    final Object? value = node.after ?? node.before;
    if (value is Map) return '{${value.length}}';
    if (value is List) return '[${value.length}]';
    return '';
  }

  static String _stringify(Object? value) {
    if (value == null) return 'null';
    if (value is String) return value;
    if (value is Map || value is List) return jsonEncode(value);
    return value.toString();
  }
}

/// Diff colors resolved once per build from the active [ColorScheme], kept
/// legible in both light and dark themes.
class _DiffPalette {
  const _DiffPalette({
    required this.added,
    required this.removed,
    required this.changed,
    required this.unchangedFg,
  });

  factory _DiffPalette.of(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color green = dark ? const Color(0xFF9ECE6A) : const Color(0xFF2E7D32);
    final Color red = scheme.error;
    final Color amber = dark ? const Color(0xFFE0AF68) : const Color(0xFFB26A00);
    return _DiffPalette(
      added: _DiffStyle('+', green, green.withValues(alpha: 0.12)),
      removed: _DiffStyle('-', red, red.withValues(alpha: 0.10)),
      changed: _DiffStyle('~', amber, amber.withValues(alpha: 0.12)),
      unchangedFg: scheme.onSurfaceVariant,
    );
  }

  final _DiffStyle added;
  final _DiffStyle removed;
  final _DiffStyle changed;
  final Color unchangedFg;

  _DiffStyle forKind(JsonDiffKind kind) {
    switch (kind) {
      case JsonDiffKind.added:
        return added;
      case JsonDiffKind.removed:
        return removed;
      case JsonDiffKind.changed:
        return changed;
      case JsonDiffKind.unchanged:
        return _DiffStyle(' ', unchangedFg, null);
    }
  }
}

class _DiffStyle {
  const _DiffStyle(this.marker, this.fg, this.bg);

  final String marker;
  final Color fg;
  final Color? bg;
}
