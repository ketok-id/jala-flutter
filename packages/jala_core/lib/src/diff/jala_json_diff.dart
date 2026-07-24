/// The kind of change a [JsonDiffNode] represents relative to the two
/// decoded JSON values being compared (the "before"/`a` and "after"/`b`
/// sides passed to [JalaJsonDiff.diff]).
enum JsonDiffKind {
  /// Present only on the `b` side.
  added,

  /// Present only on the `a` side.
  removed,

  /// Present on both sides but not deep-equal (a differing primitive, or a
  /// container with at least one changed descendant, or a type change).
  changed,

  /// Deep-equal on both sides.
  unchanged,
}

/// One node in a structural diff of two decoded JSON values, produced by
/// [JalaJsonDiff.diff]. Container nodes ([JsonDiffKind.changed] /
/// [JsonDiffKind.unchanged] over a `Map`/`List`) carry [children]; leaves,
/// and whole added/removed subtrees, carry [before]/[after] values instead.
class JsonDiffNode {
  /// Creates a diff node. Prefer [JalaJsonDiff.diff] over building these by
  /// hand.
  const JsonDiffNode({
    required this.key,
    required this.kind,
    this.before,
    this.after,
    this.children = const <JsonDiffNode>[],
  });

  /// This node's label: `$` for the root, a map key, or `[i]` for a list
  /// index — matching the path scheme used by the JSON tree UI.
  final String key;

  /// How this node changed between the two sides.
  final JsonDiffKind kind;

  /// The value on the `a` side, or null when the node was [JsonDiffKind.added]
  /// (for a container node, the whole `a` value).
  final Object? before;

  /// The value on the `b` side, or null when the node was
  /// [JsonDiffKind.removed] (for a container node, the whole `b` value).
  final Object? after;

  /// Child diffs, when this node is a `Map`/`List` present on both sides.
  /// Empty for leaves and for whole added/removed subtrees.
  final List<JsonDiffNode> children;

  /// Whether this node or any descendant differs between the two sides.
  bool get hasChanges => kind != JsonDiffKind.unchanged;
}

/// Computes a structural, order-stable diff between two already-decoded JSON
/// values (the result of `jsonDecode`). Pure and UI-agnostic: the UI walks
/// the returned [JsonDiffNode] tree and colors rows by [JsonDiffKind].
///
/// - Maps diff key-wise: `a`'s keys in their original order, then keys only
///   present in `b`.
/// - Lists diff positionally (index-wise); a length change surfaces as
///   trailing [JsonDiffKind.added]/[JsonDiffKind.removed] elements. Keyed or
///   longest-common-subsequence list diffing is a deliberate future
///   refinement (see docs/plans/track-f-v0.6-inspect-deeper.md, F1).
/// - A type change (e.g. `1` → `[1]`, or object → string) is a single
///   [JsonDiffKind.changed] leaf.
class JalaJsonDiff {
  const JalaJsonDiff._();

  /// Sentinel marking a key/index that is absent on one side, so a present
  /// explicit `null` is never confused with "not there".
  static const Object _absent = Object();

  /// Diffs [a] against [b], returning the root node (labelled `$`).
  static JsonDiffNode diff(Object? a, Object? b) => _node(r'$', a, b);

  static JsonDiffNode _node(String key, Object? a, Object? b) {
    if (identical(a, _absent)) {
      return JsonDiffNode(key: key, kind: JsonDiffKind.added, after: b);
    }
    if (identical(b, _absent)) {
      return JsonDiffNode(key: key, kind: JsonDiffKind.removed, before: a);
    }
    if (a is Map && b is Map) return _mapNode(key, a, b);
    if (a is List && b is List) return _listNode(key, a, b);
    // Primitive vs primitive, or a type change (Map↔List↔primitive).
    return JsonDiffNode(
      key: key,
      kind: _deepEquals(a, b) ? JsonDiffKind.unchanged : JsonDiffKind.changed,
      before: a,
      after: b,
    );
  }

  static JsonDiffNode _mapNode(String key, Map<Object?, Object?> a,
      Map<Object?, Object?> b) {
    final List<JsonDiffNode> children = <JsonDiffNode>[];
    final Set<String> seen = <String>{};
    for (final MapEntry<Object?, Object?> entry in a.entries) {
      final String k = entry.key.toString();
      seen.add(k);
      children.add(
        _node(k, entry.value, b.containsKey(entry.key) ? b[entry.key] : _absent),
      );
    }
    for (final MapEntry<Object?, Object?> entry in b.entries) {
      final String k = entry.key.toString();
      if (seen.contains(k)) continue;
      children.add(_node(k, _absent, entry.value));
    }
    return _container(key, a, b, children);
  }

  static JsonDiffNode _listNode(String key, List<Object?> a, List<Object?> b) {
    final List<JsonDiffNode> children = <JsonDiffNode>[];
    final int max = a.length > b.length ? a.length : b.length;
    for (int i = 0; i < max; i++) {
      children.add(
        _node(
          '[$i]',
          i < a.length ? a[i] : _absent,
          i < b.length ? b[i] : _absent,
        ),
      );
    }
    return _container(key, a, b, children);
  }

  static JsonDiffNode _container(
    String key,
    Object? a,
    Object? b,
    List<JsonDiffNode> children,
  ) {
    final bool changed = children.any((JsonDiffNode c) => c.hasChanges);
    return JsonDiffNode(
      key: key,
      kind: changed ? JsonDiffKind.changed : JsonDiffKind.unchanged,
      before: a,
      after: b,
      children: children,
    );
  }

  static bool _deepEquals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final MapEntry<Object?, Object?> entry in a.entries) {
        if (!b.containsKey(entry.key)) return false;
        if (!_deepEquals(entry.value, b[entry.key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}
