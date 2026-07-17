/// An immutable network-condition profile applied by `JalaThrottleRegistry`
/// to simulate a slower/flakier connection.
///
/// Values describe the shape of the simulated connection; a binding (e.g.
/// `jala_dio`, `jala_http` — see docs/plans/track-e-v0.5.md E2) is
/// responsible for actually applying [latencyFor]/[shouldDrop]/[paceFor]
/// from `JalaThrottleRegistry` around a real request. `jala_core` itself
/// never touches the network.
class JalaThrottleProfile {
  /// Creates a throttle profile. [dropRate] must be within `0..1`
  /// inclusive (`0` = never drop, `1` = always drop).
  const JalaThrottleProfile({
    required this.id,
    required this.name,
    required this.latencyMs,
    this.jitterMs,
    this.downloadBytesPerSec,
    this.uploadBytesPerSec,
    this.dropRate = 0,
  }) : assert(
         dropRate >= 0 && dropRate <= 1,
         'dropRate must be within 0..1',
       ),
       assert(latencyMs >= 0, 'latencyMs must not be negative');

  /// Stable identifier (e.g. `'slow3g'`), also used as `throttledBy` on
  /// `NetworkCallEntry`/`NetworkRequestEvent` when a call was throttled
  /// under this profile.
  final String id;

  /// Human-readable label for the UI (e.g. `'Slow 3G'`).
  final String name;

  /// Base one-way latency applied before a throttled call proceeds.
  final int latencyMs;

  /// Random jitter applied on top of [latencyMs] (± this many
  /// milliseconds), or null for no jitter.
  final int? jitterMs;

  /// Simulated download bandwidth cap in bytes/sec, or null for unlimited.
  final int? downloadBytesPerSec;

  /// Simulated upload bandwidth cap in bytes/sec, or null for unlimited.
  final int? uploadBytesPerSec;

  /// Probability (`0..1`) that a throttled call is dropped outright
  /// (simulated connection failure) rather than allowed through.
  final double dropRate;

  /// `400ms ±100` latency, `50 KB/s` down / `25 KB/s` up, no drops —
  /// approximates a slow 3G connection.
  static const JalaThrottleProfile slow3g = JalaThrottleProfile(
    id: 'slow3g',
    name: 'Slow 3G',
    latencyMs: 400,
    jitterMs: 100,
    downloadBytesPerSec: 50 * 1024,
    uploadBytesPerSec: 25 * 1024,
  );

  /// `150ms ±50` latency, `180 KB/s` down, no upload cap or drops —
  /// approximates a fast 3G connection.
  static const JalaThrottleProfile fast3g = JalaThrottleProfile(
    id: 'fast3g',
    name: 'Fast 3G',
    latencyMs: 150,
    jitterMs: 50,
    downloadBytesPerSec: 180 * 1024,
  );

  /// `200ms ±200` latency, no bandwidth cap, `15%` drop rate — an unstable
  /// connection that intermittently fails outright.
  static const JalaThrottleProfile flaky = JalaThrottleProfile(
    id: 'flaky',
    name: 'Flaky',
    latencyMs: 200,
    jitterMs: 200,
    dropRate: 0.15,
  );

  /// Every call is dropped — simulates no connectivity at all.
  static const JalaThrottleProfile offline = JalaThrottleProfile(
    id: 'offline',
    name: 'Offline',
    latencyMs: 0,
    dropRate: 1,
  );

  /// The built-in presets, in the order they should be offered in the UI.
  static const List<JalaThrottleProfile> presets = <JalaThrottleProfile>[
    slow3g,
    fast3g,
    flaky,
    offline,
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JalaThrottleProfile &&
          other.id == id &&
          other.name == name &&
          other.latencyMs == latencyMs &&
          other.jitterMs == jitterMs &&
          other.downloadBytesPerSec == downloadBytesPerSec &&
          other.uploadBytesPerSec == uploadBytesPerSec &&
          other.dropRate == dropRate);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    latencyMs,
    jitterMs,
    downloadBytesPerSec,
    uploadBytesPerSec,
    dropRate,
  );

  @override
  String toString() =>
      'JalaThrottleProfile(id: $id, name: $name, latencyMs: $latencyMs, '
      'jitterMs: $jitterMs, dropRate: $dropRate)';
}
