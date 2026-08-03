/// Wire-faithful query-string parsing, shared by the call detail's "Query
/// parameters" section and `HarExporter`'s `queryString` array.
library;

/// One query-string parameter, in the order it appeared on the wire.
class JalaQueryParam {
  /// Creates a parameter pair.
  const JalaQueryParam({required this.name, required this.value});

  /// Percent-decoded parameter name, e.g. `item_type[]` for `item_type%5B%5D`.
  final String name;

  /// Percent-decoded value, or null when the parameter carried no `=` at
  /// all (e.g. `q` and `min_price` in `?q&page=1&min_price`).
  ///
  /// This is why the section does not use [Uri.queryParametersAll]: that
  /// maps a valueless parameter to an *empty list*, so iterating values
  /// yields no row for it and the parameter silently disappears from the
  /// table. Here a valueless parameter is a real row with a null value.
  final String? value;
}

/// Splits [uri]'s raw query into decoded [JalaQueryParam]s, preserving wire
/// order and repeated keys (`?tag=a&tag=b` stays two rows, in that order).
///
/// Use this rather than [Uri.queryParameters] anywhere the query is being
/// *shown* or *exported*: that getter collapses repeated keys to the last
/// value, so `?tag=a&tag=b` silently becomes a single `tag=b`.
///
/// Decoding is best-effort: a component that is not valid percent-encoding
/// is kept verbatim rather than throwing, because the inspector has to
/// render whatever the app actually put on the wire — including malformed
/// URLs, which are exactly the ones worth inspecting.
List<JalaQueryParam> parseQueryParams(Uri uri) {
  final String query = uri.query;
  if (query.isEmpty) return const <JalaQueryParam>[];
  final List<JalaQueryParam> params = <JalaQueryParam>[];
  for (final String segment in query.split('&')) {
    if (segment.isEmpty) continue;
    final int equals = segment.indexOf('=');
    if (equals == -1) {
      params.add(JalaQueryParam(name: _decode(segment), value: null));
    } else {
      params.add(
        JalaQueryParam(
          name: _decode(segment.substring(0, equals)),
          value: _decode(segment.substring(equals + 1)),
        ),
      );
    }
  }
  return params;
}

String _decode(String component) {
  try {
    return Uri.decodeQueryComponent(component);
  } on ArgumentError {
    // Invalid or truncated percent-escape — show the raw text.
    return component;
  }
}
