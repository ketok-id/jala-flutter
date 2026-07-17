import '../config.dart';
import '../event/jala_event_bus.dart';
import '../mock/jala_mock_registry.dart';
import '../store/jala_store.dart';
import '../throttle/jala_throttle_registry.dart';
import 'jala_replay_registry.dart';

/// Process-wide singleton wiring together Jala's config, event bus,
/// store, replay registry, and mock registry.
///
/// Client integrations (e.g. `JalaDioInterceptor`) read
/// [JalaBinding.instance] instead of taking constructor parameters, so a
/// single `Jala.initialize()` call in the app configures every attached
/// client.
///
/// Before [initialize] is called the binding exists but is disabled
/// ([isEnabled] is false) — every capture path is a true no-op. Mock
/// short-circuits also require [isEnabled].
class JalaBinding {
  JalaBinding._() {
    throttleRegistry = JalaThrottleRegistry(isEnabled: () => isEnabled);
  }

  static JalaBinding _instance = JalaBinding._();

  /// The singleton binding.
  static JalaBinding get instance => _instance;

  JalaConfig? _config;
  JalaEventBus? _bus;
  JalaStore? _store;

  /// Registry the UI queries to replay calls; client integrations register
  /// themselves here.
  final JalaReplayRegistry replayRegistry = JalaReplayRegistry();

  /// Ordered mock rules (first enabled match wins). Always present; adapters
  /// only consult it when [isEnabled] is true.
  final JalaMockRegistry mockRegistry = JalaMockRegistry();

  /// The active network-throttle profile (if any) and helpers to apply it.
  /// Always present; every read reports "off" while [isEnabled] is false —
  /// see `JalaThrottleRegistry`.
  late final JalaThrottleRegistry throttleRegistry;

  /// Whether Jala is initialized *and* enabled by config. Hot networking
  /// paths check this before doing any capture work.
  bool get isEnabled => _config?.enabled ?? false;

  /// The active config.
  ///
  /// Throws [StateError] if [initialize] has not been called.
  JalaConfig get config => _require(_config, 'config');

  /// The event bus clients emit capture events into.
  ///
  /// Throws [StateError] if [initialize] has not been called.
  JalaEventBus get bus => _require(_bus, 'bus');

  /// The store materializing events into entries.
  ///
  /// Throws [StateError] if [initialize] has not been called.
  JalaStore get store => _require(_store, 'store');

  /// Whether [initialize] has been called.
  bool get isInitialized => _config != null;

  /// Wires up bus and store using [config] (or a default disabled
  /// [JalaConfig] when omitted).
  ///
  /// Idempotent: calling again after successful initialization does
  /// nothing and keeps the first configuration.
  void initialize({JalaConfig? config}) {
    if (isInitialized) return;
    final JalaConfig effective = config ?? JalaConfig();
    _config = effective;
    final JalaEventBus bus = JalaEventBus(isEnabled: () => isEnabled);
    _bus = bus;
    _store = JalaStore(
      bus: bus,
      maxEntries: effective.maxEntries,
      maxWsConnections: effective.maxWsConnections,
      maxWsFramesPerConnection: effective.maxWsFramesPerConnection,
      maxSubscriptionPayloads: effective.maxSubscriptionPayloads,
    );
  }

  /// Tears down the current binding and replaces the singleton with a
  /// fresh, uninitialized one. Intended for tests.
  static Future<void> resetForTesting() async {
    final JalaBinding old = _instance;
    _instance = JalaBinding._();
    await old._store?.dispose();
    await old._bus?.dispose();
    await old.mockRegistry.dispose();
    await old.throttleRegistry.dispose();
  }

  static T _require<T>(T? value, String name) {
    if (value == null) {
      throw StateError(
        'JalaBinding.$name accessed before JalaBinding.initialize()',
      );
    }
    return value;
  }
}
