import 'package:flutter/material.dart';

import 'screens/jala_inspector_screen.dart';
import 'theme/jala_theme_controller.dart';

/// Entry point for pushing the Jala inspector as a standalone route.
class JalaInspector {
  const JalaInspector._();

  /// Builds a [MaterialPageRoute] wrapping [JalaInspectorScreen] in its
  /// own [JalaThemeScope], so the facade package can push it on a root
  /// overlay navigator without touching the host app's navigation or
  /// theme.
  ///
  /// Defaults to [JalaThemeScope.sharedController] rather than a private
  /// instance: screens this route pushes (call detail, diff, …) land on the
  /// host navigator as siblings of this route and so cannot inherit the
  /// scope below — they fall back to the shared controller, and defaulting
  /// to it here keeps the AppBar theme toggle in effect across all of them.
  static Route<void> route({JalaThemeController? themeController}) {
    return MaterialPageRoute<void>(
      builder: (BuildContext context) => JalaThemeScope(
        controller: themeController ?? JalaThemeScope.sharedController,
        child: const JalaInspectorScreen(),
      ),
    );
  }
}
