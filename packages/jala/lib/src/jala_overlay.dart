import 'package:flutter/cupertino.dart' show DefaultCupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:jala_ui/jala_ui.dart';

import 'jala.dart';

/// Inserts the Jala bubble (and full-screen inspector host) above [child].
///
/// When Jala is disabled or not initialized, returns [child] unchanged —
/// zero widgets, zero overhead.
///
/// The inspector uses its **own** [Navigator] so it never touches the host
/// app's navigation stack. Open/close via [Jala.open] / [Jala.close] or
/// by tapping the floating bubble.
class JalaOverlay extends StatelessWidget {
  /// Creates an overlay wrapper around [child].
  const JalaOverlay({required this.child, super.key});

  /// The host application widget tree.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!Jala.isEnabled) return child;

    // Host apps commonly wrap MaterialApp *inside* JalaOverlay, so there
    // is often no ambient Directionality / MediaQuery yet. Provide the
    // minimum environment the bubble + inspector need.
    Widget layered = Stack(
      fit: StackFit.expand,
      textDirection: TextDirection.ltr,
      children: <Widget>[
        child,
        // The Jala layer is a *sibling* of the host app, so it can never
        // inherit Localizations from a MaterialApp inside [child] — provide
        // defaults so AppBar & co. work regardless of host setup.
        Localizations(
          locale: const Locale('en', 'US'),
          delegates: const <LocalizationsDelegate<Object?>>[
            DefaultWidgetsLocalizations.delegate,
            DefaultMaterialLocalizations.delegate,
            DefaultCupertinoLocalizations.delegate,
          ],
          // Same sibling problem, second instance: `WidgetsApp` is what
          // normally installs the keyboard shortcut/action chain, and the
          // whole inspector sits outside it. Mirror WidgetsApp's own
          // nesting and order — Shortcuts wraps DefaultTextEditingShortcuts
          // so text editing can fall through to the general bindings.
          //
          // Two user-visible bugs came from not having this:
          //  * Backspace did nothing on Android. The soft delete key arrives
          //    as a KEYCODE_DEL *key event* there, which needs
          //    DefaultTextEditingShortcuts to become a DeleteCharacterIntent;
          //    iOS sends it over the IME channel as an editing-value update,
          //    which is why iOS looked fine. Affects every field — filter
          //    bar, throttle host pattern, mock editor, composer.
          //  * Escape did not dismiss dialogs/sheets, Tab did not traverse,
          //    and Enter/Space did not activate — those live in
          //    WidgetsApp.defaultShortcuts. Reachable on any keyboard: web
          //    demo, Chromebook, Android tablet, desktop.
          child: Shortcuts(
            debugLabel: '<Jala inspector shortcuts>',
            shortcuts: WidgetsApp.defaultShortcuts,
            child: DefaultTextEditingShortcuts(
              child: Actions(
                actions: <Type, Action<Intent>>{
                  ...WidgetsApp.defaultActions,
                  // Keyboard scrolling of the call list; overridable exactly
                  // as WidgetsApp declares it.
                  ScrollIntent: Action<ScrollIntent>.overridable(
                    context: context,
                    defaultAction: ScrollAction(),
                  ),
                },
                // TapRegion is inert without a surface to arbitrate it —
                // menu/selection-toolbar dismissal depends on it.
                child: TapRegionSurface(
                  child: ListenableBuilder(
                    listenable: Jala.controller,
                    builder: (BuildContext context, Widget? _) {
                      return Stack(
                        fit: StackFit.expand,
                        textDirection: TextDirection.ltr,
                        children: <Widget>[
                          if (Jala.controller.isOpen)
                            const Positioned.fill(
                              child: _JalaInspectorHost(
                                onClose: Jala.close,
                              ),
                            ),
                          // Hide the bubble while the inspector is open so
                          // it does not cover list rows / detail actions
                          // (user feedback).
                          if (!Jala.controller.isOpen)
                            const JalaOverlayButton(onTap: Jala.open),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
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
class _JalaInspectorHost extends StatefulWidget {
  const _JalaInspectorHost({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_JalaInspectorHost> createState() => _JalaInspectorHostState();
}

class _JalaInspectorHostState extends State<_JalaInspectorHost> {
  // System back is handled by the observer Jala.initialize() registers, not
  // here. Registering from this State put Jala *after* the host's
  // `WidgetsApp` in WidgetsBinding's insertion-ordered observer list, so the
  // host consumed every back event first and this never ran. The navigator
  // key therefore lives on `Jala` — the observer outlives this widget.
  @override
  Widget build(BuildContext context) {
    // ScaffoldMessenger is normally provided by MaterialApp, which the
    // inspector deliberately lives outside of — without our own, every
    // snackbar action (copy, replay) throws / crashes in release.
    return ScaffoldMessenger(
      child: Material(
        color: Colors.black54,
        child: SafeArea(
          // The theme scope must sit *above* the Navigator, not inside a
          // route's pageBuilder: a pushed route (call detail, diff, mocks,
          // composer, …) is a sibling overlay entry of the root route, so
          // it cannot see an InheritedWidget introduced inside that route.
          // Scoping per-route left every pushed screen falling back to
          // JalaThemeScope's singleton — a different controller than the
          // AppBar toggle mutates — so detail screens ignored the theme.
          child: JalaThemeScope(
            controller: Jala.themeController,
            child: Navigator(
              key: Jala.inspectorNavigatorKey,
              onGenerateRoute: (RouteSettings settings) {
                return PageRouteBuilder<void>(
                  settings: settings,
                  pageBuilder: (
                    BuildContext context,
                    Animation<double> animation,
                    Animation<double> secondaryAnimation,
                  ) {
                    return PopScope(
                      canPop: true,
                      onPopInvokedWithResult: (bool didPop, Object? result) {
                        if (didPop) {
                          // Root route popped — hide the host.
                          widget.onClose();
                        }
                      },
                      child: JalaInspectorScreen(onClose: widget.onClose),
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
        ),
      ),
    );
  }
}
