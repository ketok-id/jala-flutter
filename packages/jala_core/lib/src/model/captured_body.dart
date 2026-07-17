import 'dart:convert';
import 'dart:typed_data';

/// The shape of data held by a [CapturedBody].
enum BodyKind {
  /// No body was present (e.g. a GET request, or a 204 response).
  none,

  /// Plain decoded text that fit entirely within the capture cap.
  text,

  /// Decoded text that is valid JSON and fit entirely within the cap.
  json,

  /// Binary data that was not decoded as text; only size metadata is kept.
  bytes,

  /// Text/JSON that exceeded the capture cap — [CapturedBody.text] holds a
  /// truncated prefix and [CapturedBody.originalSize] holds the full size.
  truncated,

  /// A streaming body (e.g. `ResponseType.stream`); only metadata is kept,
  /// the stream itself is never consumed by Jala.
  stream,

  /// An `image/*` body that fit entirely within the capture cap —
  /// [CapturedBody.bytes] holds the raw image data for inline preview.
  image,
}

/// An immutable, size-capped capture of a request or response body.
///
/// Jala never keeps more than [defaultMaxBytes] (or a caller-supplied cap)
/// of body content in memory, and never throws when handed malformed or
/// binary data — worst case it degrades to metadata-only capture. This is
/// what keeps Jala safe to leave enabled against large-body production
/// traffic (see SPEC v0.1 positioning gap #7).
class CapturedBody {
  const CapturedBody._({
    required this.kind,
    required this.text,
    required this.originalSize,
    required this.truncated,
    required this.contentType,
    this.bytes,
  });

  /// Wraps [bytes] as a [BodyKind.image] capture.
  ///
  /// This is a non-const factory (unlike the other capture paths) because
  /// `Uint8List` values are never compile-time constants. Callers normally
  /// reach this via [captureBytes], which applies the cap/content-type
  /// eligibility checks; use this constructor directly only when those
  /// checks have already been done.
  factory CapturedBody.image(
    Uint8List bytes, {
    required int originalSize,
    required bool truncated,
    String? contentType,
  }) {
    return CapturedBody._(
      kind: BodyKind.image,
      text: null,
      originalSize: originalSize,
      truncated: truncated,
      contentType: contentType,
      bytes: bytes,
    );
  }

  /// Captures [data] into a [CapturedBody], honoring [maxBytes].
  ///
  /// - `String` -> [BodyKind.text], or [BodyKind.json] when [contentType]
  ///   contains `json` or the string itself parses as JSON.
  /// - `List<int>` (raw bytes) -> decoded as UTF-8 (malformed sequences are
  ///   tolerated) when [contentType] looks textual; otherwise [BodyKind.bytes]
  ///   with only [originalSize] recorded — the raw bytes are never retained
  ///   once they exceed [maxBytes].
  /// - `Map`/`List` (already-decoded JSON) -> `jsonEncode`d into
  ///   [BodyKind.json].
  /// - `null` -> [BodyKind.none].
  /// - `Stream` -> [BodyKind.stream], metadata only; the stream is never
  ///   consumed.
  factory CapturedBody.capture(
    dynamic data, {
    String? contentType,
    int maxBytes = defaultMaxBytes,
  }) {
    if (data == null) {
      return CapturedBody._(
        kind: BodyKind.none,
        text: null,
        originalSize: null,
        truncated: false,
        contentType: contentType,
      );
    }

    if (data is Stream) {
      return CapturedBody._(
        kind: BodyKind.stream,
        text: null,
        originalSize: null,
        truncated: false,
        contentType: contentType,
      );
    }

    if (data is String) {
      return _captureText(data, contentType: contentType, maxBytes: maxBytes);
    }

    // Must be checked before the generic `List` branch below: a byte buffer
    // (List<int>) is also a List<dynamic> at runtime.
    if (data is List<int>) {
      if (_isTexty(contentType)) {
        final String decoded = utf8.decode(data, allowMalformed: true);
        return _captureText(
          decoded,
          contentType: contentType,
          maxBytes: maxBytes,
          originalByteLength: data.length,
        );
      }
      return CapturedBody._(
        kind: BodyKind.bytes,
        text: null,
        originalSize: data.length,
        truncated: false,
        contentType: contentType,
      );
    }

    if (data is Map || data is List) {
      final String encoded = jsonEncode(data);
      return _captureText(
        encoded,
        contentType: contentType ?? 'application/json',
        maxBytes: maxBytes,
        forceJson: true,
      );
    }

    // Fallback for anything else (e.g. a custom object): best-effort
    // toString(), never throw.
    // SPEC-NOTE: the spec enumerates String/bytes/Map/List/null/Stream only;
    // this branch is a defensive catch-all so `capture` never throws for an
    // unanticipated runtime type.
    return _captureText(
      data.toString(),
      contentType: contentType,
      maxBytes: maxBytes,
    );
  }

