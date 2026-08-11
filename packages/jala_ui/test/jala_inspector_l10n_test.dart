// Track H / H2 + H5: the inspector renders Indonesian when an id locale is
// installed, and the machine-read parts stay English on purpose.
import 'package:flutter/cupertino.dart'
    show CupertinoLocalizations, DefaultCupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jala_core/jala_core.dart';
import 'package:jala_ui/jala_ui.dart';

import 'test_helpers.dart';

/// Supplies English [MaterialLocalizations] for any locale.
///
/// `DefaultMaterialLocalizations.delegate.isSupported` is
/// `languageCode == 'en'`, so under an `id` locale Localizations skips it
/// and every Scaffold/TextField in the inspector throws. `JalaOverlay` pins
/// the framework strings the same way in production — see its delegate
/// list. Without flutter_localizations (which Track H refused) this is the
/// only way to render a non-en locale at all.
class _EnglishMaterialDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _EnglishMaterialDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      DefaultMaterialLocalizations.load(const Locale('en', 'US'));

  @override
  bool shouldReload(_EnglishMaterialDelegate old) => false;
}

/// Same trick as [_EnglishMaterialDelegate], for Cupertino — MaterialApp
/// pulls in a Cupertino delegate implicitly and warns if it can't serve the
/// locale.
class _EnglishCupertinoDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _EnglishCupertinoDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      DefaultCupertinoLocalizations.load(const Locale('en', 'US'));

  @override
  bool shouldReload(_EnglishCupertinoDelegate old) => false;
}

void main() {
  setUpAll(configureJalaUiTests);

  tearDown(() async {
    await JalaBinding.resetForTesting();
  });

  Future<void> pump(WidgetTester tester, Locale locale) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: const <LocalizationsDelegate<Object?>>[
          JalaLocalizations.delegate,
          _EnglishMaterialDelegate(),
          _EnglishCupertinoDelegate(),
          DefaultWidgetsLocalizations.delegate,
        ],
        supportedLocales: const <Locale>[Locale('en'), Locale('id')],
        home: const JalaInspectorScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty state is Indonesian under id', (
    WidgetTester tester,
  ) async {
    initJalaBinding();
    await pump(tester, const Locale('id'));
    expect(find.text('Belum ada network call yang tertangkap.'), findsOneWidget);
    expect(find.text('No network calls captured yet.'), findsNothing);
  });

  testWidgets('empty state is English under en', (WidgetTester tester) async {
    initJalaBinding();
    await pump(tester, const Locale('en'));
    expect(find.text('No network calls captured yet.'), findsOneWidget);
  });

  testWidgets('the filter DSL hint keeps its grammar under id', (
    WidgetTester tester,
  ) async {
    initJalaBinding();
    await pump(tester, const Locale('id'));

    // The hint documents the filter syntax. Translating the keywords would
    // fork the grammar per locale and break every shared filter string, so
    // method:/s:/host: must survive verbatim.
    final Finder field = find.byType(TextField).first;
    final String hint =
        (tester.widget<TextField>(field).decoration!.hintText) ?? '';
    expect(hint, contains('method:'));
    expect(hint, contains('s:4xx'));
    expect(hint, contains('host:'));
  });

  testWidgets('quick-filter chips keep their DSL terms under id', (
    WidgetTester tester,
  ) async {
    initJalaBinding();
    await pump(tester, const Locale('id'));
    // These are grammar tokens surfaced as chips, not prose.
    expect(find.text('4xx'), findsOneWidget);
    expect(find.text('5xx'), findsOneWidget);
  });

  testWidgets('the throttle screen renders Indonesian', (
    WidgetTester tester,
  ) async {
    initJalaBinding();
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('id'),
        localizationsDelegates: <LocalizationsDelegate<Object?>>[
          JalaLocalizations.delegate,
          _EnglishMaterialDelegate(),
          _EnglishCupertinoDelegate(),
          DefaultWidgetsLocalizations.delegate,
        ],
        supportedLocales: <Locale>[Locale('en'), Locale('id')],
        home: JalaThrottleScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tanpa simulasi kondisi jaringan'), findsOneWidget);
    // "Throttle" itself is kept English — dev vocabulary, per the H4 rule.
    expect(find.text('Throttle'), findsWidgets);
  });

  testWidgets('exports stay byte-identical across locales', (
    WidgetTester tester,
  ) async {
    // Locale must never leak into machine-read artifacts (H5).
    final JalaBinding binding = initJalaBinding();
    emitCompletedCall(binding.bus, 'c1');
    await tester.pump();

    // `exportedAt` is wall-clock and differs between any two encodes, so
    // normalize it — the point is locale leakage, not clock stability.
    String stable(String json) => json.replaceAll(
      RegExp(r'"exportedAt":\s*"[^"]*"'),
      '"exportedAt":"<t>"',
    );

    final String har = HarExporter.exportSession(
      JalaBinding.instance.store.entries,
    );
    final String session = stable(
      JalaSessionCodec.encode(JalaBinding.instance.store),
    );

    await pump(tester, const Locale('id'));

    expect(HarExporter.exportSession(JalaBinding.instance.store.entries), har);
    expect(
      stable(JalaSessionCodec.encode(JalaBinding.instance.store)),
      session,
      reason: 'locale must not leak into machine-read artifacts',
    );
    expect(har, contains('"method": "GET"'));
  });
}
