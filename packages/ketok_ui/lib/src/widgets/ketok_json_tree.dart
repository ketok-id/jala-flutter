import 'package:flutter/material.dart';

/// A simple, self-built recursive expandable tree for JSON values.
///
/// Maps and lists are expandable nodes; primitives are leaf rows. Long
/// string leaves are ellipsized with tap-to-expand. An in-body substring
/// search field filters to matching nodes (and their ancestors) and
/// highlights the match.
class KetokJsonTree extends StatefulWidget {
  /// Creates a JSON tree over an already-decoded [data] value (the result
  /// of `jsonDecode`).
  const KetokJsonTree({required this.data, super.key});

  /// The decoded JSON value: a `Map<String, dynamic>`, `List<dynamic>`, or
  /// a primitive.
  final dynamic data;

  @override
  State<KetokJsonTree> createState() => _KetokJsonTreeState();
}

class _KetokJsonTreeState extends State<KetokJsonTree> {
  static const String _rootPath = r'$';

  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expanded = <String>{_rootPath};
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggle(String path) {
    setState(() {
      if (!_expanded.add(path)) _expanded.remove(path);
    });
  }

  @override
  Widget build(BuildContext context) {
    final String query = _query.trim().toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 18),
              hintText: 'Search in JSON…',
              border: OutlineInputBorder(),
            ),
            onChanged: (String value) => setState(() => _query = value),
          ),
        ),
        KetokJsonNode(
          keyLabel: _rootPath,
          path: _rootPath,
          value: widget.data,
          depth: 0,
          query: query,
          expandedPaths: _expanded,
          onToggle: _toggle,
        ),
      ],
    );
  }
}

/// One node (container or leaf) of a [KetokJsonTree]. Public so tests can
/// target nodes directly if needed.
@visibleForTesting
class KetokJsonNode extends StatelessWidget {
  /// Creates a node.
  const KetokJsonNode({
    required this.keyLabel,
    required this.path,
    required this.value,
    required this.depth,
    required this.query,
    required this.expandedPaths,
    required this.onToggle,
    super.key,
  });

  /// The key or index label shown for this node (`$` for the root).
  final String keyLabel;

  /// A unique path identifying this node's position in the tree, used as
  /// the expansion-state key.
  final String path;

  /// This node's JSON value.
  final dynamic value;

  /// Nesting depth, used for indentation.
  final int depth;

  /// Lowercased, trimmed search query (empty when not searching).
  final String query;

  /// The set of currently manually-expanded paths.
  final Set<String> expandedPaths;

  /// Invoked with [path] when the user taps this node's expand toggle.
  final ValueChanged<String> onToggle;

  bool get _isContainer => value is Map || value is List;

  @override
  Widget build(BuildContext context) {
    if (!_subtreeMatches(keyLabel, value, query)) {
      return const SizedBox.shrink();
    }

    if (!_isContainer) {
      return _KetokJsonLeaf(
        keyLabel: keyLabel,
        value: value,
        depth: depth,
        query: query,
      );
    }

    final List<MapEntry<String, dynamic>> children = _childEntries(value);
    final bool expanded =
        expandedPaths.contains(path) || (query.isNotEmpty && children.isNotEmpty);
    final String typeLabel = value is Map
        ? '{${children.length}}'
        : '[${children.length}]';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        InkWell(
          onTap: () => onToggle(path),
          child: Padding(
            padding: EdgeInsets.only(
              left: 8.0 * depth,
              top: 4,
              bottom: 4,
              right: 8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  expanded ? Icons.arrow_drop_down : Icons.arrow_right,
                  size: 20,
                ),
                Text(
                  keyLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 6),
                Text(typeLabel, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
        if (expanded)
          for (final MapEntry<String, dynamic> entry in children)
            KetokJsonNode(
              keyLabel: entry.key,
              path: '$path.${entry.key}',
              value: entry.value,
              depth: depth + 1,
              query: query,
              expandedPaths: expandedPaths,
              onToggle: onToggle,
            ),
      ],
    );
  }

  static List<MapEntry<String, dynamic>> _childEntries(dynamic value) {
    if (value is Map) {
      return <MapEntry<String, dynamic>>[
        for (final MapEntry<dynamic, dynamic> entry in value.entries)
          MapEntry<String, dynamic>(entry.key.toString(), entry.value),
      ];
    }
    if (value is List) {
      return <MapEntry<String, dynamic>>[
        for (int i = 0; i < value.length; i++)
          MapEntry<String, dynamic>('[$i]', value[i]),
      ];
    }
    return const <MapEntry<String, dynamic>>[];
  }
}

class _KetokJsonLeaf extends StatefulWidget {
  const _KetokJsonLeaf({
    required this.keyLabel,
    required this.value,
    required this.depth,
    required this.query,
  });

