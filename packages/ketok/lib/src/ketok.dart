import 'package:flutter/foundation.dart';
import 'package:ketok_core/ketok_core.dart';
import 'package:ketok_ui/ketok_ui.dart';

/// Static facade for the Ketok network inspector.
///
/// Call [initialize] once at app start, wrap the app in [KetokOverlay]
/// (from `ketok_overlay.dart`), and attach clients (e.g. Dio via
/// `package:ketok_dio`).
class Ketok {
  Ketok._();

  static final KetokController _controller = KetokController();

  /// Shared theme for the inspector surface (never inherits host Theme).
  static final KetokThemeController themeController = KetokThemeController();

  /// Controller driving overlay open/close state. Used by [KetokOverlay].
  static KetokController get controller => _controller;

  /// Idempotent. Wires [KetokBinding] with [config], or a default that is
  /// enabled only in debug mode (`kDebugMode`).
  static void initialize({KetokConfig? config}) {
    KetokBinding.instance.initialize(
      config: config ?? KetokConfig(enabled: kDebugMode),
    );
  }

  /// Whether Ketok is initialized and enabled.
  static bool get isEnabled => KetokBinding.instance.isEnabled;

  /// Whether [initialize] has been called.
  static bool get isInitialized => KetokBinding.instance.isInitialized;

  /// The live call store. Throws if not initialized.
  static KetokStore get store => KetokBinding.instance.store;

  /// The event bus clients emit into. Throws if not initialized.
  static KetokEventBus get bus => KetokBinding.instance.bus;

  /// Opens the inspector over the host app (via [KetokOverlay]).
  ///
  /// No-op when disabled, not initialized, or already open.
  static void open() {
    if (!isEnabled) return;
    _controller.open();
  }

  /// Closes the inspector if it is open.
  static void close() {
    _controller.close();
  }

  /// Whether the inspector surface is currently visible.
  static bool get isOpen => _controller.isOpen;

  /// Test-only: resets facade controller state (not the binding).
  @visibleForTesting
  static void resetControllerForTesting() {
    _controller.close();
  }
}

/// ChangeNotifier that [KetokOverlay] listens to for open/close.
class KetokController extends ChangeNotifier {
  bool _isOpen = false;

  /// Whether the inspector is currently shown.
  bool get isOpen => _isOpen;

  /// Shows the inspector.
  void open() {
    if (_isOpen) return;
    _isOpen = true;
    notifyListeners();
  }

  /// Hides the inspector.
  void close() {
    if (!_isOpen) return;
    _isOpen = false;
    notifyListeners();
  }
}
