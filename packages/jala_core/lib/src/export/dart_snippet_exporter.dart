import '../model/captured_body.dart';
import '../model/network_call_entry.dart';

/// Exports a [NetworkCallEntry] as a runnable Dart snippet using
/// `package:dio`.
class DartSnippetExporter {
  const DartSnippetExporter._();

  /// Renders [entry] as a copy-pasteable `dio.request(...)` snippet.
  static String export(NetworkCallEntry entry) {
    final StringBuffer buffer = StringBuffer()
      ..writeln('final dio = Dio();')
      ..writeln('final response = await dio.request(')
      ..writeln('  ${_string(entry.uri.toString())},')
      ..writeln('  options: Options(');
    buffer.writeln('    method: ${_string(entry.method)},');

    if (entry.requestHeaders.isNotEmpty) {
      buffer.writeln('    headers: {');
      entry.requestHeaders.forEach((name, value) {
        buffer.writeln('      ${_string(name)}: ${_string(value)},');
      });
      buffer.writeln('    },');
    }
    buffer.writeln('  ),');

    final String? body = entry.requestBody.text;
    if (body != null && body.isNotEmpty) {
      if (entry.requestBody.kind == BodyKind.json) {
        buffer.writeln('  data: jsonDecode(${_string(body)}),');
      } else {
        buffer.writeln('  data: ${_string(body)},');
      }
    }
    buffer
      ..writeln(');')
      ..write('print(response.data);');
    return buffer.toString();
  }

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
