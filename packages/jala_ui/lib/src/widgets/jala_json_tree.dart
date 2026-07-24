import 'package:flutter/material.dart';

/// A self-built expandable tree for JSON values.
///
/// Maps and lists are expandable nodes; primitives are leaf rows. Long
/// string leaves are ellipsized with tap-to-expand. An in-body substring
/// search field filters to matching nodes (and their ancestors) and
/// highlights the match.
///
/// The tree is **flattened** into a list of rows and rendered with a
/// [ListView.builder] so only rows that intersect the viewport are built.
/// When the parent gives an unbounded height (e.g. nested in another
/// scroll view), the list shrink-wraps and defers scrolling to the parent —
/// still flat (no recursive [Column]s), which keeps large expanded payloads
/// cheaper to rebuild than the pre-0.6 recursive tree.
class JalaJsonTree extends StatefulWidget {
  /// Creates a JSON tree over an already-decoded [data] value (the result
  /// of `jsonDecode`).
  const JalaJsonTree({required this.data, super.key});

  /// The decoded JSON value: a `Map<String, dynamic>`, `List<dynamic>`, or
  /// a primitive.
  final dynamic data;

  @override
  State<JalaJsonTree> createState() => _JalaJsonTreeState();
}

class _JalaJsonTreeState extends State<JalaJsonTree> {
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

  bool get _isContainer => widget.data is Map || widget.data is List;

  /// Adds every container path in the tree to [_expanded] so the whole
  /// structure is open at once.
  void _expandAll() {
    final Set<String> paths = <String>{};
    void walk(String path, dynamic value) {
      if (value is Map) {
        paths.add(path);
        for (final MapEntry<dynamic, dynamic> entry in value.entries) {
          walk('$path.${entry.key}', entry.value);
        }
      } else if (value is List) {
        paths.add(path);
        for (int i = 0; i < value.length; i++) {
          walk('$path.[$i]', value[i]);
        }
      }
    }

    walk(_rootPath, widget.data);
    setState(() => _expanded
      ..clear()
      ..addAll(paths));
  }

  /// Collapses everything back to the root (its top-level keys shown, each
  /// collapsed) — matching the initial state.
  void _collapseAll() {
    setState(() => _expanded
      ..clear()
      ..add(_rootPath));
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  /// Counts the nodes whose key or (leaf) value contains [query] — the same
  /// hit rule the filter uses, so the shown count matches what stays visible.
  /// The synthetic root (`$`) is never counted.
  int _matchCount(String query) {
    int node(String keyLabel, dynamic value, {bool isRoot = false}) {
      final bool keyHit = !isRoot && keyLabel.toLowerCase().contains(query);
      if (value is Map) {
        int count = keyHit ? 1 : 0;
        for (final MapEntry<dynamic, dynamic> entry in value.entries) {
          count += node(entry.key.toString(), entry.value);
        }
        return count;
      }
      if (value is List) {
        int count = keyHit ? 1 : 0;
        for (int i = 0; i < value.length; i++) {
          count += node('[$i]', value[i]);
        }
        return count;
      }
      final bool valueHit = _stringify(value).toLowerCase().contains(query);
      return keyHit || valueHit ? 1 : 0;
    }

    return node(_rootPath, widget.data, isRoot: true);
  }

  /// Walks [widget.data] under the current expansion + search state and
  /// produces the visible row list for the lazy [ListView].
  List<_FlatRow> _flatten(String query) {
    final List<_FlatRow> rows = <_FlatRow>[];

    void walk(String keyLabel, String path, dynamic value, int depth) {
      if (!_subtreeMatches(keyLabel, value, query)) return;

      final bool isContainer = value is Map || value is List;
      if (!isContainer) {
        rows.add(
          _FlatRow.leaf(
            keyLabel: keyLabel,
            path: path,
            value: value,
            depth: depth,
          ),
        );
        return;
      }

      final List<MapEntry<String, dynamic>> children = _childEntries(value);
      final bool expanded =
          _expanded.contains(path) ||
          (query.isNotEmpty && children.isNotEmpty);
      rows.add(
        _FlatRow.container(
          keyLabel: keyLabel,
          path: path,
          value: value,
          depth: depth,
          childCount: children.length,
          expanded: expanded,
        ),
      );
      if (!expanded) return;
      for (final MapEntry<String, dynamic> entry in children) {
        walk(entry.key, '$path.${entry.key}', entry.value, depth + 1);
      }
    }

    walk(_rootPath, _rootPath, widget.data, 0);
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final String query = _query.trim().toLowerCase();
    final int matches = query.isEmpty ? 0 : _matchCount(query);
    final List<_FlatRow> rows = _flatten(query);

    final Widget toolbar = Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText: 'Search in JSON…',
                border: const OutlineInputBorder(),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Clear search',
                        visualDensity: VisualDensity.compact,
                        onPressed: _clearSearch,
                      ),
              ),
              onChanged: (String value) => setState(() => _query = value),
            ),
          ),
          if (_isContainer) ...<Widget>[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.unfold_more, size: 20),
              tooltip: 'Expand all',
              visualDensity: VisualDensity.compact,
              onPressed: _expandAll,
            ),
            IconButton(
              icon: const Icon(Icons.unfold_less, size: 20),
              tooltip: 'Collapse all',
              visualDensity: VisualDensity.compact,
              onPressed: _collapseAll,
            ),
          ],
        ],
      ),
    );

    final Widget? matchBanner = query.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                matches == 0
                    ? 'No matches'
                    : matches == 1
                    ? '1 match'
                    : '$matches matches',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool bounded = constraints.hasBoundedHeight;
        final Widget list = ListView.builder(
          // Nested-in-scroll-view path: size to content, let the parent
          // scroll. Bounded path: fill the remaining flex slot and
          // virtualize against this viewport.
          shrinkWrap: !bounded,
          physics: bounded
              ? const AlwaysScrollableScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          itemCount: rows.length,
          itemBuilder: (BuildContext context, int index) {
            final _FlatRow row = rows[index];
            if (row.isContainer) {
              return _JsonContainerRow(
                row: row,
                onToggle: _toggle,
              );
            }
            return _JalaJsonLeaf(
              keyLabel: row.keyLabel,
              value: row.value,
              depth: row.depth,
              query: query,
            );
          },
        );

        if (bounded) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              toolbar,
              ?matchBanner,
              Expanded(child: list),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            toolbar,
            ?matchBanner,
            list,
          ],
        );
      },
    );
  }
}

