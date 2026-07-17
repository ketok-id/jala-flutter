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
  JalaRedactor({
    Set<String> redactedHeaders = defaultRedactedHeaders,
    List<Pattern> redactedBodyPatterns = const <Pattern>[],
    this.includeDefaultBodyPatterns = true,
  }) : _redactedHeaders = {
         for (final String name in redactedHeaders) name.toLowerCase(),
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

  final Set<String> _redactedHeaders;
  final List<Pattern> _redactedBodyPatterns;

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
