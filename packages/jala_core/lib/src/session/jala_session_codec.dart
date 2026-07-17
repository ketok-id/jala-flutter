import 'dart:convert';

import '../model/network_call_entry.dart';
import '../model/ws_connection_entry.dart';
import '../store/jala_store.dart';
import 'jala_session.dart';

/// Encodes/decodes a [JalaStore] snapshot to/from a versioned JSON envelope,
/// so a captured session can be shared between developers (see
/// docs/plans/track-e-v0.5.md E1 "session share").
///
/// The envelope carries a `"format": "jala-session"` marker and an integer
/// `version` so [decode] can reject anything that isn't a Jala session up
/// front, rather than failing deep inside field parsing. Every field of
/// [NetworkCallEntry] round-trips except `progress`, which is transient
/// live-capture state and is never serialized.
class JalaSessionCodec {
  const JalaSessionCodec._();

  /// The envelope's format marker (`envelope['format']`).
  static const String formatMarker = 'jala-session';

  /// The current envelope version this build writes (via [encode]) and
  /// fully understands (via [decode]).
  static const int currentVersion = 1;

  /// Encodes every entry and WebSocket connection currently in [store] into
  /// a versioned JSON string.
  static String encode(JalaStore store) {
    final Map<String, Object?> envelope = <String, Object?>{
      'format': formatMarker,
      'version': currentVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'entries': store.entries
          .map((NetworkCallEntry e) => e.toJson())
          .toList(),
      'wsConnections': store.wsConnections
          .map((WsConnectionEntry w) => w.toJson())
          .toList(),
    };
    return jsonEncode(envelope);
  }

  /// Decodes a session previously produced by [encode] (or a compatible
  /// older version).
  ///
  /// Never throws anything other than [JalaSessionFormatException]:
  /// malformed JSON, a missing/wrong `format` marker, an unsupported
  /// `version`, or any other parsing failure is caught here and wrapped.
  static JalaSession decode(String data) {
    final Object? decoded = _decodeJson(data);
    if (decoded is! Map) {
      throw const JalaSessionFormatException(
        'Session data is not a JSON object',
      );
    }
    final Map<String, Object?> envelope = Map<String, Object?>.from(decoded);

    final Object? format = envelope['format'];
    if (format != formatMarker) {
      throw JalaSessionFormatException(
        'Not a Jala session (expected format "$formatMarker", '
        'found: $format)',
      );
    }

    final int version = _parseVersion(envelope['version']);
    if (version > currentVersion) {
      throw JalaSessionFormatException(
        'Unsupported session version $version; this build understands up '
        'to version $currentVersion',
      );
    }

    try {
      final String? exportedAtRaw = envelope['exportedAt'] as String?;
      if (exportedAtRaw == null) {
        throw const FormatException('missing exportedAt');
      }
      final List<NetworkCallEntry> entries = _asList(envelope['entries'])
          .map((Object? e) => NetworkCallEntry.fromJson(_asMap(e)))
          .toList();
      final List<WsConnectionEntry> wsConnections = _asList(
        envelope['wsConnections'],
      ).map((Object? w) => WsConnectionEntry.fromJson(_asMap(w))).toList();

      return JalaSession(
        version: version,
        exportedAt: DateTime.parse(exportedAtRaw),
        entries: entries,
        wsConnections: wsConnections,
      );
    } on JalaSessionFormatException {
      rethrow;
    } on Object catch (e) {
      throw JalaSessionFormatException('Malformed session data: $e');
    }
  }

  static Object? _decodeJson(String data) {
    try {
      return jsonDecode(data);
    } on FormatException catch (e) {
      throw JalaSessionFormatException('Malformed JSON: ${e.message}');
    }
  }

  static int _parseVersion(Object? raw) {
    if (raw is int) return raw;
    final int? parsed = int.tryParse('$raw');
    if (parsed == null) {
      throw JalaSessionFormatException('Missing or invalid version: $raw');
    }
    return parsed;
  }

  static List<Object?> _asList(Object? raw) =>
      raw is List ? raw : const <Object?>[];

  static Map<String, Object?> _asMap(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('Expected a JSON object in list');
    }
    return Map<String, Object?>.from(raw);
  }
}
