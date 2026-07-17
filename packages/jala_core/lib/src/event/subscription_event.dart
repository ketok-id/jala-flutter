part of 'jala_event.dart';

/// Emitted for each payload delivered on an open GraphQL subscription (see
/// docs/plans/track-e-v0.5.md E1/E2 — `jala_graphql` emits one of these per
/// payload rather than folding counts into the response body).
///
/// `JalaStore` appends [body] to the matching `NetworkCallEntry.payloads`
/// (a ring buffer capped by `JalaConfig.maxSubscriptionPayloads`, mirroring
/// the WS frame ring buffer) only while that entry is still
/// `JalaCallStatus.pending` — a subscription call never resolves to
/// success/error/cancelled from an adapter's point of view while payloads
/// keep arriving, so "pending" is the only state a live subscription is
/// ever in.
class NetworkSubscriptionPayloadEvent extends JalaEvent {
  /// Creates a subscription payload event for [callId] (the subscription's
  /// `NetworkCallEntry.id`).
  const NetworkSubscriptionPayloadEvent({
    required super.callId,
    required super.timestamp,
    required this.seq,
    required this.body,
  });

  /// Zero-based sequence number of this payload within the subscription,
  /// assigned by the emitting binding. Not separately retained on
  /// `NetworkCallEntry` — payload order is preserved by `payloads` list
  /// order instead.
  final int seq;

  /// The captured payload body.
  final CapturedBody body;
}
