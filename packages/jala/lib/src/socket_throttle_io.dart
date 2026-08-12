import 'dart:io';

import 'package:jala_core/jala_core.dart' hide JalaSocketThrottle;
import 'package:jala_core/jala_socket_throttle_io.dart';

/// Installs socket-level throttling process-wide via [HttpOverrides.global].
///
/// Returns true if it was installed. Keeps the previous overrides so
/// [uninstallSocketThrottling] can restore them rather than clearing
/// somebody else's.
///
/// **This is the most invasive thing Jala does.** `HttpOverrides.global`
/// changes `HttpClient()` construction for the whole process, including code
/// that never opted into Jala — which is why it is never wired from
/// `Jala.initialize` and only ever from an explicit call.
bool installSocketThrottling(JalaThrottleRegistry registry) {
  if (_installed) return true;
  _previous = HttpOverrides.current;
  HttpOverrides.global = _JalaHttpOverrides(_previous, registry);
  registry.socketModeActive = true;
  _installed = true;
  return true;
}

/// Restores whatever overrides were in place before. Idempotent.
void uninstallSocketThrottling(JalaThrottleRegistry registry) {
  if (!_installed) return;
  HttpOverrides.global = _previous;
  _previous = null;
  registry.socketModeActive = false;
  _installed = false;
}

/// Whether socket-level throttling is currently installed.
bool get socketThrottlingInstalled => _installed;

bool _installed = false;
HttpOverrides? _previous;

class _JalaHttpOverrides extends HttpOverrides {
  _JalaHttpOverrides(this._previous, this._registry);

  final HttpOverrides? _previous;
  final JalaThrottleRegistry _registry;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    // Chain rather than replace: a host app may already have overrides for
    // its own reasons, and silently dropping them would be exactly the kind
    // of host breakage Jala promises never to cause.
    final HttpClient client =
        _previous?.createHttpClient(context) ?? super.createHttpClient(context);
    client.connectionFactory = JalaSocketThrottle.connectionFactory(_registry);
    return client;
  }

  @override
  String findProxyFromEnvironment(Uri url, Map<String, String>? environment) {
    return _previous?.findProxyFromEnvironment(url, environment) ??
        super.findProxyFromEnvironment(url, environment);
  }
}
