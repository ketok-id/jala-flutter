import 'package:jala_core/jala_core.dart';

/// Web has no `dart:io`, so there is nothing to override and the
/// adapter-level throttle stays in charge. See
/// docs/plans/track-i-v0.8.3-socket-throttle.md, Open question 3.

/// Always false on this platform — nothing was installed.
bool installSocketThrottling(JalaThrottleRegistry registry) => false;

/// No-op on this platform.
void uninstallSocketThrottling(JalaThrottleRegistry registry) {}

/// Always false on this platform.
bool get socketThrottlingInstalled => false;
