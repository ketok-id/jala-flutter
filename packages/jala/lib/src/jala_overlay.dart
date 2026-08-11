import 'package:flutter/cupertino.dart'
    show CupertinoLocalizations, DefaultCupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:jala_core/jala_core.dart';
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
          // Resolved from JalaConfig.locale only — the device locale is
          // deliberately never consulted (Track H, 0.8.1: following it
          // would change behaviour for existing hosts and force a minor).
          locale: _resolveLocale(),
          delegates: const <LocalizationsDelegate<Object?>>[
            DefaultWidgetsLocalizations.delegate,
            // NOT DefaultMaterialLocalizations.delegate: its isSupported is
            // `languageCode == 'en'`, so under an `id` locale Localizations
            // would skip it and the first MaterialLocalizations.of() — every
            // AppBar and Scaffold in the inspector — would throw. These
            // wrappers pin the framework strings to English instead, which
            // is the documented seam ("Back", "Close" stay English) rather
            // than a crash. Fixing it properly means depending on
            // flutter_localizations, which Track H refused because it pins
            // an exact `intl` version onto every host app.
            _EnglishMaterialLocalizationsDelegate(),
            _EnglishCupertinoLocalizationsDelegate(),
            JalaLocalizations.delegate,
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

/// The inspector's locale: [JalaConfig.locale] if set, else English.
///
/// Two rungs, no third. `PlatformDispatcher.instance.locale` is deliberately
/// not consulted — see [JalaConfig.locale].
Locale _resolveLocale() {
  final String? tag = JalaBinding.instance.isInitialized
      ? JalaBinding.instance.config.locale
      : null;
  if (tag == null || tag.isEmpty) return const Locale('en', 'US');
  final List<String> parts = tag.split(RegExp('[-_]'));
  final String language = parts.first.toLowerCase();
  // Unsupported tags still resolve here; JalaLocalizations.forLocale falls
  // back to English, and the framework delegates below are locale-agnostic.
  return parts.length > 1 && parts[1].isNotEmpty
      ? Locale(language, parts[1].toUpperCase())
      : Locale(language);
}

/// Supplies English [MaterialLocalizations] for *any* locale.
///
/// See the delegate list in [JalaOverlay] for why this exists.
class _EnglishMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _EnglishMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      DefaultMaterialLocalizations.load(const Locale('en', 'US'));

  @override
  bool shouldReload(_EnglishMaterialLocalizationsDelegate old) => false;
}

/// Supplies English [CupertinoLocalizations] for *any* locale.
class _EnglishCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _EnglishCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      DefaultCupertinoLocalizations.load(const Locale('en', 'US'));

  @override
  bool shouldReload(_EnglishCupertinoLocalizationsDelegate old) => false;
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
