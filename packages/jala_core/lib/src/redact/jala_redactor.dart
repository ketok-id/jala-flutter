/// Redacts sensitive header values and body content before they ever enter
/// the Jala store.
///
/// Redaction happens **at capture time** (in the client interceptor), so
/// raw secrets are never held in memory by Jala — this is the core of the
/// "production safety by default" promise (SPEC v0.1 positioning gap #5).
///
/// See also [docs/SECURITY.md](https://github.com/ketok-id/jala-flutter/blob/main/docs/SECURITY.md).
class JalaRedactor {
  /// Creates a redactor.
  ///
  /// [redactedHeaders] are matched case-insensitively against header names;
  /// matching headers keep their name but have their value replaced with
  /// [mask].
  ///
  /// [redactedBodyPatterns] are applied after the built-in JSON / form
  /// secret-key patterns (when [includeDefaultBodyPatterns] is true): every
  /// match of a custom [Pattern] is replaced by [mask].
  /// [redactedQueryParams] are matched against query-parameter names
  /// ignoring case, `-` and `_`, so `access_token`, `access-token` and
  /// `accessToken` are all one entry; matching parameters keep their name
  /// but have their value replaced with [mask]. See [redactUri].
  JalaRedactor({
    Set<String> redactedHeaders = defaultRedactedHeaders,
    List<Pattern> redactedBodyPatterns = const <Pattern>[],
    Set<String> redactedQueryParams = defaultRedactedQueryParams,
    this.includeDefaultBodyPatterns = true,
  }) : _redactedHeaders = {
         for (final String name in redactedHeaders) name.toLowerCase(),
       },
       _redactedQueryParams = {
         for (final String name in redactedQueryParams)
           _normalizeParamName(name),
       },
       _redactedBodyPatterns = List.unmodifiable(redactedBodyPatterns);

  /// The replacement string used for redacted values.
  static const String mask = '••••••';

  /// Header names redacted by default (matched case-insensitively).
  static const Set<String> defaultRedactedHeaders = {
    'authorization',
    'proxy-authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
    'x-auth-token',
    'api-key',
    // Common enterprise / cloud auth headers
    'x-access-token',
    'x-refresh-token',
    'x-csrf-token',
    'x-xsrf-token',
    'x-session-token',
    'x-session-id',
    'x-amz-security-token',
  };

  /// JSON object members whose string values are masked by default, e.g.
  /// `"password":"s3cret"` → `"password":"••••••"`.
  ///
  /// Applied only when [includeDefaultBodyPatterns] is true.
  static final RegExp defaultJsonSecretValues = RegExp(
    r'("(?:'
    r'password|passwd|pwd|secret|token|'
    r'access[_-]?token|refresh[_-]?token|id[_-]?token|'
    r'api[_-]?key|apikey|client[_-]?secret|private[_-]?key|'
    r'auth[_-]?token|session[_-]?token|bearer|client[_-]?id'
    r')"\s*:\s*)"(?:\\.|[^"\\])*"',
    caseSensitive: false,
  );

  /// `application/x-www-form-urlencoded` style pairs, e.g.
  /// `password=s3cret` → `password=••••••`.
  static final RegExp defaultFormSecretValues = RegExp(
    r'((?:^|[&?])(?:'
    r'password|passwd|pwd|secret|token|'
    r'access[_-]?token|refresh[_-]?token|id[_-]?token|'
    r'api[_-]?key|apikey|client[_-]?secret|'
    r'auth[_-]?token|session[_-]?token'
    r')=)([^&\s#]*)',
    caseSensitive: false,
  );

  /// Query-parameter names whose values are masked by [redactUri], matched
  /// ignoring case, `-` and `_`.
  ///
  /// Mirrors the name list in [defaultFormSecretValues] — a query string and
  /// an `x-www-form-urlencoded` body are the same syntax carrying the same
  /// secrets — plus the signature parameters that make a presigned URL
  /// itself a credential.
  ///
  /// Deliberately excluded as too generic to mask without surprising
  /// developers: bare `key` and `code` (country/error codes), and
  /// `client_id`, which OAuth treats as public. Pass your own set to the
  /// constructor to add them.
  static const Set<String> defaultRedactedQueryParams = {
    'password',
    'passwd',
    'pwd',
    'secret',
    'client_secret',
    'token',
    'access_token',
    'refresh_token',
    'id_token',
    'auth_token',
    'session_token',
    'api_key',
    'apikey',
    // A presigned URL's signature *is* the credential.
    'signature',
    'sig',
    'x_amz_signature',
    'x_amz_security_token',
    'x_amz_credential',
  };

