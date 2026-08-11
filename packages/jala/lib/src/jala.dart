import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:jala_core/jala_core.dart';
import 'package:jala_ui/jala_ui.dart';

import 'file_export_sink.dart';
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

  /// Key for the inspector's private [Navigator], owned here rather than by
  /// the overlay's State so [_JalaBackObserver] — which is registered before
  /// the overlay ever mounts — can reach it. See [initialize].
  static final GlobalKey<NavigatorState> inspectorNavigatorKey =
      GlobalKey<NavigatorState>();

  static final _JalaBackObserver _backObserver = _JalaBackObserver();
  static bool _backObserverRegistered = false;

  /// Idempotent. Wires [JalaBinding] with [config], or a default that is
  /// enabled only in debug mode (`kDebugMode`).
  ///
  /// Also registers the system-back observer. **Registration order matters
  /// and is the whole reason this lives in `initialize` rather than in
  /// [JalaOverlay]'s State:** `WidgetsBinding.handlePopRoute` walks its
  /// observer list in insertion order and stops at the first one that
  /// returns true. The host's `WidgetsApp` registers during its first build,
  /// so anything registered from a widget inside the tree lands *after* it
  /// and never sees the event — the inspector's own back handling was dead
  /// code for exactly that reason. `initialize()` runs before `runApp`, so
  /// registering here puts Jala first. The observer is inert (returns false,
  /// claims no gesture) whenever the inspector is closed.
  static void initialize({JalaConfig? config}) {
    JalaBinding.instance.initialize(
      config: config ?? JalaConfig(enabled: kDebugMode),
    );
    if (!_backObserverRegistered) {
      WidgetsBinding.instance.addObserver(_backObserver);
      _backObserverRegistered = true;
    }
  }

  /// Attaches a file-backed mock rule store under [directory] and hydrates
  /// rules from disk. No-op when Jala is disabled.
  ///
  /// Writes plaintext `{directory}/jala_mock_rules.json` (URL patterns and
  /// canned bodies). Intended for **developer machines / internal builds**,
  /// not end-user devices. On web this is a no-op store (in-memory only).
  /// See docs/SECURITY.md.
  ///
  /// The directory is caller-supplied (e.g. from `path_provider`) so this
  /// package does not depend on platform path plugins.
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

  /// Routes session/HAR exports to files under [directory] instead of the
  /// clipboard. No-op when Jala is disabled.
  ///
  /// The clipboard is the default because it needs no configuration, but it
  /// has a hard ceiling on Android — the system clipboard rides the Binder
  /// transaction buffer (~1 MB, shared process-wide), and a full session
  /// export with bodies clears that routinely. When it does, the copy fails
  /// and there is nowhere to paste 5 MB of JSON on a phone anyway. A file
  /// has neither problem and can be pulled off the device.
  ///
  /// Writes `{directory}/jala_session-{timestamp}.json` (or `.har`) in
  /// plaintext, including whatever bodies and headers survived redaction —
  /// **internal builds only**, same posture as [enableMockPersistence]. See
  /// docs/SECURITY.md. On web this reports an error rather than writing.
  ///
  /// The directory is caller-supplied (e.g. from `path_provider`) so this
  /// package does not depend on platform path plugins.
  ///
  /// ```dart
  /// Jala.initialize();
  /// final dir = await getApplicationDocumentsDirectory();
  /// Jala.enableFileExport(dir.path);
  /// ```
  static void enableFileExport(String directory) {
    if (!isEnabled) return;
    JalaExportSink.install(FileJalaExportSink(directory));
  }

  /// Restores the default clipboard export destination.
  static void disableFileExport() => JalaExportSink.install(null);

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
    // The host's `WidgetsApp` reports *its* pop capability to the platform
    // (`NavigationNotification` → `setFrameworkHandlesBack`). The inspector's
    // Navigator is a sibling, outside that NotificationListener, so its
    // routes never count: with the host sitting on its root route Android is
    // told the framework does not handle back and finishes the activity
    // without ever dispatching to Dart. Claim it while the inspector is up.
    unawaited(SystemNavigator.setFrameworkHandlesBack(true));
  }

  /// Closes the inspector if it is open.
  ///
  /// Deliberately does **not** hand `setFrameworkHandlesBack` back to
  /// `false`: the host's real value is unknowable from here, and guessing
  /// wrong strands a host that still has routes to pop (back would exit the
  /// app instead of popping). Leaving it true only routes back through Dart,
  /// where [_JalaBackObserver] declines and the host's `WidgetsApp` handles
  /// it exactly as it always did — popping if it can, falling through to
  /// `SystemNavigator.pop()` if it cannot.
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

/// Routes the Android system back gesture/button to the inspector while it
/// is open, and stays out of the way entirely when it is not.
///
/// Order of preference, per user requirement: pop the inspector's own
/// navigator if it has anything to pop, otherwise close the inspector. The
/// host app's navigation is never touched while Jala is visible.
class _JalaBackObserver with WidgetsBindingObserver {
  /// True when this observer consumed the event; false hands it to the next
  /// observer (i.e. the host's `WidgetsApp`) unchanged.
  bool _handleBack() {
    if (!Jala.isOpen) return false;
    final NavigatorState? nav = Jala.inspectorNavigatorKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
    } else {
      Jala.close();
    }
    return true;
  }

  @override
  Future<bool> didPopRoute() async => _handleBack();

  // Predictive back (API 33+) never reaches didPopRoute — the gesture is
  // dispatched through this trio instead, and an observer that claims no
  // gesture is skipped for the rest of it.
  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) => Jala.isOpen;

  @override
  void handleCommitBackGesture() {
    _handleBack();
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
