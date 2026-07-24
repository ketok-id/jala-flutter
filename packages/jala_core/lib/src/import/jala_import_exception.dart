/// Thrown by `JalaCurlCodec.decode` when a pasted command cannot be parsed
/// into a request (empty input, no URL, or an unparseable URL). HAR import
/// reuses `JalaSessionFormatException` instead, since it yields a whole
/// session rather than a single request.
class JalaImportFormatException implements Exception {
  /// Creates the exception with a human-readable [message].
  const JalaImportFormatException(this.message);

  /// Explains what was wrong with the input.
  final String message;

  @override
  String toString() => 'JalaImportFormatException: $message';
}
