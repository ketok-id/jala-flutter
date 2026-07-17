import '../model/jala_call_status.dart';
import '../model/network_call_entry.dart';
import '../model/ws_connection_entry.dart';
import '../util/glob.dart';

/// A parsed DevTools-style filter query over [NetworkCallEntry]s (via
/// [matches]) and, in parallel, over [WsConnectionEntry]s (via
/// [matchesWs]) — the same query text is interpreted against whichever
/// grammar subset applies to the entry kind, so one filter bar can drive a
/// merged list (see docs/plans/track-d-v0.4.md D1/D4).
///
/// Grammar (all matching is case-insensitive):
///
/// - The query is split on whitespace into terms; **all** terms must match
///   (AND semantics).
/// - A leading `-` negates a term: `-status:404`.
/// - `method:get` / `m:get` — HTTP method; comma list allowed
///   (`m:get,post`). [NetworkCallEntry] only.
/// - `status:404` / `s:404` — exact status code.
/// - `status:4xx` — status class; `s:error` — statusCode >= 400 or the
///   call errored/was cancelled; `s:pending` — still in flight.
/// - `host:api.example.com` / `d:` — host, `*` wildcard allowed
///   (`host:*.example.com`).
/// - `path:/users` — path substring. [NetworkCallEntry] only.
/// - `type:json` / `t:json` — response content-type substring.
///   [NetworkCallEntry] only.
/// - `larger-than:10k` — responseSize > n (`k`/`m` suffixes; plain number
///   means bytes). [NetworkCallEntry] only.
/// - `slower-than:500` — duration > n milliseconds. [NetworkCallEntry]
///   only.
/// - `is:replay` — the call is a replay of another entry. [NetworkCallEntry]
///   only.
/// - `is:mocked` — the call was handled by a mock rule. [NetworkCallEntry]
///   only.
/// - `op:<name>` — GraphQL `operationName`, `*` wildcard allowed (same
///   semantics as `host:`). [NetworkCallEntry] only.
/// - `is:graphql` — `operationName != null`. [NetworkCallEntry] only.
/// - `is:subscription` — `operationType == 'subscription'`.
///   [NetworkCallEntry] only.
/// - `is:ws` — always false against [matches] (a [NetworkCallEntry] is
///   never a WS entry); always true against [matchesWs].
/// - `body:token` — substring of captured request or response body text.
///   [NetworkCallEntry] only.
/// - Any other term (including malformed structured terms) is free text
///   matched as a substring of `method + " " + full URL` for [matches], or
///   of the WS connection's URI for [matchesWs].
///
/// For [matchesWs], every structured key above marked "[NetworkCallEntry]
/// only" evaluates to **not matching** (so, e.g., `status:404` excludes
/// every WS connection rather than falling back to free text) — only
/// `host:`/`d:`, `status:`/`s:`, `is:ws`, and bare text apply.
class JalaFilter {
  JalaFilter._(this.query, this._terms, this._wsTerms);

  /// Parses [query] into a filter. Never throws; malformed terms degrade
  /// to free-text terms.
  factory JalaFilter.parse(String query) {
    final List<_Term> terms = <_Term>[];
    final List<_WsTerm> wsTerms = <_WsTerm>[];
    for (final String raw in query.trim().split(RegExp(r'\s+'))) {
      if (raw.isEmpty) continue;
      final bool negated = raw.startsWith('-') && raw.length > 1;
      final String body = negated ? raw.substring(1) : raw;
      terms.add(_Term(negated: negated, predicate: _parseTerm(body)));
      wsTerms.add(_WsTerm(negated: negated, predicate: _parseWsTerm(body)));
    }
    return JalaFilter._(query, terms, wsTerms);
  }

  /// The original query text this filter was parsed from.
  final String query;

  final List<_Term> _terms;
  final List<_WsTerm> _wsTerms;

  /// Whether this filter has no effective terms (matches everything).
  bool get isEmpty => _terms.isEmpty;

  /// Returns true when [entry] satisfies every term of the query.
  bool matches(NetworkCallEntry entry) {
    for (final _Term term in _terms) {
      final bool result = term.predicate(entry);
      if (result == term.negated) return false;
    }
    return true;
  }

