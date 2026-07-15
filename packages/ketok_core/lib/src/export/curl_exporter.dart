import '../model/network_call_entry.dart';
import '../redact/ketok_redactor.dart';

/// Exports a [NetworkCallEntry] as a runnable `curl` command.
class CurlExporter {
  const CurlExporter._();

  /// Renders [entry] as a multiline `curl` command with `\` continuations.
  ///
  /// - Values are single-quoted for the shell; embedded single quotes are
  ///   escaped with the standard `'\''` sequence, which also keeps unicode
  ///   and `$`/backtick content literal.
  /// - `--compressed` is added when the request's `accept-encoding` header
  ///   mentions gzip.
  /// - When [redacted] is true (the default) headers whose value was
  ///   masked at capture time are emitted with the mask placeholder; when
  ///   false those headers are omitted entirely.
  ///
  /// SPEC-NOTE: the spec's `redacted` flag cannot reveal original values —
  /// redaction happens at capture time and raw secrets never enter the
  /// store. The chosen semantics (false = drop masked headers instead of
  /// emitting a placeholder that would break the request anyway) is the
  /// simplest useful interpretation.
  static String export(NetworkCallEntry entry, {bool redacted = true}) {
    final List<String> lines = <String>[
      'curl -X ${entry.method}',
      _quote(entry.uri.toString()),
    ];

    var compressed = false;
    entry.requestHeaders.forEach((name, value) {
      if (name.toLowerCase() == 'accept-encoding' &&
          value.toLowerCase().contains('gzip')) {
        compressed = true;
      }
      if (!redacted && value == KetokRedactor.mask) return;
      lines.add('-H ${_quote('$name: $value')}');
    });

    if (compressed) {
      lines.add('--compressed');
    }

    final String? body = entry.requestBody.text;
    if (body != null && body.isNotEmpty) {
      lines.add('-d ${_quote(body)}');
    }

    return lines.join(' \\\n  ');
  }

  static String _quote(String value) => "'${value.replaceAll("'", r"'\''")}'";
}
