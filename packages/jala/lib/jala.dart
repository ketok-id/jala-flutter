/// Jala — in-app Flutter network inspector (facade).
///
/// ```dart
/// void main() {
///   Jala.initialize(); // enabled: kDebugMode by default
///   runApp(JalaOverlay(child: MyApp()));
/// }
/// ```
///
/// Attach Dio with `package:jala_dio` (`JalaDio.attach(dio)`).
library;

export 'package:jala_core/jala_core.dart';
export 'package:jala_ui/jala_ui.dart';

export 'src/jala.dart';
export 'src/jala_overlay.dart';