  /// Returns true when [entry] satisfies every term of the query, under
  /// the WS-specific grammar subset (see the class doc).
  bool matchesWs(WsConnectionEntry entry) {
    for (final _WsTerm term in _wsTerms) {
      final bool result = term.predicate(entry);
      if (result == term.negated) return false;
    }
    return true;
  }

  static _Predicate _parseTerm(String term) {
    final int colon = term.indexOf(':');
    if (colon > 0 && colon < term.length - 1) {
      final String key = term.substring(0, colon).toLowerCase();
      final String value = term.substring(colon + 1);
      final _Predicate? structured = _parseStructured(key, value);
      if (structured != null) return structured;
    }
    return _freeText(term);
  }

  static _Predicate? _parseStructured(String key, String value) {
    switch (key) {
      case 'method':
      case 'm':
        return _method(value);
      case 'status':
      case 's':
        return _status(value);
      case 'host':
      case 'd':
        return _host(value);
      case 'path':
        return _path(value);
      case 'type':
      case 't':
        return _type(value);
      case 'larger-than':
        return _largerThan(value);
      case 'slower-than':
        return _slowerThan(value);
      case 'is':
        return _is(value);
      case 'body':
        return _body(value);
      case 'op':
        return _op(value);
      default:
        return null; // unknown key -> free text
    }
  }

  static _Predicate _method(String value) {
    final Set<String> methods = value
        .split(',')
        .map((m) => m.trim().toUpperCase())
        .where((m) => m.isNotEmpty)
        .toSet();
    return (e) => methods.contains(e.method.toUpperCase());
  }

  static _Predicate _status(String value) {
    final String v = value.toLowerCase();
    if (v == 'pending') {
      return (e) => e.status == JalaCallStatus.pending;
    }
    if (v == 'error') {
      return (e) =>
          (e.statusCode != null && e.statusCode! >= 400) ||
          e.status == JalaCallStatus.error ||
          e.status == JalaCallStatus.cancelled;
    }
    final RegExpMatch? classMatch = RegExp(r'^([1-5])xx$').firstMatch(v);
    if (classMatch != null) {
      final int hundreds = int.parse(classMatch.group(1)!);
      return (e) => e.statusCode != null && e.statusCode! ~/ 100 == hundreds;
    }
    final int? exact = int.tryParse(v);
    if (exact != null) {
      return (e) => e.statusCode == exact;
    }
    // Malformed status value -> free text over the whole term.
    return _freeText('status:$value');
  }

  static _Predicate _host(String value) {
    final String v = value.toLowerCase();
    if (v.contains('*')) {
      final String pattern = v.split('*').map(RegExp.escape).join('.*');
      final RegExp regex = RegExp('^$pattern\$');
      return (e) => regex.hasMatch(e.uri.host.toLowerCase());
    }
    return (e) => e.uri.host.toLowerCase() == v;
  }

  static _Predicate _path(String value) {
    final String v = value.toLowerCase();
    return (e) => e.uri.path.toLowerCase().contains(v);
  }

  static _Predicate _type(String value) {
    final String v = value.toLowerCase();
    return (e) {
      final String? contentType = _responseContentType(e);
      return contentType != null && contentType.toLowerCase().contains(v);
    };
  }

  static _Predicate _largerThan(String value) {
    final int? bytes = _parseSize(value);
    if (bytes == null) return _freeText('larger-than:$value');
    return (e) => e.responseSize != null && e.responseSize! > bytes;
  }

  static _Predicate _slowerThan(String value) {
    final int? ms = int.tryParse(value);
    if (ms == null) return _freeText('slower-than:$value');
    return (e) => e.duration != null && e.duration!.inMilliseconds > ms;
  }

  static _Predicate _is(String value) {
    switch (value.toLowerCase()) {
      case 'replay':
        return (e) => e.replayOf != null;
      case 'mocked':
        return (e) => e.mockRuleId != null;
      case 'graphql':
        return (e) => e.operationName != null;
      case 'subscription':
        return (e) => e.operationType == 'subscription';
      case 'ws':
        // A NetworkCallEntry is never a WS entry (see matchesWs for the
        // WS-side counterpart).
        return (e) => false;
      default:
        return _freeText('is:$value');
    }
  }

