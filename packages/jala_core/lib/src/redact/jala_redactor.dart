/// Redacts sensitive header values and body content before they ever enter
/// the Jala store.
///
/// Redaction happens **at capture time** (in the client interceptor), so
/// raw secrets are never held in memory by Jala — this is the core of the
/// "production safety by default" promise (SPEC v0.1 positioning gap #5).
class JalaRedactor {
  /// Creates a redactor.
  ///
  /// [redactedHeaders] are matched case-insensitively against header names;
  /// matching headers keep their name but have their value replaced with
  /// [mask]. [redactedBodyPatterns] are applied to body text with every
  /// match replaced by [mask].
  JalaRedactor({
    Set<String> redactedHeaders = defaultRedactedHeaders,
    List<Pattern> redactedBodyPatterns = const <Pattern>[],
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
  };

  final Set<String> _redactedHeaders;
  final List<Pattern> _redactedBodyPatterns;

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

  /// Returns [body] with every match of the configured body patterns
  /// replaced by [mask]. Returns [body] unchanged when no patterns are
  /// configured.
  String redactBody(String body) {
    var result = body;
    for (final Pattern pattern in _redactedBodyPatterns) {
      result = result.replaceAll(pattern, mask);
    }
    return result;
  }
}
