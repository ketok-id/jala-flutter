/// Ketok — in-app Flutter network inspector (facade).
///
/// ```dart
/// void main() {
///   Ketok.initialize(); // enabled: kDebugMode by default
///   runApp(KetokOverlay(child: MyApp()));
/// }
/// ```
///
/// Attach Dio with `package:ketok_dio` (`KetokDio.attach(dio)`).
library;

export 'package:ketok_core/ketok_core.dart';
export 'package:ketok_ui/ketok_ui.dart';

export 'src/ketok.dart';
export 'src/ketok_overlay.dart';