  /// Deserializes a body previously produced by [toJson] (used by
  /// `JalaSessionCodec` — see docs/plans/track-e-v0.5.md E1). Reconstructs
  /// the capture exactly, including combinations (e.g. [BodyKind.truncated])
  /// that [capture] itself would derive rather than accept directly.
  ///
  /// Throws [FormatException] on an unrecognized `kind` or malformed
  /// `bytes` — never silently returns a wrong-shaped body.
  factory CapturedBody.fromJson(Map<String, Object?> json) {
    final String? kindName = json['kind'] as String?;
    BodyKind? kind;
    for (final BodyKind candidate in BodyKind.values) {
      if (candidate.name == kindName) {
        kind = candidate;
        break;
      }
    }
    if (kind == null) {
      throw FormatException('Unknown CapturedBody kind: $kindName');
    }
    final String? bytesB64 = json['bytes'] as String?;
    Uint8List? bytes;
    if (bytesB64 != null) {
      try {
        bytes = base64Decode(bytesB64);
      } on FormatException {
        throw const FormatException('CapturedBody.bytes is not valid base64');
      }
    }
    return CapturedBody._(
      kind: kind,
      text: json['text'] as String?,
      originalSize: json['originalSize'] as int?,
      truncated: json['truncated'] as bool? ?? false,
      contentType: json['contentType'] as String?,
      bytes: bytes,
    );
  }

  /// Central capture decision for raw binary bodies (e.g. a Dio
  /// `ResponseType.bytes` response, or a buffered `http` byte response).
  ///
  /// Returns a [BodyKind.image] capture — retaining the raw bytes for
  /// inline preview — only when all of the following hold:
  /// - [contentType] starts with `image/` (case-insensitive);
  /// - [captureImages] is `true` (wired from
  ///   `JalaConfig.captureImageBodies`);
  /// - `bytes.length <= maxBytes`.
  ///
  /// Otherwise it falls back to the existing metadata-only
  /// [BodyKind.bytes] behavior: [originalSize] is recorded but the payload
  /// itself is never retained.
  static CapturedBody captureBytes(
    List<int> bytes, {
    String? contentType,
    required int maxBytes,
    required bool captureImages,
  }) {
    final bool isImage =
        contentType != null && contentType.toLowerCase().startsWith('image/');
    if (isImage && captureImages && bytes.length <= maxBytes) {
      return CapturedBody.image(
        bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
        originalSize: bytes.length,
        truncated: false,
        contentType: contentType,
      );
    }
    return CapturedBody._(
      kind: BodyKind.bytes,
      text: null,
      originalSize: bytes.length,
      truncated: false,
      contentType: contentType,
    );
  }

  /// A shared, allocation-free instance for absent bodies.
  static const CapturedBody none = CapturedBody._(
    kind: BodyKind.none,
    text: null,
    originalSize: null,
    truncated: false,
    contentType: null,
  );

  /// Default hard cap on captured body size: 512 KB.
  static const int defaultMaxBytes = 512 * 1024;