  final Set<String> _redactedHeaders;
  final Set<String> _redactedQueryParams;
  final List<Pattern> _redactedBodyPatterns;

  static String _normalizeParamName(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[-_]'), '');

  /// Whether built-in JSON/form secret-key redaction runs in [redactBody].
  final bool includeDefaultBodyPatterns;

  /// Returns a copy of [headers] with the values of all redacted header
  /// names (case-insensitive match) replaced by [mask]. Header names and
  /// ordering are preserved.
  Map<String, String> redactHeaders(Map<String, String> headers) {
    return {
      for (final MapEntry<String, String> entry in headers.entries)
        entry.key: _redactedHeaders.contains(entry.key.toLowerCase())
            ? mask
            : entry.value,
    };
  }

  /// Returns [uri] with the values of sensitive query parameters (see
  /// [defaultRedactedQueryParams]) replaced by [mask], leaving scheme,
  /// host, path, fragment and every other parameter untouched.
  ///
  /// A token in a URL is as sensitive as one in a header — and more exposed,
  /// since the full URL is what shows on the call list, in the detail
  /// screen, and in every cURL / HAR / Dart-snippet export. Adapters call
  /// this at capture time, so the real value never reaches the store.
  ///
  /// The raw query is rewritten segment by segment rather than round-tripped
  /// through [Uri.queryParameters]: that would collapse repeated keys, drop
  /// valueless parameters (`?q&page=1`) entirely, and re-encode the rest,
  /// none of which an inspector may do to the URL the app actually sent.
  ///
  /// Parameters with an empty value (`?token=`) are left alone — masking
  /// them would imply a secret that was never there.
  ///
  /// Replay drops masked values rather than resending them, exactly as it
  /// already does for redacted headers (see `JalaDioReplayer`).
  Uri redactUri(Uri uri) {
    final String query = uri.query;
    if (query.isEmpty) return uri;
    bool changed = false;
    final List<String> segments = <String>[];
    for (final String segment in query.split('&')) {
      final int equals = segment.indexOf('=');
      if (equals == -1 || equals == segment.length - 1) {
        segments.add(segment);
        continue;
      }
      final String rawName = segment.substring(0, equals);
      if (!_redactedQueryParams.contains(
        _normalizeParamName(_decodeParamName(rawName)),
      )) {
        segments.add(segment);
        continue;
      }
      // `mask` is written raw; Uri.replace percent-encodes it, and parsing
      // the result back yields `mask` again (so replay can detect it).
      segments.add('$rawName=$mask');
      changed = true;
    }
    if (!changed) return uri;
    return uri.replace(query: segments.join('&'));
  }

  /// Returns [uri] with every query parameter whose value is [mask] removed
  /// entirely.
  ///
  /// Replayers call this for the same reason they drop headers masked by
  /// [redactUri]: Jala never retained the real secret, so resending
  /// `token=••••••` would issue a request with a knowingly wrong
  /// credential. Dropping it fails the same way a dropped `Authorization`
  /// header does — visibly, at the server — instead of silently.
  static Uri stripMaskedQueryParams(Uri uri) {
    final String query = uri.query;
    if (query.isEmpty) return uri;
    bool changed = false;
    final List<String> kept = <String>[];
    for (final String segment in query.split('&')) {
      final int equals = segment.indexOf('=');
      if (equals != -1 &&
          _decodeParamName(segment.substring(equals + 1)) == mask) {
        changed = true;
        continue;
      }
      kept.add(segment);
    }
    if (!changed) return uri;
    if (kept.isNotEmpty) return uri.replace(query: kept.join('&'));
    // Rebuilt rather than `replace(query: '')`, which leaves a bare `?`.
    return Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
      fragment: uri.hasFragment ? uri.fragment : null,
    );
  }

  static String _decodeParamName(String name) {
    try {
      return Uri.decodeQueryComponent(name);
    } on ArgumentError {
      // Malformed percent-escape — match against the raw name instead.
      return name;
    }
  }

  /// Returns [body] with default secret-key patterns (when enabled) and
  /// every custom [redactedBodyPatterns] match replaced by [mask].
  String redactBody(String body) {
    var result = body;
    if (includeDefaultBodyPatterns) {
      result = result.replaceAllMapped(
        defaultJsonSecretValues,
        (Match m) => '${m[1]}"$mask"',
      );
      result = result.replaceAllMapped(
        defaultFormSecretValues,
        (Match m) => '${m[1]}$mask',
      );
    }
    for (final Pattern pattern in _redactedBodyPatterns) {
      result = result.replaceAll(pattern, mask);
    }
    return result;
  }
}
