import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'jala_localizations_en.dart';
import 'jala_localizations_id.dart';

/// Localized strings for the Jala inspector UI.
///
/// Jala ships its own table-based localizations rather than generated
/// ARB/`gen-l10n` output, so that adding a translation never forces an
/// `intl` version constraint onto the host app. See
/// `docs/plans/track-h-v0.8.1-l10n.md`.
///
/// The class is abstract with no default implementations on purpose: a
/// locale that forgets a string fails to compile rather than silently
/// falling back at runtime.
///
/// Resolution is **opt-in**. The inspector renders English unless the host
/// sets a locale — the device locale is deliberately not consulted.
abstract class JalaLocalizations {
  /// Creates a localization table.
  const JalaLocalizations();

  /// The English table, used whenever no better match is available.
  static const JalaLocalizations fallback = JalaLocalizationsEn();

  /// Locales Jala ships strings for.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// Delegate to install in a [Localizations] widget.
  static const LocalizationsDelegate<JalaLocalizations> delegate =
      _JalaLocalizationsDelegate();

  /// The table for [locale], falling back to English for anything
  /// unsupported. Matches on language code only — `id-ID` and `id` both
  /// resolve to the Indonesian table.
  static JalaLocalizations forLocale(Locale locale) {
    return switch (locale.languageCode) {
      'id' => const JalaLocalizationsId(),
      _ => fallback,
    };
  }

  /// The table for a BCP-47 language tag such as `id-ID`.
  ///
  /// [JalaConfig] stores the locale as a `String` because `jala_core` is
  /// pure Dart and may not import `dart:ui`. A null, empty or unparseable
  /// tag resolves to English.
  static JalaLocalizations forLanguageTag(String? tag) {
    if (tag == null || tag.isEmpty) return fallback;
    final String code = tag.split(RegExp('[-_]')).first.toLowerCase();
    return forLocale(Locale(code));
  }

  /// The nearest table, or English when no delegate is installed.
  ///
  /// Never returns null and never throws: `jala_ui` widgets are exported
  /// individually and a host may mount one anywhere, so a missing delegate
  /// must degrade to English rather than crash someone else's app.
  static JalaLocalizations of(BuildContext context) {
    return Localizations.of<JalaLocalizations>(context, JalaLocalizations) ??
        fallback;
  }

  // ---------------------------------------------------------------- common

  String get actionCancel;
  String get actionClear;
  String get actionSave;
  String get actionImport;
  String get actionSend;
  String get actionReplace;
  String get actionAppend;
  String get tooltipCopyValue;
  String get tooltipClearSearch;
  String get tooltipExpandAll;
  String get tooltipCollapseAll;
  String get labelEmptyValue;
  String get labelNoValue;
  String get labelNoMatches;

  /// Snackbar shown after copying [label] to the clipboard.
  String copied(String label);

  // ------------------------------------------------------------- inspector

  String get inspectorTitle;
  String get inspectorClose;
  String get inspectorClearConfirmTitle;
  String get inspectorMocks;
  String get inspectorComfortableList;
  String get inspectorCompactList;
  String get inspectorCopySessionAsHar;
  String get inspectorSession;
  String get inspectorExportSessionFull;
  String get inspectorExportSessionNoBodies;
  String get inspectorExportSessionHeadersOnly;
  String get inspectorImportSession;
  String get inspectorImportHarMenu;
  String get inspectorImportCurlMenu;
  String get inspectorImportHarTitle;
  String get inspectorImportCurlTitle;
  String get inspectorOpenInComposer;
  String get inspectorFilterHint;
  String get inspectorCurlHint;
  String get inspectorEmpty;
  String get inspectorCopiedUrl;

  /// Overflow tooltip when [count] mock rules are enabled.
  String inspectorMocksEnabled(int count);

  /// Theme toggle tooltip; [mode] is the current mode's name.
  String inspectorThemeMode(String mode);

  /// Empty state when the filter [query] matches nothing.
  String inspectorNoCallsMatch(String query);

  /// Snackbar after copying the session as HAR.
  String inspectorCopiedHar(int count);

