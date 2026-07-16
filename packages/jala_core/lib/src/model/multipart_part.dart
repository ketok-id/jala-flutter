import 'dart:convert';

import 'captured_body.dart';

/// JSON key marking a request body as a structured multipart summary — see
/// [CapturedBodyMultipart] and B3 in docs/plans/track-b-v0.2.md.
const String multipartBodyKey = '@multipart';

/// One part of a captured `multipart/form-data` request body.
///
/// Only structural metadata is ever kept here — never the field's value or
/// the file's bytes — so a multipart summary is safe to retain even when
/// the underlying form carries sensitive data or large file uploads.
class JalaMultipartPart {
  /// Creates a part summary.
  const JalaMultipartPart({
    required this.name,
    required this.size,
    this.filename,
    this.contentType,
  });

  /// The form field name.
  final String name;

  /// The uploaded file's name, present only for file parts (as opposed to
  /// plain form fields).
  final String? filename;

  /// The part's declared content type, if known.
  final String? contentType;

  /// The part's size in bytes: the field value's encoded length, or the
  /// file's byte length.
  final int size;

  /// Rebuilds a part from the map shape produced by [toJson]; returns null
  /// if [json] doesn't match (missing/mistyped `name` or `size`).
  static JalaMultipartPart? fromJson(Object? json) {
    if (json is! Map) return null;
    final Object? name = json['name'];
    final Object? size = json['size'];
    if (name is! String || size is! int) return null;
    return JalaMultipartPart(
      name: name,
      size: size,
      filename: json['filename'] as String?,
      contentType: json['contentType'] as String?,
    );
  }

  /// Renders this part as a JSON-encodable map.
  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    if (filename != null) 'filename': filename,
    if (contentType != null) 'contentType': contentType,
    'size': size,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JalaMultipartPart &&
          other.name == name &&
          other.filename == filename &&
          other.contentType == contentType &&
          other.size == size);

  @override
  int get hashCode => Object.hash(name, filename, contentType, size);

  @override
  String toString() =>
      'JalaMultipartPart(name: $name, filename: $filename, '
      'contentType: $contentType, size: $size)';
}

/// Captures/reads the `{"@multipart": [...]}` structured-summary convention
/// used for multipart request bodies (B3 in docs/plans/track-b-v0.2.md).
///
/// Both `jala_dio` (`FormData`) and `jala_http` (`http.MultipartRequest`)
/// build a [CapturedBody] via [capture]; `jala_ui`'s body view reads it back
/// via [partsOf] to render a parts table instead of the raw JSON tree, and
/// `CurlExporter` reads it to emit `-F` flags instead of `-d`.
class CapturedBodyMultipart {
  const CapturedBodyMultipart._();

  /// Captures [parts] as a [BodyKind.json] body under the `@multipart` key.
  static CapturedBody capture(
    List<JalaMultipartPart> parts, {
    int maxBytes = CapturedBody.defaultMaxBytes,
  }) {
    final Map<String, Object?> summary = <String, Object?>{
      multipartBodyKey: <Map<String, Object?>>[
        for (final JalaMultipartPart part in parts) part.toJson(),
      ],
    };
    return CapturedBody.capture(
      summary,
      contentType: 'application/json',
      maxBytes: maxBytes,
    );
  }

  /// Extracts the parts list from [body] if it holds a multipart summary
  /// produced by [capture] — a [BodyKind.json] body whose decoded JSON is a
  /// map containing the `@multipart` key. Returns null for any other body,
  /// including one that was cut short by the capture cap (`BodyKind
  /// .truncated`, where the JSON is necessarily incomplete).
  static List<JalaMultipartPart>? partsOf(CapturedBody body) {
    if (body.kind != BodyKind.json) return null;
    final String? text = body.text;
    if (text == null) return null;
    try {
      final Object? decoded = jsonDecode(text);
      if (decoded is! Map || !decoded.containsKey(multipartBodyKey)) {
        return null;
      }
      final Object? list = decoded[multipartBodyKey];
      if (list is! List) return null;
      final List<JalaMultipartPart> parts = <JalaMultipartPart>[];
      for (final Object? item in list) {
        final JalaMultipartPart? part = JalaMultipartPart.fromJson(item);
        if (part != null) parts.add(part);
      }
      return parts;
    } on FormatException {
      return null;
    }
  }
}
