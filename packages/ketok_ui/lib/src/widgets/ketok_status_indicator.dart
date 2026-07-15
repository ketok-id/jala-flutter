import 'package:flutter/material.dart';
import 'package:ketok_core/ketok_core.dart';

import '../theme/ketok_theme.dart';

/// A small dot colored by [entry]'s status, or a spinner while pending.
class KetokStatusIndicator extends StatelessWidget {
  /// Creates a status indicator for [entry].
  const KetokStatusIndicator({required this.entry, super.key, this.size = 12});

  /// The entry whose status is rendered.
  final NetworkCallEntry entry;

  /// Diameter of the dot/spinner.
  final double size;

  @override
  Widget build(BuildContext context) {
    if (entry.status == KetokCallStatus.pending) {
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
        color: KetokTheme.statusColorFor(entry),
        shape: BoxShape.circle,
      ),
    );
  }
}
