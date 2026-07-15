import 'package:flutter/cupertino.dart' show DefaultCupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:ketok_ui/ketok_ui.dart';

import 'ketok.dart';

/// Inserts the Ketok bubble (and full-screen inspector host) above [child].
///
/// When Ketok is disabled or not initialized, returns [child] unchanged —
/// zero widgets, zero overhead.
///
/// The inspector uses its **own** [Navigator] so it never touches the host
/// app's navigation stack. Open/close via [Ketok.open] / [Ketok.close] or
/// by tapping the floating bubble.
class KetokOverlay extends StatelessWidget {
  /// Creates an overlay wrapper around [child].
  const KetokOverlay({required this.child, super.key});

  /// The host application widget tree.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!Ketok.isEnabled) return child;

    // Host apps commonly wrap MaterialApp *inside* KetokOverlay, so there
    // is often no ambient Directionality / MediaQuery yet. Provide the
    // minimum environment the bubble + inspector need.
    Widget layered = Stack(
      fit: StackFit.expand,
      textDirection: TextDirection.ltr,
      children: <Widget>[
        child,
        // The Ketok layer is a *sibling* of the host app, so it can never
        // inherit Localizations from a MaterialApp inside [child] — provide
        // defaults so AppBar & co. work regardless of host setup.
        Localizations(
          locale: const Locale('en', 'US'),
          delegates: const <LocalizationsDelegate<Object?>>[
            DefaultWidgetsLocalizations.delegate,
            DefaultMaterialLocalizations.delegate,
            DefaultCupertinoLocalizations.delegate,
          ],
          child: ListenableBuilder(
            listenable: Ketok.controller,
            builder: (BuildContext context, Widget? _) {
              return Stack(
                fit: StackFit.expand,
                textDirection: TextDirection.ltr,
                children: <Widget>[
                  if (Ketok.controller.isOpen)
                    const Positioned.fill(
                      child: _KetokInspectorHost(
                        onClose: Ketok.close,
                      ),
                    ),
                  const KetokOverlayButton(onTap: Ketok.open),
                ],
              );
            },
          ),
        ),
      ],
    );

    if (Directionality.maybeOf(context) == null) {
      layered = Directionality(
        textDirection: TextDirection.ltr,
        child: layered,
      );
    }
    return layered;
  }
}

/// Full-screen host with its own navigator for the inspector.
class _KetokInspectorHost extends StatefulWidget {
  const _KetokInspectorHost({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_KetokInspectorHost> createState() => _KetokInspectorHostState();
}

class _KetokInspectorHostState extends State<_KetokInspectorHost>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The inspector lives outside every route, so the system back button
  // (Android) would otherwise fall through to the host app — popping its
  // routes or exiting the app while the inspector covers the screen.
  // While the host is mounted, back pops the inspector's own navigator,
  // then closes the inspector.
  @override
  Future<bool> didPopRoute() async {
    final NavigatorState? nav = _navKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
    } else {
      widget.onClose();
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Navigator(
          key: _navKey,
          onGenerateRoute: (RouteSettings settings) {
            return PageRouteBuilder<void>(
              settings: settings,
              pageBuilder: (
                BuildContext context,
                Animation<double> animation,
                Animation<double> secondaryAnimation,
              ) {
                return KetokThemeScope(
                  controller: Ketok.themeController,
                  child: PopScope(
                    canPop: true,
                    onPopInvokedWithResult: (bool didPop, Object? result) {
                      if (didPop) {
                        // Root route popped — hide the host.
                        widget.onClose();
                      }
                    },
                    child: KetokInspectorScreen(onClose: widget.onClose),
                  ),
                );
              },
              transitionsBuilder: (
                BuildContext context,
                Animation<double> animation,
                Animation<double> secondaryAnimation,
                Widget child,
              ) {
                return FadeTransition(opacity: animation, child: child);
              },
            );
          },
        ),
      ),
    );
  }
}
