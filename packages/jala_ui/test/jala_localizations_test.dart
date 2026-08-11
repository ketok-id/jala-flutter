import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jala_ui/jala_ui.dart';

import 'test_helpers.dart';

/// Pumps [child] under a [Localizations] carrying the Jala delegate.
Widget _localized(Locale locale, Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Localizations(
      locale: locale,
      delegates: const <LocalizationsDelegate<Object?>>[
        JalaLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
      ],
      child: child,
    ),
  );
}

void main() {
  setUpAll(configureJalaUiTests);

  group('locale resolution', () {
    test('forLocale matches on language code, ignoring country', () {
      expect(
        JalaLocalizations.forLocale(const Locale('id')),
        isA<JalaLocalizationsId>(),
      );
      expect(
        JalaLocalizations.forLocale(const Locale('id', 'ID')),
        isA<JalaLocalizationsId>(),
      );
      expect(
        JalaLocalizations.forLocale(const Locale('en')),
        isA<JalaLocalizationsEn>(),
      );
    });

    test('forLocale falls back to English for unsupported locales', () {
      expect(
        JalaLocalizations.forLocale(const Locale('ja')),
        isA<JalaLocalizationsEn>(),
      );
    });

    test('forLanguageTag parses tags and degrades to English', () {
      expect(
        JalaLocalizations.forLanguageTag('id-ID'),
        isA<JalaLocalizationsId>(),
      );
      expect(
        JalaLocalizations.forLanguageTag('id_ID'),
        isA<JalaLocalizationsId>(),
      );
      expect(JalaLocalizations.forLanguageTag('ID'), isA<JalaLocalizationsId>());
      expect(JalaLocalizations.forLanguageTag(null), isA<JalaLocalizationsEn>());
      expect(JalaLocalizations.forLanguageTag(''), isA<JalaLocalizationsEn>());
      expect(
        JalaLocalizations.forLanguageTag('not a tag'),
        isA<JalaLocalizationsEn>(),
      );
    });

    testWidgets('of() resolves the installed delegate', (
      WidgetTester tester,
    ) async {
      late JalaLocalizations resolved;
      await tester.pumpWidget(
        _localized(
          const Locale('id'),
          Builder(
            builder: (BuildContext context) {
              resolved = JalaLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved, isA<JalaLocalizationsId>());
      expect(resolved.actionCancel, 'Batal');
    });
  });

  group('missing-delegate contract', () {
    // H1: jala_ui widgets are exported individually and a host may mount one
    // anywhere. A missing delegate must degrade to English, never throw —
    // capture and UI both follow "never break the host app".
    testWidgets('of() returns English instead of throwing', (
      WidgetTester tester,
    ) async {
      late JalaLocalizations resolved;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (BuildContext context) {
              resolved = JalaLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(resolved, isA<JalaLocalizationsEn>());
      expect(resolved.inspectorTitle, 'Jala');
    });
  });

  group('plurals', () {
    test('English inflects, Indonesian does not', () {
      const JalaLocalizations en = JalaLocalizationsEn();
      expect(en.inspectorCopiedHar(1), 'Copied HAR for 1 call');
      expect(en.inspectorCopiedHar(2), 'Copied HAR for 2 calls');
      expect(en.mockEditorMatches(1), 'Matches 1 captured call');
      expect(en.mockEditorMatches(0), 'Matches 0 captured calls');
      expect(en.inspectorImportedSessionBanner(1), contains('1 entry)'));
      expect(en.inspectorImportedSessionBanner(3), contains('3 entries)'));

      // Indonesian nouns do not inflect for number — this is why the track
      // does not need ICU plural machinery (and therefore no `intl`).
      const JalaLocalizations id = JalaLocalizationsId();
      expect(id.inspectorCopiedHar(1), 'HAR disalin untuk 1 call');
      expect(id.inspectorCopiedHar(2), 'HAR disalin untuk 2 call');
    });
  });

  group('table completeness', () {
    // The abstract base has no defaults, so a missing member is a compile
    // error. These cover what the compiler cannot: a translation that was
    // left as its English source, and empty strings.
    test('no member returns an empty string', () {
      for (final JalaLocalizations table in <JalaLocalizations>[
        const JalaLocalizationsEn(),
        const JalaLocalizationsId(),
      ]) {
        for (final String value in _allStrings(table)) {
          expect(value.trim(), isNotEmpty, reason: 'empty string in $table');
        }
      }
    });

    test('Indonesian differs from English on translated prose', () {
      const JalaLocalizations en = JalaLocalizationsEn();
      const JalaLocalizations id = JalaLocalizationsId();
      // Spot-check the prose that must not be left in English. Jargon that
      // deliberately stays English (Body, Method, Session…) is excluded by
      // design — see JalaLocalizationsId's doc comment.
      expect(id.actionCancel, isNot(en.actionCancel));
      expect(id.inspectorEmpty, isNot(en.inspectorEmpty));
      expect(id.callDetailUnavailable, isNot(en.callDetailUnavailable));
      expect(id.throttleApply, isNot(en.throttleApply));
      expect(id.filterHelpIntro, isNot(en.filterHelpIntro));
      expect(id.mocksEmpty, isNot(en.mocksEmpty));
    });

    test('jargon stays English in both tables', () {
      const JalaLocalizations id = JalaLocalizationsId();
      expect(id.sectionBody, 'Body');
      expect(id.sectionHeaders, 'Headers');
      expect(id.fieldMethod, 'Method');
      expect(id.callDetailTabRequest, 'Request');
      expect(id.callDetailTabResponse, 'Response');
      expect(id.callDetailReplay, 'Replay');
      expect(id.inspectorSession, 'Session');
    });

    test('the filter DSL hint keeps its grammar untranslated', () {
      const JalaLocalizations id = JalaLocalizationsId();
      // The DSL is a syntax, not prose: translating the terms would fork
      // the grammar per locale and break shared filter strings.
      expect(id.inspectorFilterHint, contains('method:get'));
      expect(id.inspectorFilterHint, contains('s:4xx'));
      expect(id.inspectorCurlHint, startsWith('curl '));
    });
  });
}

/// Every string-valued member of [table], for table-wide assertions.
List<String> _allStrings(JalaLocalizations t) {
  return <String>[
    t.actionCancel,
    t.actionClear,
    t.actionSave,
    t.actionImport,
    t.actionSend,
    t.actionReplace,
    t.actionAppend,
    t.tooltipCopyValue,
    t.tooltipClearSearch,
    t.tooltipExpandAll,
    t.tooltipCollapseAll,
    t.labelEmptyValue,
    t.labelNoValue,
    t.labelNoMatches,
    t.copied('X'),
    t.inspectorTitle,
    t.inspectorClose,
    t.inspectorClearConfirmTitle,
    t.inspectorMocks,
    t.inspectorComfortableList,
    t.inspectorCompactList,
    t.inspectorCopySessionAsHar,
    t.inspectorSession,
    t.inspectorExportSessionFull,
    t.inspectorExportSessionNoBodies,
    t.inspectorExportSessionHeadersOnly,
    t.inspectorImportSession,
    t.inspectorImportHarMenu,
    t.inspectorImportCurlMenu,
    t.inspectorImportHarTitle,
    t.inspectorImportCurlTitle,
    t.inspectorOpenInComposer,
    t.inspectorFilterHint,
    t.inspectorCurlHint,
    t.inspectorEmpty,
    t.inspectorCopiedUrl,
    t.inspectorMocksEnabled(2),
    t.inspectorThemeMode('dark'),
    t.inspectorNoCallsMatch('q'),
    t.inspectorCopiedHar(2),
    t.inspectorImportedSessionBanner(2),
    t.callDetailTitle,
    t.callDetailUnavailable,
    t.callDetailCompareWith,
    t.callDetailCompareTitle,
    t.callDetailNoOtherCalls,
    t.callDetailTabOverview,
    t.callDetailTabRequest,
    t.callDetailTabResponse,
    t.callDetailExportBody,
    t.callDetailExportCurl,
    t.callDetailExportDart,
    t.callDetailExportHar,
    t.callDetailMockThis,
    t.callDetailEditAndResend,
    t.callDetailReplay,
    t.callDetailReplaySent,
    t.callDetailReplayThisCall,
    t.callDetailEditAndResendThisCall,
    t.callDetailNoReplayer,
    t.callDetailNoReplayerHint,
    t.callDetailImportedNoResend,
    t.callDetailImportedNoReplay,
    t.fieldMethod,
    t.fieldUrl,
    t.fieldStatus,
    t.fieldDuration,
    t.fieldRequestSize,
    t.fieldResponseSize,
    t.fieldStartTime,
    t.fieldClient,
    t.fieldThrottledBy,
    t.fieldTransferred,
    t.sectionError,
    t.sectionHeaders,
    t.sectionQuery,
    t.sectionVariables,
    t.sectionBody,
    t.callDetailNoVariables,
    t.mocksTitle,
    t.mocksAddRule,
    t.mocksEmpty,
    t.mockEditorNewTitle,
    t.mockEditorEditTitle,
    t.mockEditorName,
    t.mockEditorMethod,
    t.mockEditorMethodAny,
    t.mockEditorUrlPattern,
    t.mockEditorBodyContains,
    t.mockEditorAction,
    t.mockEditorActionResponse,
    t.mockEditorActionFailure,
    t.mockEditorActionDelay,
    t.mockEditorStatusCode,
    t.mockEditorHeaders,
    t.mockEditorBody,
    t.mockEditorFailureKind,
    t.mockEditorDelayRequired,
    t.mockEditorDelayOptional,
    t.mockEditorMatches(2),
    t.composerTitle,
    t.composerSend,
    t.composerSent,
    t.composerInvalidUrl,
    t.composerMethod,
    t.composerUrl,
    t.composerHeaders,
    t.composerBody,
    t.throttleTitle,
    t.throttleOff,
    t.throttleOffSubtitle,
    t.throttleCustom,
    t.throttleCustomSubtitle,
    t.throttleHostPattern,
    t.throttleHostPatternHint,
    t.throttleLatency,
    t.throttleJitter,
    t.throttleDownload,
    t.throttleUpload,
    t.throttleApply,
    t.wsDetailTitle,
    t.wsDetailUnavailable,
    t.wsCopySummary,
    t.wsCopyFramePreview,
    t.wsFilterFramesHint,
    t.wsNoFramesCaptured,
    t.wsFieldUri,
    t.wsFieldOpened,
    t.wsFieldClosedAt,
    t.wsFieldCloseCode,
    t.wsFieldCloseReason,
    t.wsFieldFrames,
    t.wsNoFramesMatch('q'),
    t.wsFramesTruncated(10, 5),
    t.bodyEmpty,
    t.bodyViewTree,
    t.bodyViewPretty,
    t.bodyViewRaw,
    t.bodyMultipartNoParts,
    t.bodyPartName,
    t.bodyPartFilename,
    t.bodyPartContentType,
    t.bodyPartSize,
    t.jsonSearchHint,
    t.headersEmpty,
    t.headersSearchHint,
    t.headersNoMatch('q'),
    t.filterHelpTitle,
    t.filterHelpIntro,
    t.filterHelpStatus,
    t.filterHelpMethod,
    t.filterHelpHost,
    t.filterHelpPath,
    t.filterHelpType,
    t.filterHelpLargerThan,
    t.filterHelpSlowerThan,
    t.filterHelpIsReplay,
    t.filterHelpIsMocked,
    t.filterHelpOp,
    t.filterHelpIsGraphql,
    t.filterHelpIsSubscription,
    t.filterHelpIsWs,
    t.filterHelpBody,
    t.filterHelpBareText,
    t.filterHelpNegate,
  ];
}
