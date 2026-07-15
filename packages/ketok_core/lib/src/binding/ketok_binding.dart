import '../config.dart';
import '../event/ketok_event_bus.dart';
import '../store/ketok_store.dart';
import 'ketok_replay_registry.dart';

/// Process-wide singleton wiring together Ketok's config, event bus,
/// store, and replay registry.
///
/// Client integrations (e.g. `KetokDioInterceptor`) read
/// [KetokBinding.instance] instead of taking constructor parameters, so a
/// single `Ketok.initialize()` call in the app configures every attached
/// client.
///
/// Before [initialize] is called the binding exists but is disabled
/// ([isEnabled] is false) — every capture path is a true no-op.
class KetokBinding {
  KetokBinding._();

  static KetokBinding _instance = KetokBinding._();

  /// The singleton binding.
  static KetokBinding get instance => _instance;

  KetokConfig? _config;
  KetokEventBus? _bus;
  KetokStore? _store;

  /// Registry the UI queries to replay calls; client integrations register
  /// themselves here.
  final KetokReplayRegistry replayRegistry = KetokReplayRegistry();

  /// Whether Ketok is initialized *and* enabled by config. Hot networking
  /// paths check this before doing any capture work.
  bool get isEnabled => _config?.enabled ?? false;

  /// The active config.
  ///
  /// Throws [StateError] if [initialize] has not been called.
  KetokConfig get config => _require(_config, 'config');

  /// The event bus clients emit capture events into.
  ///
  /// Throws [StateError] if [initialize] has not been called.
  KetokEventBus get bus => _require(_bus, 'bus');

  /// The store materializing events into entries.
  ///
  /// Throws [StateError] if [initialize] has not been called.
  KetokStore get store => _require(_store, 'store');

  /// Whether [initialize] has been called.
  bool get isInitialized => _config != null;

  /// Wires up bus and store using [config] (or a default disabled
  /// [KetokConfig] when omitted).
  ///
  /// Idempotent: calling again after successful initialization does
  /// nothing and keeps the first configuration.
  void initialize({KetokConfig? config}) {
    if (isInitialized) return;
    final KetokConfig effective = config ?? KetokConfig();
    _config = effective;
    final KetokEventBus bus = KetokEventBus(isEnabled: () => isEnabled);
    _bus = bus;
    _store = KetokStore(bus: bus, maxEntries: effective.maxEntries);
  }

  /// Tears down the current binding and replaces the singleton with a
  /// fresh, uninitialized one. Intended for tests.
  static Future<void> resetForTesting() async {
    final KetokBinding old = _instance;
    _instance = KetokBinding._();
    await old._store?.dispose();
    await old._bus?.dispose();
  }

  static T _require<T>(T? value, String name) {
    if (value == null) {
      throw StateError(
        'KetokBinding.$name accessed before KetokBinding.initialize()',
      );
    }
    return value;
  }
}
