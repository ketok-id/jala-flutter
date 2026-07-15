import 'package:flutter/material.dart';

import '../theme/ketok_theme.dart';
import '../theme/ketok_theme_controller.dart';

/// Wraps [child] in an explicit Ketok [Theme] (light/dark/system),
/// resolved from the nearest [KetokThemeScope] (or its fallback
/// singleton). Ketok screens use this instead of relying on any host
/// `Theme` ancestor.
class KetokThemedPage extends StatelessWidget {
  /// Creates a themed page wrapping [child].
  const KetokThemedPage({required this.child, super.key});

  /// The content to theme.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final KetokThemeController controller = KetokThemeScope.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? _) {
        final Brightness brightness = switch (controller.mode) {
          KetokThemeMode.light => Brightness.light,
          KetokThemeMode.dark => Brightness.dark,
          KetokThemeMode.system => MediaQuery.platformBrightnessOf(context),
        };
        final ThemeData theme = brightness == Brightness.dark
            ? KetokTheme.dark
            : KetokTheme.light;
        return Theme(data: theme, child: child);
      },
    );
  }
}
