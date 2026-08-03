import '../model/captured_body.dart';
import '../model/network_call_entry.dart';
import '../redact/jala_redactor.dart';

/// Exports a [NetworkCallEntry] as a runnable Dart snippet using
/// `package:dio`.
class DartSnippetExporter {
  const DartSnippetExporter._();

  /// Renders [entry] as a copy-pasteable `dio.request(...)` snippet.
  ///
  /// When [redacted] is true (the default) headers whose value was masked
  /// at capture time keep the mask placeholder, flagged with a trailing
  /// comment so the snippet cannot quietly be run with a credential that
  /// was never real. When false those headers are omitted entirely —
  /// matching `CurlExporter.export`'s `redacted` flag, and for the same
  /// reason: redaction happens at capture time, so there is no original
  /// value for either mode to reveal.
  static String export(NetworkCallEntry entry, {bool redacted = true}) {
    final StringBuffer buffer = StringBuffer()
      ..writeln('final dio = Dio();')
      ..writeln('final response = await dio.request(')
      ..writeln('  ${_string(entry.uri.toString())},')
      ..writeln('  options: Options(');
    buffer.writeln('    method: ${_string(entry.method)},');

    final Map<String, String> headers = redacted
        ? entry.requestHeaders
        : <String, String>{
            for (final MapEntry<String, String> h
                in entry.requestHeaders.entries)
              if (h.value != JalaRedactor.mask) h.key: h.value,
          };
    if (headers.isNotEmpty) {
      buffer.writeln('    headers: {');
      headers.forEach((name, value) {
        final String masked = value == JalaRedactor.mask
            ? ' // redacted at capture — replace with the real value'
            : '';
        buffer.writeln('      ${_string(name)}: ${_string(value)},$masked');
      });
      buffer.writeln('    },');
    }
    buffer.writeln('  ),');

    // SPEC-NOTE: image bodies are never inlined as a Dart string literal
    // (that would mean base64-encoding raw bytes into the snippet); emit a
    // size/mime placeholder comment instead.
    if (entry.requestBody.kind == BodyKind.image) {
      buffer.writeln(
        '  // request body omitted: ${_imagePlaceholder(entry.requestBody)}',
      );
    } else {
      final String? body = entry.requestBody.text;
      if (body != null && body.isNotEmpty) {
        if (entry.requestBody.kind == BodyKind.json) {
          buffer.writeln('  data: jsonDecode(${_string(body)}),');
        } else {
          buffer.writeln('  data: ${_string(body)},');
        }
      }
    }
    buffer
      ..writeln(');')
      ..write('print(response.data);');
    return buffer.toString();
  }

  static String _imagePlaceholder(CapturedBody body) =>
      '${body.contentType ?? 'image'}, ${body.originalSize ?? '?'} bytes';

  /// Renders [value] as a single-quoted Dart string literal, escaping
  /// backslashes, quotes, `$` (to prevent interpolation), and control
  /// characters.
  static String _string(String value) {
    final StringBuffer out = StringBuffer("'");
    for (final int unit in value.runes) {
      switch (unit) {
        case 0x5C: // backslash
          out.write(r'\\');
        case 0x27: // single quote
          out.write(r"\'");
        case 0x24: // dollar
          out.write(r'\$');
        case 0x0A:
          out.write(r'\n');
        case 0x0D:
          out.write(r'\r');
        case 0x09:
          out.write(r'\t');
        default:
          out.writeCharCode(unit);
      }
    }
    out.write("'");
    return out.toString();
  }
}
