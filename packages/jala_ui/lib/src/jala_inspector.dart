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
  static Route<void> route({JalaThemeController? themeController}) {
    return MaterialPageRoute<void>(
      builder: (BuildContext context) => JalaThemeScope(
        controller: themeController ?? JalaThemeController(),
        child: const JalaInspectorScreen(),
      ),
    );
  }
}