  final String keyLabel;
  final dynamic value;
  final int depth;
  final String query;

  @override
  State<_KetokJsonLeaf> createState() => _KetokJsonLeafState();
}

class _KetokJsonLeafState extends State<_KetokJsonLeaf> {
  static const int _collapseThreshold = 120;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final String display = _stringify(widget.value);
    final bool isLongString =
        widget.value is String && display.length > _collapseThreshold;
    final String shown = isLongString && !_expanded
        ? '${display.substring(0, _collapseThreshold)}…'
        : display;
    final TextStyle baseStyle =
        DefaultTextStyle.of(
          context,
        ).style.copyWith(fontFamily: 'monospace', fontSize: 13);

    return InkWell(
      onTap: isLongString
          ? () => setState(() => _expanded = !_expanded)
          : null,
      child: Padding(
        padding: EdgeInsets.only(
          left: 8.0 * widget.depth + 26,
          top: 3,
          bottom: 3,
          right: 8,
        ),
        // Text.rich (not bare RichText) so widget tests can find text via
        // find.text / find.textContaining without findRichText: true.
        child: Text.rich(
          TextSpan(
            children: <TextSpan>[
              TextSpan(
                text: '${widget.keyLabel}: ',
                style: baseStyle.copyWith(fontWeight: FontWeight.w600),
              ),
              ..._highlighted(shown, widget.query, baseStyle),
            ],
          ),
        ),
      ),
    );
  }
}

List<TextSpan> _highlighted(String text, String query, TextStyle style) {
  if (query.isEmpty) return <TextSpan>[TextSpan(text: text, style: style)];
  final String lower = text.toLowerCase();
  final List<TextSpan> spans = <TextSpan>[];
  int start = 0;
  while (true) {
    final int idx = lower.indexOf(query, start);
    if (idx == -1) {
      spans.add(TextSpan(text: text.substring(start), style: style));
      break;
    }
    if (idx > start) {
      spans.add(TextSpan(text: text.substring(start, idx), style: style));
    }
    spans.add(
      TextSpan(
        text: text.substring(idx, idx + query.length),
        style: style.copyWith(
          backgroundColor: Colors.yellow.withValues(alpha: 0.6),
        ),
      ),
    );
    start = idx + query.length;
  }
  return spans;
}

String _stringify(dynamic value) {
  if (value == null) return 'null';
  if (value is String) return value;
  return value.toString();
}

bool _subtreeMatches(String keyLabel, dynamic value, String query) {
  if (query.isEmpty) return true;
  if (keyLabel.toLowerCase().contains(query)) return true;
  if (value is Map) {
    for (final MapEntry<dynamic, dynamic> entry in value.entries) {
      if (_subtreeMatches(entry.key.toString(), entry.value, query)) {
        return true;
      }
    }
    return false;
  }
  if (value is List) {
    for (int i = 0; i < value.length; i++) {
      if (_subtreeMatches('[$i]', value[i], query)) return true;
    }
    return false;
  }
  return _stringify(value).toLowerCase().contains(query);
}
