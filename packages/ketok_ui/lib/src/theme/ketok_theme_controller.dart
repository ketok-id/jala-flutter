import 'package:flutter/widgets.dart';

/// Which brightness the Ketok inspector should render in.
enum KetokThemeMode {
  /// Follow [MediaQuery.platformBrightnessOf] of the surrounding context.
  system,

  /// Always render [KetokTheme.light] (see `ketok_theme.dart`).
  light,

  /// Always render [KetokTheme.dark] (see `ketok_theme.dart`).
  dark,
}

/// Holds the current [KetokThemeMode] for the Ketok inspector UI.
///
/// Deliberately separate from the host app's theme: Ketok never inherits
/// the embedding app's `Theme`, so the inspector looks and reads
/// consistently no matter what app it's embedded in.
class KetokThemeController extends ChangeNotifier {
  /// Creates a controller, defaulting to [KetokThemeMode.system].
  KetokThemeController({KetokThemeMode mode = KetokThemeMode.system})
    : _mode = mode;

  KetokThemeMode _mode;

  /// The current theme mode.
  KetokThemeMode get mode => _mode;

  set mode(KetokThemeMode value) {
    if (_mode == value) return;
    _mode = value;
    notifyListeners();
  }

  /// Cycles system -> light -> dark -> system, used by the AppBar toggle.
  void cycle() {
    const List<KetokThemeMode> order = KetokThemeMode.values;
    mode = order[(order.indexOf(_mode) + 1) % order.length];
  }
}

/// Makes a [KetokThemeController] available to descendants.
///
/// Screens look it up via [KetokThemeScope.of], which never returns null:
/// absent an ancestor scope (e.g. a screen pumped standalone in a test, or
/// embedded without going through `KetokInspector.route()`), it falls back
/// to a package-level singleton controller so every Ketok widget still
/// shares one consistent, self-contained theme mode.
class KetokThemeScope extends InheritedNotifier<KetokThemeController> {
  /// Creates a scope exposing [controller] to descendants.
  const KetokThemeScope({
    required KetokThemeController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static final KetokThemeController _fallback = KetokThemeController();

  /// Returns the nearest ancestor controller, or a shared fallback
  /// singleton if this widget isn't wrapped in a [KetokThemeScope].
  static KetokThemeController of(BuildContext context) {
    final KetokThemeScope? scope = context
        .dependOnInheritedWidgetOfExactType<KetokThemeScope>();
    return scope?.notifier ?? _fallback;
  }
}
