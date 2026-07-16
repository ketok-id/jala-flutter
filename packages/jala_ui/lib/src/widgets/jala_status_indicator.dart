import 'package:flutter/material.dart';
import 'package:jala_core/jala_core.dart';

import '../theme/jala_theme.dart';
import '../util/format.dart';

/// A small dot colored by [entry]'s status; while pending, a determinate
/// [LinearProgressIndicator] when [NetworkCallEntry.progress] reports a
/// known total (see [progressFraction]), otherwise the previous
/// indeterminate spinner.
class JalaStatusIndicator extends StatelessWidget {
  /// Creates a status indicator for [entry].
  const JalaStatusIndicator({required this.entry, super.key, this.size = 12});

  /// The entry whose status is rendered.
  final NetworkCallEntry entry;

  /// Diameter of the dot/spinner (and, while a determinate bar is shown,
  /// its height).
  final double size;

  @override
  Widget build(BuildContext context) {
    if (entry.status == JalaCallStatus.pending) {
      final double? fraction = progressFraction(entry.progress);
      if (fraction != null) {
        return SizedBox(
          width: size * 3,
          height: size * 0.4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: size * 0.4,
            ),
          ),
        );
      }
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
