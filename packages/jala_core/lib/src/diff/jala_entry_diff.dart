import 'dart:convert';

import '../model/captured_body.dart';
import '../model/network_call_entry.dart';
import 'jala_json_diff.dart';

/// A single header's change between two [NetworkCallEntry] values. Header
/// names are matched case-insensitively; [name] preserves the `b`-side
/// casing when present, otherwise the `a`-side.
class HeaderDiff {
  /// Creates a header diff row.
  const HeaderDiff({
    required this.name,
    required this.kind,
    this.before,
    this.after,
  });

  /// Display name for the header.
  final String name;

  /// How the header changed (reuses the JSON diff vocabulary).
  final JsonDiffKind kind;

  /// The `a`-side value, or null when [JsonDiffKind.added].
  final String? before;

  /// The `b`-side value, or null when [JsonDiffKind.removed].
  final String? after;
}

/// Structural diff of two captured calls, for the inspector's compare view.
///
/// Header sets and the status line are always diffed; request/response
/// bodies are diffed structurally only when *both* sides are JSON (see
/// [requestBodyComparable] / [responseBodyComparable]) — otherwise the UI
/// falls back to a plain before/after text view.
class JalaEntryDiff {
  /// Creates an entry diff. Prefer [JalaEntryDiff.of].
  const JalaEntryDiff({
    required this.requestHeaders,
    required this.responseHeaders,
    required this.statusBefore,
    required this.statusAfter,
    required this.requestBodyDiff,
    required this.responseBodyDiff,
    required this.requestBodyComparable,
    required this.responseBodyComparable,
  });

  /// Request-header diffs, `a`-order first then `b`-only headers.
  final List<HeaderDiff> requestHeaders;

  /// Response-header diffs, ordered the same way.
  final List<HeaderDiff> responseHeaders;

  /// Status code on the `a` side (null while that call was pending).
  final int? statusBefore;

  /// Status code on the `b` side.
  final int? statusAfter;

  /// Structural diff of the two request bodies, or null when they are not
  /// both JSON.
  final JsonDiffNode? requestBodyDiff;

  /// Structural diff of the two response bodies, or null when they are not
  /// both JSON.
  final JsonDiffNode? responseBodyDiff;

  /// Whether both request bodies were JSON (so [requestBodyDiff] is set).
  final bool requestBodyComparable;

  /// Whether both response bodies were JSON (so [responseBodyDiff] is set).
  final bool responseBodyComparable;

  /// Whether the status code differs between the two calls.
  bool get statusChanged => statusBefore != statusAfter;

  /// Diffs [a] against [b].
  static JalaEntryDiff of(NetworkCallEntry a, NetworkCallEntry b) {
    final _JsonBody reqA = _JsonBody.from(a.requestBody);
    final _JsonBody reqB = _JsonBody.from(b.requestBody);
    final _JsonBody resA = _JsonBody.from(a.responseBody);
    final _JsonBody resB = _JsonBody.from(b.responseBody);
    final bool reqComparable = reqA.isJson && reqB.isJson;
    final bool resComparable = resA.isJson && resB.isJson;
    return JalaEntryDiff(
      requestHeaders: _headerDiffs(a.requestHeaders, b.requestHeaders),
      responseHeaders: _headerDiffs(a.responseHeaders, b.responseHeaders),
      statusBefore: a.statusCode,
      statusAfter: b.statusCode,
      requestBodyComparable: reqComparable,
      responseBodyComparable: resComparable,
      requestBodyDiff:
          reqComparable ? JalaJsonDiff.diff(reqA.value, reqB.value) : null,
      responseBodyDiff:
          resComparable ? JalaJsonDiff.diff(resA.value, resB.value) : null,
    );
  }

  static List<HeaderDiff> _headerDiffs(
    Map<String, String> a,
    Map<String, String> b,
  ) {
    // Index each side by lowercased name so matching is case-insensitive,
    // but keep the original name for display.
    final Map<String, MapEntry<String, String>> aByLower =
        <String, MapEntry<String, String>>{};
    for (final MapEntry<String, String> e in a.entries) {
      aByLower[e.key.toLowerCase()] = e;
    }
    final Map<String, MapEntry<String, String>> bByLower =
        <String, MapEntry<String, String>>{};
    for (final MapEntry<String, String> e in b.entries) {
      bByLower[e.key.toLowerCase()] = e;
    }

    final List<HeaderDiff> out = <HeaderDiff>[];
    final Set<String> seen = <String>{};
    for (final MapEntry<String, String> e in a.entries) {
      final String lower = e.key.toLowerCase();
      seen.add(lower);
      final MapEntry<String, String>? bEntry = bByLower[lower];
      if (bEntry == null) {
        out.add(
          HeaderDiff(name: e.key, kind: JsonDiffKind.removed, before: e.value),
        );
      } else {
        out.add(
          HeaderDiff(
            name: bEntry.key,
            kind: e.value == bEntry.value
                ? JsonDiffKind.unchanged
                : JsonDiffKind.changed,
            before: e.value,
            after: bEntry.value,
          ),
        );
      }
    }
    for (final MapEntry<String, String> e in b.entries) {
      if (seen.contains(e.key.toLowerCase())) continue;
      out.add(
        HeaderDiff(name: e.key, kind: JsonDiffKind.added, after: e.value),
      );
    }
    return out;
  }
}

/// A captured body decoded to a JSON value, or flagged non-JSON.
class _JsonBody {
  const _JsonBody(this.isJson, this.value);

  factory _JsonBody.from(CapturedBody body) {
    if (body.kind != BodyKind.json || body.text == null) {
      return const _JsonBody(false, null);
    }
    try {
      return _JsonBody(true, jsonDecode(body.text!));
    } on FormatException {
      return const _JsonBody(false, null);
    }
  }

  final bool isJson;
  final Object? value;
}
