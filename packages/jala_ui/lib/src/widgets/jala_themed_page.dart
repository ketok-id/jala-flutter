import 'package:flutter/material.dart';

import '../theme/jala_theme.dart';
import '../theme/jala_theme_controller.dart';

/// Wraps [child] in an explicit Jala [Theme] (light/dark/system),
/// resolved from the nearest [JalaThemeScope] (or its fallback
/// singleton). Jala screens use this instead of relying on any host
/// `Theme` ancestor.
class JalaThemedPage extends StatelessWidget {
  /// Creates a themed page wrapping [child].
  const JalaThemedPage({required this.child, super.key});

  /// The content to theme.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final JalaThemeController controller = JalaThemeScope.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? _) {
        final Brightness brightness = switch (controller.mode) {
          JalaThemeMode.light => Brightness.light,
          JalaThemeMode.dark => Brightness.dark,
          JalaThemeMode.system => MediaQuery.platformBrightnessOf(context),
        };
        final ThemeData theme = brightness == Brightness.dark
            ? JalaTheme.dark
            : JalaTheme.light;
        return Theme(data: theme, child: child);
      },
    );
  }
}