  static _Predicate _op(String value) {
    final String v = value.toLowerCase();
    return (e) =>
        e.operationName != null && globMatchesIgnoreCase(v, e.operationName!);
  }

  static _Predicate _body(String value) {
    final String v = value.toLowerCase();
    return (e) =>
        (e.requestBody.text?.toLowerCase().contains(v) ?? false) ||
        (e.responseBody.text?.toLowerCase().contains(v) ?? false);
  }

  static _Predicate _freeText(String term) {
    final String v = term.toLowerCase();
    return (e) => '${e.method} ${e.uri}'.toLowerCase().contains(v);
  }

  static String? _responseContentType(NetworkCallEntry e) {
    final String? fromBody = e.responseBody.contentType;
    if (fromBody != null) return fromBody;
    for (final MapEntry<String, String> header in e.responseHeaders.entries) {
      if (header.key.toLowerCase() == 'content-type') return header.value;
    }
    return null;
  }

  /// Parses `10`, `10k`, `2m` (case-insensitive) into bytes. Returns null
  /// when unparseable.
  static int? _parseSize(String value) {
    final String v = value.toLowerCase().trim();
    if (v.isEmpty) return null;
    int multiplier = 1;
    String digits = v;
    if (v.endsWith('k')) {
      multiplier = 1024;
      digits = v.substring(0, v.length - 1);
    } else if (v.endsWith('m')) {
      multiplier = 1024 * 1024;
      digits = v.substring(0, v.length - 1);
    }
    final num? parsed = num.tryParse(digits);
    if (parsed == null) return null;
    return (parsed * multiplier).round();
  }

  /// Structured keys that are meaningful for [NetworkCallEntry] but have no
  /// WS counterpart — a term using one of these keys never matches a
  /// [WsConnectionEntry] (see [_parseWsTerm]).
  static const Set<String> _wsNonApplicableKeys = <String>{
    'method',
    'm',
    'path',
    'type',
    't',
    'larger-than',
    'slower-than',
    'body',
    'op',
  };

  static _WsPredicate _parseWsTerm(String term) {
    final int colon = term.indexOf(':');
    if (colon > 0 && colon < term.length - 1) {
      final String key = term.substring(0, colon).toLowerCase();
      final String value = term.substring(colon + 1);
      if (_wsNonApplicableKeys.contains(key)) {
        return (w) => false;
      }
      switch (key) {
        case 'host':
        case 'd':
          return _wsHost(value);
        case 'status':
        case 's':
          return _wsStatus(value) ?? _wsFreeText('$key:$value');
        case 'is':
          return _wsIs(value);
      }
    }
    return _wsFreeText(term);
  }

  static _WsPredicate _wsHost(String value) {
    final String v = value.toLowerCase();
    return (w) => globMatchesIgnoreCase(v, w.uri.host);
  }

  static _WsPredicate? _wsStatus(String value) {
    final String v = value.toLowerCase();
    for (final WsConnectionStatus status in WsConnectionStatus.values) {
      if (status.name == v) {
        return (w) => w.status == status;
      }
    }
    return null; // unparseable -> caller degrades to free text.
  }

  static _WsPredicate _wsIs(String value) {
    switch (value.toLowerCase()) {
      case 'ws':
        return (w) => true;
      default:
        // e.g. is:graphql, is:replay, is:mocked — network-only concepts
        // that don't apply to a WS connection.
        return (w) => false;
    }
  }

  static _WsPredicate _wsFreeText(String term) {
    final String v = term.toLowerCase();
    return (w) => w.uri.toString().toLowerCase().contains(v);
  }
}

typedef _Predicate = bool Function(NetworkCallEntry entry);

class _Term {
  const _Term({required this.negated, required this.predicate});

  final bool negated;
  final _Predicate predicate;
}

typedef _WsPredicate = bool Function(WsConnectionEntry entry);

class _WsTerm {
  const _WsTerm({required this.negated, required this.predicate});

  final bool negated;
  final _WsPredicate predicate;
}