  /// Banner shown while an imported session is on screen.
  String inspectorImportedSessionBanner(int count);

  /// Body of the "clear all captured calls?" confirmation.
  String get inspectorClearConfirmBody;

  /// Tooltip on the filter-grammar help button.
  String get inspectorFilterGrammar;

  /// Throttle button tooltip when no profile is active.
  String get inspectorThrottle;

  /// Throttle button tooltip while [name] is active.
  String inspectorThrottlingActive(String name);

  /// Throttle banner text while [name] is active.
  String inspectorThrottlingBanner(String name);

  // Import dialogs. The dialog *title* strings live above with the menu
  // items they are opened from.

  String get importSessionHint;
  String get importSessionNote;
  String get importHarHint;
  String get importHarNote;
  String get importCurlHint;
  String get importCurlNote;
  String get importNothingPasted;

  /// Max paste size, in MiB, quoted in [importSessionNote].
  String importSessionMaxSize(int mib);

  // Export outcome reporting. `destination` and `size` are formatted by the
  // sink and are not themselves translated (they are paths and byte counts).

  /// Snackbar when an export could not be delivered.
  String exportFailed(String size, String destination);

  /// Appended when a successful export is large enough that the clipboard
  /// may have silently dropped it.
  String get exportClipboardRisk;

  /// Trailing warning on a session export.
  String get exportPersonalDataWarning;

  /// Successful session export of [count] entries in [mode].
  String exportedSession(String mode, int count);

  /// Successful HAR export of [count] calls.
  String exportedHar(int count);

  /// The `— <size> → <destination>.` tail shared by every export snackbar.
  String exportDelivered(String size, String destination);

  // ----------------------------------------------------------- call detail

  String get callDetailTitle;
  String get callDetailUnavailable;
  String get callDetailCompareWith;
  String get callDetailCompareTitle;
  String get callDetailNoOtherCalls;
  String get callDetailTabOverview;
  String get callDetailTabRequest;
  String get callDetailTabResponse;
  String get callDetailExportBody;
  String get callDetailExportCurl;
  String get callDetailExportDart;
  String get callDetailExportHar;
  String get callDetailMockThis;
  String get callDetailEditAndResend;
  String get callDetailReplay;
  String get callDetailReplaySent;
  String get callDetailReplayThisCall;
  String get callDetailEditAndResendThisCall;
  String get callDetailNoReplayer;
  String get callDetailNoReplayerHint;
  String get callDetailImportedNoResend;
  String get callDetailImportedNoReplay;
  String get callDetailPending;
  String get callDetailCancelled;
  String get callDetailBinaryBody;
  String get callDetailPrefillMock;
  String get callDetailReplayOf;

  /// Status line for a failed call; [statusCode] is null when the call never
  /// got one (connection error, timeout).
  String callDetailErrorStatus(int? statusCode);

  /// Byte counters for an in-flight or finished transfer. [sent] and
  /// [received] are already formatted (`1.2 MB`) — byte formatting stays
  /// unlocalized, see the plan.
  String callDetailTransferred(String sent, String received);

  // gRPC (Track G). The status *name* (`NOT_FOUND`) and the numeric code are
  // wire vocabulary and stay English — only the surrounding labels move.

  String get sectionGrpcStatus;

  /// Section header for gRPC trailers, with the count.
  String sectionTrailers(int count);

  /// Why a streaming RPC has no response body. This is the longest string in
  /// the UI and the one most likely to overflow — check it on a device.
  String get callDetailStreamingNoMessages;

  // Query params + subscription payloads.

  /// Section header for the decoded query-parameter table, with the count.
  String sectionQueryParams(int count);

  String get sectionSubscriptionPayloads;

  /// Shown when the payload ring buffer has evicted older entries.
  String callDetailPayloadsTruncated(int shown, int total);
  String get fieldMethod;
  String get fieldPath;
  String get fieldUrl;
  String get fieldStatus;
  String get fieldDuration;
  String get fieldRequestSize;
  String get fieldResponseSize;
  String get fieldStartTime;
  String get fieldClient;
  String get fieldThrottledBy;
  String get fieldTransferred;
  String get sectionError;
  String get sectionHeaders;
  String get sectionQuery;
  String get sectionVariables;
  String get sectionBody;
  String get callDetailNoVariables;

