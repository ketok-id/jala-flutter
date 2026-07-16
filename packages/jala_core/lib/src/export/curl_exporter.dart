import '../model/captured_body.dart';
import '../model/multipart_part.dart';
import '../model/network_call_entry.dart';
import '../redact/jala_redactor.dart';

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
      if (!redacted && value == JalaRedactor.mask) return;
      lines.add('-H ${_quote('$name: $value')}');
    });

    if (compressed) {
      lines.add('--compressed');
    }

    // SPEC-NOTE: a multipart body (the `@multipart` convention — see B3 in
    // docs/plans/track-b-v0.2.md) never had its field values or file bytes
    // retained in the first place, so it is rendered as `-F` flags built
    // entirely from the captured metadata: file parts use the captured
    // filename as a placeholder for the real local path (the actual file
    // was never read), and plain fields — whose value was never
    // captured either — are rendered as a size placeholder. Neither case
    // ever emits real content.
    final List<JalaMultipartPart>? multipart = CapturedBodyMultipart.partsOf(
      entry.requestBody,
    );
    if (multipart != null) {
      for (final JalaMultipartPart part in multipart) {
        lines.add('-F ${_quote(_multipartFieldSpec(part))}');
      }
    } else if (entry.requestBody.kind == BodyKind.image) {
      // SPEC-NOTE: image bodies are never inlined as `-d` (that would mean
      // base64-encoding raw bytes into the command); emit a size/mime
      // placeholder comment instead so the exported command stays runnable
      // and text-safe.
      lines.add(
        '# request body omitted: ${_imagePlaceholder(entry.requestBody)}',
      );
    } else {
      final String? body = entry.requestBody.text;
      if (body != null && body.isNotEmpty) {
        lines.add('-d ${_quote(body)}');
      }
    }

    return lines.join(' \\\n  ');
  }

  static String _multipartFieldSpec(JalaMultipartPart part) {
    if (part.filename != null) {
      final String type = part.contentType == null
          ? ''
          : ';type=${part.contentType}';
      return '${part.name}=@${part.filename}$type';
    }
    return '${part.name}=<${part.size} bytes, value not captured>';
  }

  static String _imagePlaceholder(CapturedBody body) =>
      '${body.contentType ?? 'image'}, ${body.originalSize ?? '?'} bytes';

  static String _quote(String value) => "'${value.replaceAll("'", r"'\''")}'";
}
