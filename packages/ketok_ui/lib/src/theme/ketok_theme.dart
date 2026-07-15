import 'package:flutter/material.dart';
import 'package:ketok_core/ketok_core.dart';

/// Explicit, self-contained Material 3 theming for the Ketok inspector.
///
/// Ketok never inherits the host app's `Theme` — [light] and [dark] are
/// built from scratch so the inspector looks the same regardless of what
/// app it is embedded in.
class KetokTheme {
  const KetokTheme._();

  static const Color _seed = Color(0xFF5B5BD6);

  /// Neutral color for a pending (in-flight) call.
  static const Color pendingColor = Color(0xFF9E9E9E);

  /// Color for 2xx responses.
  static const Color successColor = Color(0xFF2E7D32);

  /// Color for 3xx responses.
  static const Color redirectColor = Color(0xFF1565C0);

  /// Color for 4xx responses.
  static const Color clientErrorColor = Color(0xFFEF6C00);

  /// Color for 5xx responses and transport-level errors.
  static const Color serverErrorColor = Color(0xFFC62828);

  /// Color for cancelled calls.
  static const Color cancelledColor = Color(0xFF757575);

  /// The light theme.
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    ),
    visualDensity: VisualDensity.standard,
  );

  /// The dark theme.
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ),
    visualDensity: VisualDensity.standard,
  );

  /// Resolves the status color for [entry]'s current lifecycle state.
  static Color statusColorFor(NetworkCallEntry entry) {
    switch (entry.status) {
      case KetokCallStatus.pending:
        return pendingColor;
      case KetokCallStatus.cancelled:
        return cancelledColor;
      case KetokCallStatus.error:
        return serverErrorColor;
      case KetokCallStatus.success:
        final int? code = entry.statusCode;
        if (code == null) return pendingColor;
        if (code < 300) return successColor;
        if (code < 400) return redirectColor;
        if (code < 500) return clientErrorColor;
        return serverErrorColor;
    }
  }
}