  // ---------------------------------------------------------------- mocks

  String get mocksTitle;
  String get mocksAddRule;
  String get mocksEmpty;
  String get mockEditorNewTitle;
  String get mockEditorEditTitle;
  String get mockEditorName;
  String get mockEditorMethod;
  String get mockEditorMethodAny;
  String get mockEditorUrlPattern;
  String get mockEditorBodyContains;
  String get mockEditorAction;
  String get mockEditorActionResponse;
  String get mockEditorActionFailure;
  String get mockEditorActionDelay;
  String get mockEditorStatusCode;
  String get mockEditorHeaders;
  String get mockEditorBody;
  String get mockEditorFailureKind;
  String get mockEditorDelayRequired;
  String get mockEditorDelayOptional;

  /// Live count of captured calls a draft rule would match.
  String mockEditorMatches(int count);

  // ------------------------------------------------------------- composer

  String get composerTitle;
  String get composerSend;
  String get composerSent;
  String get composerInvalidUrl;
  String get composerMethod;
  String get composerUrl;
  String get composerHeaders;
  String get composerBody;

  // ------------------------------------------------------------- throttle

  String get throttleTitle;
  String get throttleOff;
  String get throttleOffSubtitle;
  String get throttleCustom;
  String get throttleCustomSubtitle;
  String get throttleHostPattern;
  String get throttleHostPatternHint;
  String get throttleLatency;
  String get throttleJitter;
  String get throttleDownload;
  String get throttleUpload;
  String get throttleApply;

  // ------------------------------------------------------------ websocket

  String get wsDetailTitle;
  String get wsDetailUnavailable;
  String get wsCopySummary;
  String get wsCopyFramePreview;
  String get wsFilterFramesHint;
  String get wsNoFramesCaptured;
  String get wsFieldUri;
  String get wsFieldOpened;
  String get wsFieldClosedAt;
  String get wsFieldCloseCode;
  String get wsFieldCloseReason;
  String get wsFieldFrames;

  /// Empty state when the frame filter [query] matches nothing.
  String wsNoFramesMatch(String query);

  /// Frame counter when only the last [shown] of [total] are retained.
  String wsFramesTruncated(int total, int shown);

  // ------------------------------------------------------------ body view

  String get bodyEmpty;
  String get bodyViewTree;
  String get bodyViewPretty;
  String get bodyViewRaw;
  String get bodyMultipartNoParts;
  String get bodyPartName;
  String get bodyPartFilename;
  String get bodyPartContentType;
  String get bodyPartSize;
  String get jsonSearchHint;

  // ---------------------------------------------------------------- headers

  String get headersEmpty;
  String get headersSearchHint;

  /// Empty state when the header search [query] matches nothing.
  String headersNoMatch(String query);

  // ----------------------------------------------------------- filter help

  String get filterHelpTitle;
  String get filterHelpIntro;
  String get filterHelpStatus;
  String get filterHelpMethod;
  String get filterHelpHost;
  String get filterHelpPath;
  String get filterHelpType;
  String get filterHelpLargerThan;
  String get filterHelpSlowerThan;
  String get filterHelpIsReplay;
  String get filterHelpIsMocked;
  String get filterHelpOp;
  String get filterHelpIsGraphql;
  String get filterHelpIsSubscription;
  String get filterHelpIsWs;
  String get filterHelpBody;
  String get filterHelpBareText;
  String get filterHelpNegate;
}

class _JalaLocalizationsDelegate
    extends LocalizationsDelegate<JalaLocalizations> {
  const _JalaLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return JalaLocalizations.supportedLocales.any(
      (Locale l) => l.languageCode == locale.languageCode,
    );
  }

  @override
  Future<JalaLocalizations> load(Locale locale) {
    return SynchronousFuture<JalaLocalizations>(
      JalaLocalizations.forLocale(locale),
    );
  }

  @override
  bool shouldReload(_JalaLocalizationsDelegate old) => false;
}
