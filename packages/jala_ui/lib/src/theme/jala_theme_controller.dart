import 'package:flutter/widgets.dart';

/// Which brightness the Jala inspector should render in.
enum JalaThemeMode {
  /// Follow [MediaQuery.platformBrightnessOf] of the surrounding context.
  system,

  /// Always render [JalaTheme.light] (see `jala_theme.dart`).
  light,

  /// Always render [JalaTheme.dark] (see `jala_theme.dart`).
  dark,
}

/// Holds the current [JalaThemeMode] for the Jala inspector UI.
///
/// Deliberately separate from the host app's theme: Jala never inherits
/// the embedding app's `Theme`, so the inspector looks and reads
/// consistently no matter what app it's embedded in.
class JalaThemeController extends ChangeNotifier {
  /// Creates a controller, defaulting to [JalaThemeMode.system].
  JalaThemeController({JalaThemeMode mode = JalaThemeMode.system})
    : _mode = mode;

  JalaThemeMode _mode;

  /// The current theme mode.
  JalaThemeMode get mode => _mode;

  set mode(JalaThemeMode value) {
    if (_mode == value) return;
    _mode = value;
    notifyListeners();
  }

  /// Cycles system -> light -> dark -> system, used by the AppBar toggle.
  void cycle() {
    const List<JalaThemeMode> order = JalaThemeMode.values;
    mode = order[(order.indexOf(_mode) + 1) % order.length];
  }
}

/// Makes a [JalaThemeController] available to descendants.
///
/// Screens look it up via [JalaThemeScope.of], which never returns null:
/// absent an ancestor scope (e.g. a screen pumped standalone in a test, or
/// embedded without going through `JalaInspector.route()`), it falls back
/// to a package-level singleton controller so every Jala widget still
/// shares one consistent, self-contained theme mode.
class JalaThemeScope extends InheritedNotifier<JalaThemeController> {
  /// Creates a scope exposing [controller] to descendants.
  const JalaThemeScope({
    required JalaThemeController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static final JalaThemeController _fallback = JalaThemeController();

  /// Returns the nearest ancestor controller, or a shared fallback
  /// singleton if this widget isn't wrapped in a [JalaThemeScope].
  static JalaThemeController of(BuildContext context) {
    final JalaThemeScope? scope = context
        .dependOnInheritedWidgetOfExactType<JalaThemeScope>();
    return scope?.notifier ?? _fallback;
  }
}
