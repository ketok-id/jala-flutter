import 'package:flutter/material.dart';
import 'package:jala_core/jala_core.dart';

import '../theme/jala_theme.dart';

/// A small dot colored by [entry]'s status, or a spinner while pending.
class JalaStatusIndicator extends StatelessWidget {
  /// Creates a status indicator for [entry].
  const JalaStatusIndicator({required this.entry, super.key, this.size = 12});

  /// The entry whose status is rendered.
  final NetworkCallEntry entry;

  /// Diameter of the dot/spinner.
  final double size;

  @override
  Widget build(BuildContext context) {
    if (entry.status == JalaCallStatus.pending) {
      return SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: JalaTheme.statusColorFor(entry),
        shape: BoxShape.circle,
      ),
    );
  }
}
