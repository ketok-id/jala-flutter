import 'dart:convert';

import 'jala_import_exception.dart';

/// A single HTTP request parsed from an external source (currently a `curl`
/// command), ready to feed the request composer / replay path.
class ImportedRequest {
  /// Creates an imported request.
  const ImportedRequest({
    required this.method,
    required this.uri,
    required this.headers,
    this.body,
  });

  /// HTTP method, uppercased.
  final String method;

  /// Request URI.
  final Uri uri;

  /// Parsed request headers (last value wins for a repeated name).
  final Map<String, String> headers;

  /// Request body text, or null when the command carried no data.
  final String? body;
}

/// Parses a `curl` command into an [ImportedRequest].
///
/// The inverse of `CurlExporter` for the subset of flags Jala emits, plus
/// the common flags people paste from browser devtools and API docs. Parsing
/// is lenient: unknown flags are skipped, and a body with no explicit method
/// defaults to `POST`. Only [JalaImportFormatException] is thrown, for empty
/// input or a missing/invalid URL.
class JalaCurlCodec {
  const JalaCurlCodec._();

  /// Flags accepted for compatibility but with no effect on the captured
  /// request shape (they change transport/output, not the request itself).
  static const Set<String> _ignoredNoArgFlags = <String>{
    '--compressed',
    '-L', '--location',
    '-s', '--silent',
    '-i', '--include',
    '-k', '--insecure',
    '-v', '--verbose',
    '-#', '--progress-bar',
    '-g', '--globoff',
  };

  /// Parses [command] into an [ImportedRequest].
  static ImportedRequest decode(String command) {
    final List<String> tokens = _tokenize(command);
    if (tokens.isEmpty) {
      throw const JalaImportFormatException('Empty curl command');
    }

    var i = tokens.first.toLowerCase() == 'curl' ? 1 : 0;
    String? method;
    String? url;
    final Map<String, String> headers = <String, String>{};
    final List<String> data = <String>[];

    String? next() => i + 1 < tokens.length ? tokens[++i] : null;

    for (; i < tokens.length; i++) {
      final String tok = tokens[i];
      switch (tok) {
        case '-X':
        case '--request':
          method = next()?.toUpperCase();
        case '-H':
        case '--header':
          final String? h = next();
          if (h != null) _addHeader(headers, h);
        case '-d':
        case '--data':
        case '--data-raw':
        case '--data-ascii':
        case '--data-binary':
        case '--data-urlencode':
          final String? d = next();
          if (d != null) data.add(d);
        case '-u':
        case '--user':
          final String? cred = next();
          if (cred != null) {
            headers['Authorization'] =
                'Basic ${base64.encode(utf8.encode(cred))}';
          }
        case '-b':
        case '--cookie':
          final String? c = next();
          if (c != null) headers['Cookie'] = c;
        case '-A':
        case '--user-agent':
          final String? ua = next();
          if (ua != null) headers['User-Agent'] = ua;
        case '-e':
        case '--referer':
          final String? r = next();
          if (r != null) headers['Referer'] = r;
        case '--url':
          url = next() ?? url;
        default:
          if (_ignoredNoArgFlags.contains(tok)) break;
          if (tok.startsWith('-')) break; // unknown flag: skip, don't guess
          // Prefer a scheme-bearing token as the URL, so a stray bare
          // argument (e.g. an unknown flag's value) can't win over a real
          // URL that appears later.
          if (url == null || (!url.contains('://') && tok.contains('://'))) {
            url = tok;
          }
      }
    }

    if (url == null || url.isEmpty) {
      throw const JalaImportFormatException('No URL found in curl command');
    }
    final Uri uri;
    try {
      uri = Uri.parse(url);
    } on FormatException {
      throw JalaImportFormatException('Invalid URL: $url');
    }
    final String? body = data.isEmpty ? null : data.join('&');
    return ImportedRequest(
      method: method ?? (body != null ? 'POST' : 'GET'),
      uri: uri,
      headers: headers,
      body: body,
    );
  }

  static void _addHeader(Map<String, String> headers, String raw) {
    final int idx = raw.indexOf(':');
    if (idx <= 0) return;
    final String name = raw.substring(0, idx).trim();
    final String value = raw.substring(idx + 1).trim();
    if (name.isNotEmpty) headers[name] = value;
  }

  /// Splits a shell command into tokens, honoring single quotes (literal),
  /// double quotes (with `\`-escapes), backslash escapes, and `\`-newline
  /// line continuations. Adjacent quoted/unquoted runs with no whitespace
  /// between them join into one token — so the exporter's `'\''` idiom for
  /// an embedded single quote round-trips.
  static List<String> _tokenize(String input) {
    final List<String> tokens = <String>[];
    final StringBuffer buf = StringBuffer();
    var inToken = false;
    var i = 0;
    final int n = input.length;

    void flush() {
      if (inToken) {
        tokens.add(buf.toString());
        buf.clear();
        inToken = false;
      }
    }

    while (i < n) {
      final String c = input[i];
      if (c == r'\') {
        if (i + 1 < n && (input[i + 1] == '\n' || input[i + 1] == '\r')) {
          i += 2; // line continuation → token separator
          flush();
          continue;
        }
        if (i + 1 < n) {
          buf.write(input[i + 1]);
          inToken = true;
          i += 2;
          continue;
        }
        i++;
        continue;
      }
      if (c == "'") {
        inToken = true;
        i++;
        while (i < n && input[i] != "'") {
          buf.write(input[i]);
          i++;
        }
        i++; // skip closing quote
        continue;
      }
      if (c == '"') {
        inToken = true;
        i++;
        while (i < n && input[i] != '"') {
          if (input[i] == r'\' && i + 1 < n) {
            buf.write(input[i + 1]);
            i += 2;
            continue;
          }
          buf.write(input[i]);
          i++;
        }
        i++; // skip closing quote
        continue;
      }
      if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
        flush();
        i++;
        continue;
      }
      buf.write(c);
      inToken = true;
      i++;
    }
    flush();
    return tokens;
  }
}
