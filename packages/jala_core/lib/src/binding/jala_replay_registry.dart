import '../model/captured_body.dart';
import '../model/network_call_entry.dart';

/// Thrown when a captured call cannot be faithfully re-issued.
///
/// Replay puts real bytes on a real server. Where Jala cannot reproduce the
/// original request exactly, it refuses rather than sending something
/// subtly wrong — see [JalaReplayability.replayBlockedReason].
class JalaReplayException implements Exception {
  /// Creates the exception with a user-facing [message].
  const JalaReplayException(this.message);

  /// Why the call could not be replayed, phrased for display.
  final String message;

  @override
  String toString() => 'JalaReplayException: $message';
}

/// Whether a captured call can be re-issued as-is.
extension JalaReplayability on NetworkCallEntry {
  /// Why replaying this entry unmodified would be unfaithful, or null when
  /// it can be replayed as captured.
  ///
  /// Currently one case: a request body that hit the capture cap. Jala
  /// deliberately never retained the rest of it (see
  /// `CapturedBody.defaultMaxBytes`), so resending the prefix it does have
  /// would silently deliver a corrupt payload — a truncated JSON document
  /// or a half-uploaded file — to a live endpoint. Edit-and-resend still
  /// works: an explicit body override is the developer supplying the real
  /// content, so it is sent as given.
  String? get replayBlockedReason {
    if (requestBody.kind == BodyKind.truncated || requestBody.truncated) {
      return 'The request body was truncated at capture time, so replaying '
          'it would send an incomplete body. Use Edit & resend to supply '
          'the full body.';
    }
    return null;
  }
}

/// Something that can re-issue a previously captured network call.
///
/// Client integrations implement this — e.g. `jala_dio` registers a
/// replayer that rebuilds `RequestOptions` from a [NetworkCallEntry] and
/// runs `dio.fetch(...)`, so the replayed call flows through interceptors
/// again and is captured as a fresh entry with `replayOf` set.
abstract class JalaReplayer {
  /// Re-issues the network call described by [entry].
  Future<void> replay(NetworkCallEntry entry);

  /// Re-issues [entry] with optional field overrides (edit-and-resend).
  ///
  /// Default implementation ignores overrides and calls [replay]. Adapters
  /// that support editing override this.
  Future<void> replayModified(
    NetworkCallEntry entry, {
    String? method,
    Uri? uri,
    Map<String, String>? headers,
    String? body,
  }) =>
      replay(entry);
}

/// Registry connecting the inspector UI ("Replay" button) to whichever
/// client integration is able to re-issue calls.
///
/// v0.1 keeps this deliberately simple: a single active replayer. The last
/// registered replayer wins (matching "the most recently attached client
/// handles replays"), and unregistering a replayer that is not the active
/// one is a no-op.
class JalaReplayRegistry {
  /// Creates an empty registry. Usually accessed via
  /// `JalaBinding.instance.replayRegistry`.
  JalaReplayRegistry();

  JalaReplayer? _replayer;

  /// Whether a replayer is currently registered. UIs use this to
  /// enable/disable the Replay action.
  bool get hasReplayer => _replayer != null;

  /// Registers [replayer] as the active replayer, replacing any previous
  /// one.
  void register(JalaReplayer replayer) {
    _replayer = replayer;
  }

  /// Unregisters [replayer] if it is the active one; otherwise does
  /// nothing.
  void unregister(JalaReplayer replayer) {
    if (identical(_replayer, replayer)) {
      _replayer = null;
    }
  }

  /// Replays [entry] via the active replayer.
  ///
  /// Returns `true` once the replay has been issued, or `false` when no
  /// replayer is registered (spec allows returning false or throwing
  /// StateError for that case; returning false is chosen so callers can
  /// branch without try/catch).
  ///
  /// Throws [JalaReplayException] when [entry] cannot be replayed
  /// faithfully — see [JalaReplayability.replayBlockedReason]. That is a
  /// distinct outcome from "no replayer attached", which is why it is not
  /// folded into the `false` return.
  Future<bool> replay(NetworkCallEntry entry) async {
    final JalaReplayer? replayer = _replayer;
    if (replayer == null) return false;
    final String? blocked = entry.replayBlockedReason;
    if (blocked != null) throw JalaReplayException(blocked);
    await replayer.replay(entry);
    return true;
  }

  /// Edit-and-resend via the active replayer. Returns false when none is
  /// registered.
  Future<bool> replayModified(
    NetworkCallEntry entry, {
    String? method,
    Uri? uri,
    Map<String, String>? headers,
    String? body,
  }) async {
    final JalaReplayer? replayer = _replayer;
    if (replayer == null) return false;
    await replayer.replayModified(
      entry,
      method: method,
      uri: uri,
      headers: headers,
      body: body,
    );
    return true;
  }
}
