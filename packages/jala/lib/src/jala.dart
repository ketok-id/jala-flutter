import 'package:flutter/foundation.dart';
import 'package:jala_core/jala_core.dart';
import 'package:jala_ui/jala_ui.dart';

import 'file_jala_mock_store.dart';

/// Static facade for the Jala network inspector.
///
/// Call [initialize] once at app start, wrap the app in [JalaOverlay]
/// (from `jala_overlay.dart`), and attach clients (e.g. Dio via
/// `package:jala_dio`).
class Jala {
  Jala._();

  static final JalaController _controller = JalaController();

  /// Shared theme for the inspector surface (never inherits host Theme).
  static final JalaThemeController themeController = JalaThemeController();

  /// Controller driving overlay open/close state. Used by [JalaOverlay].
  static JalaController get controller => _controller;

  /// Idempotent. Wires [JalaBinding] with [config], or a default that is
  /// enabled only in debug mode (`kDebugMode`).
  static void initialize({JalaConfig? config}) {
    JalaBinding.instance.initialize(
      config: config ?? JalaConfig(enabled: kDebugMode),
    );
  }

  /// Attaches a file-backed mock rule store under [directory] and hydrates
  /// rules from disk. No-op when Jala is disabled.
  ///
  /// The directory is caller-supplied (e.g. from `path_provider`) so this
  /// package does not depend on platform path plugins. On web this is a
  /// no-op store (rules stay in memory only).
  ///
  /// ```dart
  /// Jala.initialize();
  /// final dir = await getApplicationSupportDirectory();
  /// await Jala.enableMockPersistence(dir.path);
  /// ```
  static Future<void> enableMockPersistence(String directory) async {
    if (!isEnabled) return;
    final FileJalaMockStore store = FileJalaMockStore(directory);
    await JalaBinding.instance.mockRegistry.attachStore(store);
  }

  /// Whether Jala is initialized and enabled.
  static bool get isEnabled => JalaBinding.instance.isEnabled;

  /// Whether [initialize] has been called.
  static bool get isInitialized => JalaBinding.instance.isInitialized;

  /// The live call store. Throws if not initialized.
  static JalaStore get store => JalaBinding.instance.store;

  /// The event bus clients emit into. Throws if not initialized.
  static JalaEventBus get bus => JalaBinding.instance.bus;

  /// Opens the inspector over the host app (via [JalaOverlay]).
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

/// ChangeNotifier that [JalaOverlay] listens to for open/close.
class JalaController extends ChangeNotifier {
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
