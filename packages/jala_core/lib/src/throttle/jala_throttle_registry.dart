import 'dart:async';
import 'dart:math';

import '../util/glob.dart';
import 'jala_throttle_profile.dart';

/// Process-wide (per `JalaBinding`) active throttle configuration.
///
/// A single [JalaThrottleProfile] can be active at a time, optionally
/// scoped to hosts matching [hostPattern]. Client integrations (e.g.
/// `jala_dio`, `jala_http` — see docs/plans/track-e-v0.5.md E2) consult
/// [shouldDrop]/[latencyFor]/[paceFor]/[hostMatches] around real requests;
/// `jala_core` itself never touches the network.
///
/// Every read (`activeProfile`, `hostPattern`, `watch`, and every helper)
/// reports the "off" value — null / false / zero — whenever [isEnabled]
/// (usually wired to `JalaBinding.isEnabled`) is false, regardless of what
/// [setActive] last configured. This mirrors `JalaMockRegistry`/`JalaStore`:
/// the registry always holds its configuration, but a disabled binding
/// makes every read path a true no-op.
class JalaThrottleRegistry {
  /// Creates a registry. [isEnabled] defaults to always-true for standalone
  /// use (tests, or callers not wiring it to a binding); `JalaBinding` wires
  /// it to its own `isEnabled`. [random] supports deterministic testing —
  /// inject a seeded `Random` (e.g. `Random(42)`) for reproducible
  /// [shouldDrop]/[latencyFor] results.
  JalaThrottleRegistry({bool Function()? isEnabled, Random? random})
    : _isEnabled = isEnabled ?? (() => true),
      _random = random ?? Random();

  final bool Function() _isEnabled;
  final Random _random;

  JalaThrottleProfile? _activeProfile;
  String? _hostPattern;

  final StreamController<JalaThrottleProfile?> _controller =
      StreamController<JalaThrottleProfile?>.broadcast();

  /// The currently active profile, or null when off — either because no
  /// profile was ever activated, [clear] was called, or the binding is
  /// disabled.
  JalaThrottleProfile? get activeProfile =>
      _isEnabled() ? _activeProfile : null;

  /// The host glob pattern the active profile is scoped to, or null when
  /// it applies to all hosts (or when off — see [activeProfile]).
  String? get hostPattern => _isEnabled() ? _hostPattern : null;

  /// Emits the current [activeProfile] to every new listener, then again on
  /// every [setActive]/[clear] call. Broadcast: any number of listeners may
  /// subscribe, each getting an immediate replay of the current value.
  late final Stream<JalaThrottleProfile?> watch =
      Stream<JalaThrottleProfile?>.multi((controller) {
        controller.add(activeProfile);
        final StreamSubscription<JalaThrottleProfile?> sub = _controller
            .stream
            .listen(
              controller.add,
              onError: controller.addError,
              onDone: controller.close,
            );
        controller.onCancel = sub.cancel;
      });

  /// Activates [profile], optionally scoped to hosts matching
  /// [hostPattern] (a glob per `globMatchesIgnoreCase`; null applies to all
  /// hosts). Replaces any previously active profile/pattern.
  void setActive(JalaThrottleProfile profile, {String? hostPattern}) {
    _activeProfile = profile;
    _hostPattern = hostPattern;
    _emit();
  }

  /// Deactivates throttling — [activeProfile] becomes null and
  /// [hostPattern] is cleared.
  void clear() {
    _activeProfile = null;
    _hostPattern = null;
    _emit();
  }

  /// Whether a call should be dropped outright (simulated connection
  /// failure), per the active profile's `dropRate`. Always false when off.
  /// `dropRate <= 0` and `dropRate >= 1` are handled without consulting
  /// [random] at all, so those edges are deterministic regardless of the
  /// injected `Random`.
  bool shouldDrop() {
    final JalaThrottleProfile? profile = activeProfile;
    if (profile == null) return false;
    if (profile.dropRate <= 0) return false;
    if (profile.dropRate >= 1) return true;
    return _random.nextDouble() < profile.dropRate;
  }

  /// The artificial latency to wait before a throttled call proceeds:
  /// `latencyMs` plus a random jitter within `±jitterMs`, clamped so the
  /// result is never negative. Zero when off.
  Duration latencyFor() {
    final JalaThrottleProfile? profile = activeProfile;
    if (profile == null) return Duration.zero;
    final int? jitterMs = profile.jitterMs;
    if (jitterMs == null || jitterMs <= 0) {
      return Duration(milliseconds: profile.latencyMs);
    }
    // Uniform integer offset in [-jitterMs, +jitterMs].
    final int offset = _random.nextInt(jitterMs * 2 + 1) - jitterMs;
    final int rawMs = profile.latencyMs + offset;
    return Duration(milliseconds: rawMs < 0 ? 0 : rawMs);
  }

  /// The artificial delay to spread [bytes] worth of transfer over, given a
  /// bandwidth cap of [perSec] bytes/sec. Zero when off, when [perSec] is
  /// null/non-positive, or when [bytes] is non-positive.
  ///
  /// [perSec] is a parameter (rather than read from [activeProfile])
  /// because callers pass whichever direction applies —
  /// `activeProfile?.downloadBytesPerSec` or `…uploadBytesPerSec`.
  Duration paceFor(int bytes, int? perSec) {
    if (!_isEnabled()) return Duration.zero;
    if (perSec == null || perSec <= 0 || bytes <= 0) return Duration.zero;
    final int micros = (bytes * Duration.microsecondsPerSecond) ~/ perSec;
    return Duration(microseconds: micros);
  }

  /// Whether [host] is in scope for the active profile: always true when
  /// [hostPattern] is null (applies to all hosts, or when off — see
  /// [activeProfile]), otherwise a case-insensitive glob match.
  bool hostMatches(String host) {
    final String? pattern = hostPattern;
    if (pattern == null) return true;
    return globMatchesIgnoreCase(pattern, host);
  }

  /// Releases the [watch] broadcast controller. Idempotent.
  Future<void> dispose() async {
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(activeProfile);
    }
  }
}