  /// The shape of the captured content.
  final BodyKind kind;

  /// Decoded text (possibly a truncated prefix). Null unless [kind] is
  /// [BodyKind.text], [BodyKind.json], or [BodyKind.truncated].
  final String? text;

  /// Size in bytes of the *original* body, if known — even when the
  /// content itself was not kept (e.g. [BodyKind.bytes]).
  final int? originalSize;

  /// Whether the content was cut short to respect the capture cap.
  final bool truncated;

  /// The content-type reported alongside the body, if any.
  final String? contentType;

  /// Raw image bytes, present only when [kind] is [BodyKind.image]; null
  /// for every other kind.
  final Uint8List? bytes;

  /// Serializes this body for `JalaSessionCodec` (see
  /// docs/plans/track-e-v0.5.md E1). [bytes] (image captures) are
  /// base64-encoded; [FormatException]-free — every field here is already
  /// a JSON-safe primitive.
  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.name,
    if (text != null) 'text': text,
    if (originalSize != null) 'originalSize': originalSize,
    'truncated': truncated,
    if (contentType != null) 'contentType': contentType,
    if (bytes != null) 'bytes': base64Encode(bytes!),
  };

  static bool _isTexty(String? contentType) {
    if (contentType == null) return false;
    final String ct = contentType.toLowerCase();
    return ct.startsWith('text/') ||
        ct.contains('json') ||
        ct.contains('xml') ||
        ct.contains('javascript') ||
        ct.contains('x-www-form-urlencoded') ||
        ct.contains('graphql');
  }

  static bool _looksLikeJson(String text, String? contentType) {
    if (contentType != null && contentType.toLowerCase().contains('json')) {
      return true;
    }
    final String trimmed = text.trimLeft();
    if (trimmed.isEmpty) return false;
    final String firstChar = trimmed[0];
    if (firstChar != '{' &&
        firstChar != '[' &&
        firstChar != '"' &&
        firstChar != '-' &&
        firstChar != 't' &&
        firstChar != 'f' &&
        firstChar != 'n' &&
        int.tryParse(firstChar) == null) {
      return false;
    }
    try {
      jsonDecode(trimmed);
      return true;
    } on FormatException {
      return false;
    }
  }

  static CapturedBody _captureText(
    String text, {
    required String? contentType,
    required int maxBytes,
    int? originalByteLength,
    bool forceJson = false,
  }) {
    final List<int> encoded = utf8.encode(text);
    final int originalSize = originalByteLength ?? encoded.length;
    final bool isJson = forceJson || _looksLikeJson(text, contentType);

    if (encoded.length <= maxBytes) {
      return CapturedBody._(
        kind: isJson ? BodyKind.json : BodyKind.text,
        text: text,
        originalSize: originalSize,
        truncated: false,
        contentType: contentType,
      );
    }

    final List<int> cut = encoded.sublist(0, maxBytes);
    final String truncatedText = utf8.decode(cut, allowMalformed: true);
    return CapturedBody._(
      kind: BodyKind.truncated,
      text: truncatedText,
      originalSize: originalSize,
      truncated: true,
      contentType: contentType,
    );
  }

  // SPEC-NOTE: `bytes` is intentionally excluded from equality/hashCode —
  // comparing raw image payloads byte-for-byte would make this an O(n)
  // operation on every store/filter comparison. Two `BodyKind.image`
  // captures are considered equal when their kind/size/truncated/
  // contentType agree, same as any other kind.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CapturedBody &&
          other.kind == kind &&
          other.text == text &&
          other.originalSize == originalSize &&
          other.truncated == truncated &&
          other.contentType == contentType);

  @override
  int get hashCode =>
      Object.hash(kind, text, originalSize, truncated, contentType);

  @override
  String toString() =>
      'CapturedBody(kind: $kind, originalSize: $originalSize, '
      'truncated: $truncated, contentType: $contentType)';
}
