import 'package:flutter/material.dart';

import 'screens/ketok_inspector_screen.dart';
import 'theme/ketok_theme_controller.dart';

/// Entry point for pushing the Ketok inspector as a standalone route.
class KetokInspector {
  const KetokInspector._();

  /// Builds a [MaterialPageRoute] wrapping [KetokInspectorScreen] in its
  /// own [KetokThemeScope], so the facade package can push it on a root
  /// overlay navigator without touching the host app's navigation or
  /// theme.
  static Route<void> route({KetokThemeController? themeController}) {
    return MaterialPageRoute<void>(
      builder: (BuildContext context) => KetokThemeScope(
        controller: themeController ?? KetokThemeController(),
        child: const KetokInspectorScreen(),
      ),
    );
  }
}