/// One visible row in the flattened JSON tree.
@immutable
class _FlatRow {
  const _FlatRow.leaf({
    required this.keyLabel,
    required this.path,
    required this.value,
    required this.depth,
  }) : isContainer = false,
       childCount = 0,
       expanded = false;

  const _FlatRow.container({
    required this.keyLabel,
    required this.path,
    required this.value,
    required this.depth,
    required this.childCount,
    required this.expanded,
  }) : isContainer = true;

  final String keyLabel;
  final String path;
  final dynamic value;
  final int depth;
  final bool isContainer;
  final int childCount;
  final bool expanded;
}

/// Expandable container row (map / list header).
class _JsonContainerRow extends StatelessWidget {
  const _JsonContainerRow({required this.row, required this.onToggle});

  final _FlatRow row;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final String typeLabel = row.value is Map
        ? '{${row.childCount}}'
        : '[${row.childCount}]';

    return InkWell(
      onTap: () => onToggle(row.path),
      child: Padding(
        padding: EdgeInsets.only(
          left: 8.0 * row.depth,
          top: 4,
          bottom: 4,
          right: 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              row.expanded ? Icons.arrow_drop_down : Icons.arrow_right,
              size: 20,
            ),
            Text(
              row.keyLabel,
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
    );
  }
}

/// One node (container or leaf) of a [JalaJsonTree]. Kept public so existing
/// tests / callers that target nodes by type keep working; new code should
/// treat the flattened tree as the sole layout path.
@visibleForTesting
class JalaJsonNode extends StatelessWidget {
  /// Creates a node.
  const JalaJsonNode({
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
    // Compatibility shim: render a single flat row (no recursive children).
    // Production layout goes through [JalaJsonTree]'s flattened list.
    if (!_subtreeMatches(keyLabel, value, query)) {
      return const SizedBox.shrink();
    }
    if (!_isContainer) {
      return _JalaJsonLeaf(
        keyLabel: keyLabel,
        value: value,
        depth: depth,
        query: query,
      );
    }
    final List<MapEntry<String, dynamic>> children = _childEntries(value);
    final bool expanded =
        expandedPaths.contains(path) ||
        (query.isNotEmpty && children.isNotEmpty);
    return _JsonContainerRow(
      row: _FlatRow.container(
        keyLabel: keyLabel,
        path: path,
        value: value,
        depth: depth,
        childCount: children.length,
        expanded: expanded,
      ),
      onToggle: onToggle,
    );
  }
}

class _JalaJsonLeaf extends StatefulWidget {
  const _JalaJsonLeaf({
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
  State<_JalaJsonLeaf> createState() => _JalaJsonLeafState();
}

class _JalaJsonLeafState extends State<_JalaJsonLeaf> {
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
    final TextStyle baseStyle = DefaultTextStyle.of(
      context,
    ).style.copyWith(fontFamily: 'monospace', fontSize: 13);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final _JsonLeafStyle leaf = _JsonLeafStyle.of(
      widget.value,
      Theme.of(context).brightness,
      scheme,
    );

    return InkWell(
      onTap: isLongString ? () => setState(() => _expanded = !_expanded) : null,
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
              ..._highlighted(
                shown,
                widget.query,
                baseStyle.copyWith(
                  color: leaf.color,
                  fontStyle: leaf.fontStyle,
                ),
                highlightBg: scheme.tertiaryContainer,
                highlightFg: scheme.onTertiaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resolves the text color (and, for `null`, the italic style) a JSON leaf
/// value is rendered with, so strings, numbers, booleans and null are
/// distinguishable at a glance. Colors are chosen per [Brightness] to stay
/// legible in both themes.
class _JsonLeafStyle {
  const _JsonLeafStyle(this.color, this.fontStyle);

  factory _JsonLeafStyle.of(
    dynamic value,
    Brightness brightness,
    ColorScheme scheme,
  ) {
    final bool dark = brightness == Brightness.dark;
    if (value == null) {
      return _JsonLeafStyle(scheme.onSurfaceVariant, FontStyle.italic);
    }
    if (value is String) {
      return _JsonLeafStyle(
        dark ? const Color(0xFF9ECE6A) : const Color(0xFF2E7D32),
        FontStyle.normal,
      );
    }
    if (value is num) {
      return _JsonLeafStyle(
        dark ? const Color(0xFF7AA2F7) : const Color(0xFF1565C0),
        FontStyle.normal,
      );
    }
    if (value is bool) {
      return _JsonLeafStyle(
        dark ? const Color(0xFFE0AF68) : const Color(0xFFB26A00),
        FontStyle.normal,
      );
    }
    return _JsonLeafStyle(scheme.onSurface, FontStyle.normal);
  }

  final Color color;
  final FontStyle fontStyle;
}

List<TextSpan> _highlighted(
  String text,
  String query,
  TextStyle style, {
  required Color highlightBg,
  required Color highlightFg,
}) {
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
          backgroundColor: highlightBg,
          color: highlightFg,
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

List<MapEntry<String, dynamic>> _childEntries(dynamic value) {
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
