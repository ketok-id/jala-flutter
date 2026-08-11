// Track H / H3 + H5: locale resolution and the constraints that keep this
// release a patch rather than a minor.
import 'dart:io';

import 'package:flutter/cupertino.dart' show CupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jala/jala.dart';

void main() {
  setUpAll(() => EditableText.debugDeterministicCursor = true);

  tearDown(() async {
    Jala.resetControllerForTesting();
    await JalaBinding.resetForTesting();
  });

  Future<void> openWith(WidgetTester tester, {String? locale}) async {
    Jala.initialize(config: JalaConfig(enabled: true, locale: locale));
    await tester.pumpWidget(
      const JalaOverlay(
        child: MaterialApp(home: Scaffold(body: Text('host'))),
      ),
    );
    Jala.open();
    await tester.pumpAndSettle();
  }

  /// The JalaLocalizations table actually resolved inside the inspector.
  JalaLocalizations resolved(WidgetTester tester) {
    return JalaLocalizations.of(
      tester.element(find.byType(JalaInspectorScreen)),
    );
  }

  testWidgets('unset locale renders English', (WidgetTester tester) async {
    await openWith(tester);
    expect(resolved(tester), isA<JalaLocalizationsEn>());
  });

  testWidgets('JalaConfig.locale id-ID resolves the Indonesian table', (
    WidgetTester tester,
  ) async {
    await openWith(tester, locale: 'id-ID');
    expect(resolved(tester), isA<JalaLocalizationsId>());
  });

  testWidgets('bare id resolves too', (WidgetTester tester) async {
    await openWith(tester, locale: 'id');
    expect(resolved(tester), isA<JalaLocalizationsId>());
  });

  testWidgets('an unsupported locale falls back to English, does not throw', (
    WidgetTester tester,
  ) async {
    await openWith(tester, locale: 'fr-FR');
    expect(resolved(tester), isA<JalaLocalizationsEn>());
    expect(tester.takeException(), isNull);
  });

  testWidgets('OPT-IN GUARANTEE: platform locale id does NOT translate', (
    WidgetTester tester,
  ) async {
    // This is the test that decides the version number. Jala must ignore the
    // device locale entirely: an app on an Indonesian phone that has not set
    // JalaConfig.locale must render exactly as it did before this feature
    // existed. If this ever goes red the release is a 0.9.0, not a 0.8.1 —
    // see docs/plans/track-h-v0.8.1-l10n.md.
    tester.platformDispatcher.localeTestValue = const Locale('id', 'ID');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    await openWith(tester); // locale deliberately unset

    expect(
      resolved(tester),
      isA<JalaLocalizationsEn>(),
      reason: 'the device locale must never be consulted — following it is '
          'a behaviour change and forces a minor release',
    );
  });

  testWidgets('Material strings still resolve under a non-en locale', (
    WidgetTester tester,
  ) async {
    // DefaultMaterialLocalizations.delegate.isSupported is
    // `languageCode == "en"`, so installing it directly under an `id` locale
    // makes Localizations skip it and every MaterialLocalizations.of() in
    // the inspector throws. The overlay pins English framework strings via
    // its own delegates instead; this proves the AppBar survives.
    await openWith(tester, locale: 'id-ID');

    final BuildContext ctx = tester.element(
      find.byType(JalaInspectorScreen),
    );
    expect(MaterialLocalizations.of(ctx), isNotNull);
    expect(CupertinoLocalizations.of(ctx), isNotNull);
    expect(tester.takeException(), isNull);
  });

  test('JalaConfig.locale defaults to null (English)', () {
    expect(JalaConfig().locale, isNull);
    expect(JalaConfig(locale: 'id-ID').locale, 'id-ID');
  });

  test('no intl dependency crept into the workspace lockfile', () {
    // The whole premise of hand-rolling the delegate: a debugging library
    // must not pin a host app's `intl` version. See track-h H5.
    final File lock = File('../../pubspec.lock');
    expect(lock.existsSync(), isTrue, reason: 'workspace lockfile missing');
    final String text = lock.readAsStringSync();
    expect(
      RegExp(r'^  intl:', multiLine: true).hasMatch(text),
      isFalse,
      reason: 'flutter_localizations/intl would pin an exact intl version '
          'onto every host app — Track H refused that dependency',
    );
  });
}
