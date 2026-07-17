/// Options for [JalaSessionCodec.encode] — reduce what leaves the device
/// when sharing a session (see docs/SECURITY.md).
class JalaSessionExportOptions {
  /// Creates export options. Defaults keep full fidelity (same as pre-0.5.3
  /// encode behavior) so existing callers stay unchanged.
  const JalaSessionExportOptions({
    this.includeRequestBodies = true,
    this.includeResponseBodies = true,
    this.includePayloads = true,
    this.includeImages = true,
    this.includeWsFramePreviews = true,
  });

  /// Full session (default).
  static const JalaSessionExportOptions full = JalaSessionExportOptions();

  /// Headers, status, sizes, and URLs only — no request/response bodies,
  /// subscription payloads, image bytes, or WS text previews.
  static const JalaSessionExportOptions headersOnly = JalaSessionExportOptions(
    includeRequestBodies: false,
    includeResponseBodies: false,
    includePayloads: false,
    includeImages: false,
    includeWsFramePreviews: false,
  );

  /// Like [full] but strips request/response bodies and payloads (metadata
  /// and headers remain).
  static const JalaSessionExportOptions noBodies = JalaSessionExportOptions(
    includeRequestBodies: false,
    includeResponseBodies: false,
    includePayloads: false,
    includeImages: false,
  );

  /// Like [full] but replaces image bodies with empty captures (keeps text
  /// bodies).
  static const JalaSessionExportOptions stripImages = JalaSessionExportOptions(
    includeImages: false,
  );

  /// Include captured request bodies.
  final bool includeRequestBodies;

  /// Include captured response bodies.
  final bool includeResponseBodies;

  /// Include GraphQL subscription [NetworkCallEntry.payloads].
  final bool includePayloads;

  /// Keep [BodyKind.image] bytes when bodies are included; when false,
  /// image captures become empty.
  final bool includeImages;

  /// Include WebSocket frame text [WsFrame.preview] values.
  final bool includeWsFramePreviews;
}
