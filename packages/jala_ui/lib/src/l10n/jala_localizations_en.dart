import 'jala_localizations.dart';

/// English strings — the reference table.
///
/// Wording here is the source of truth for every other locale. Note that
/// `COMPAT.md` explicitly excludes snackbar/error wording from the
/// semver-covered surface, so these may be reworded in a patch.
class JalaLocalizationsEn extends JalaLocalizations {
  /// Creates the English table.
  const JalaLocalizationsEn();

  @override
  String get actionCancel => 'Cancel';
  @override
  String get actionClear => 'Clear';
  @override
  String get actionSave => 'Save';
  @override
  String get actionImport => 'Import';
  @override
  String get actionSend => 'Send';
  @override
  String get actionReplace => 'Replace';
  @override
  String get actionAppend => 'Append';
  @override
  String get tooltipCopyValue => 'Copy value';
  @override
  String get tooltipClearSearch => 'Clear search';
  @override
  String get tooltipExpandAll => 'Expand all';
  @override
  String get tooltipCollapseAll => 'Collapse all';
  @override
  String get labelEmptyValue => '(empty)';
  @override
  String get labelNoValue => '(no value)';
  @override
  String get labelNoMatches => 'No matches';

  @override
  String copied(String label) => 'Copied $label';

  @override
  String get inspectorTitle => 'Jala';
  @override
  String get inspectorClose => 'Close inspector';
  @override
  String get inspectorClearConfirmTitle => 'Clear all captured calls?';
  @override
  String get inspectorMocks => 'Mocks';
  @override
  String get inspectorComfortableList => 'Comfortable list';
  @override
  String get inspectorCompactList => 'Compact list';
  @override
  String get inspectorCopySessionAsHar => 'Copy session as HAR';
  @override
  String get inspectorSession => 'Session';
  @override
  String get inspectorExportSessionFull => 'Export session (full)';
  @override
  String get inspectorExportSessionNoBodies => 'Export session (no bodies)';
  @override
  String get inspectorExportSessionHeadersOnly =>
      'Export session (headers only)';
  @override
  String get inspectorImportSession => 'Import session';
  @override
  String get inspectorImportHarMenu => 'Import HAR…';
  @override
  String get inspectorImportCurlMenu => 'Import cURL…';
  @override
  String get inspectorImportHarTitle => 'Import HAR';
  @override
  String get inspectorImportCurlTitle => 'Import cURL';
  @override
  String get inspectorOpenInComposer => 'Open in composer';
  @override
  String get inspectorFilterHint => 'Filter: method:get  s:4xx  host:api.*';
  @override
  String get inspectorCurlHint => "curl 'https://…' -H '…' -d '…'";
  @override
  String get inspectorEmpty => 'No network calls captured yet.';
  @override
  String get inspectorCopiedUrl => 'Copied URL';

  @override
  String inspectorMocksEnabled(int count) => 'Mocks ($count enabled)';
  @override
  String inspectorThemeMode(String mode) => 'Theme: $mode';
  @override
  String inspectorNoCallsMatch(String query) => 'No calls match "$query".';
  @override
  String inspectorCopiedHar(int count) =>
      'Copied HAR for $count ${count == 1 ? 'call' : 'calls'}';
  @override
  String inspectorImportedSessionBanner(int count) =>
      'Imported session ($count ${count == 1 ? 'entry' : 'entries'}) — '
      'Clear to return to live capture';

  @override
  String get inspectorClearConfirmBody =>
      'This removes every entry from the inspector. This cannot be undone.';
  @override
  String get inspectorFilterGrammar => 'Filter grammar';
  @override
  String get inspectorThrottle => 'Throttle';
  @override
  String inspectorThrottlingActive(String name) => 'Throttling: $name';
  @override
  String inspectorThrottlingBanner(String name) =>
      'Throttling: $name — tap to change';

  @override
  String get importSessionHint => 'Paste exported session JSON here…';
  @override
  String get importSessionNote =>
      'Treat pasted JSON like a log dump — it may contain personal or '
      'business data.';
  @override
  String get importHarHint => 'Paste HAR 1.2 JSON here…';
  @override
  String get importHarNote =>
      'Imports a HAR export (browser devtools, Charles, Proxyman, …) as a '
      'session. Imported calls have replay disabled.';
  @override
  String get importCurlHint => "curl 'https://…' -H '…' -d '…'";
  @override
  String get importCurlNote =>
      'Paste a curl command (e.g. copied from browser devtools). It opens '
      'in the request composer.';
  @override
  String get importNothingPasted => 'Paste something to import';
  @override
  String importSessionMaxSize(int mib) => 'Max size $mib MiB.';

  @override
  String exportFailed(String size, String destination) =>
      'Export failed ($size → $destination). Too large for the clipboard? '
      'Use Jala.enableFileExport() to write exports to a file instead.';
  @override
  String get exportClipboardRisk =>
      'That is large for a clipboard; if the paste comes out empty or '
      'truncated, use Jala.enableFileExport().';
  @override
  String get exportPersonalDataWarning =>
      'May contain personal data; share carefully.';
  @override
  String exportedSession(String mode, int count) =>
      'Exported session ($mode) — $count ${count == 1 ? 'entry' : 'entries'}';
  @override
  String exportedHar(int count) =>
      'Exported HAR for $count ${count == 1 ? 'call' : 'calls'}';
  @override
  String exportDelivered(String size, String destination) =>
      ' — $size → $destination.';

  @override
  String get callDetailTitle => 'Call detail';
  @override
  String get callDetailUnavailable => 'This call is no longer available.';
  @override
  String get callDetailCompareWith => 'Compare with…';
  @override
  String get callDetailCompareTitle => 'Compare calls';
  @override
  String get callDetailNoOtherCalls => 'No other calls to compare with';
  @override
  String get callDetailTabOverview => 'Overview';
  @override
  String get callDetailTabRequest => 'Request';
  @override
  String get callDetailTabResponse => 'Response';
  @override
  String get callDetailExportBody => 'Body';
  @override
  String get callDetailExportCurl => 'cURL';
  @override
  String get callDetailExportDart => 'Dart';
  @override
  String get callDetailExportHar => 'HAR';
  @override
  String get callDetailMockThis => 'Mock this';
  @override
  String get callDetailEditAndResend => 'Edit & resend';
  @override
  String get callDetailReplay => 'Replay';
  @override
  String get callDetailReplaySent => 'Replay sent';
  @override
  String get callDetailReplayThisCall => 'Replay this call';
  @override
  String get callDetailEditAndResendThisCall => 'Edit and resend this call';
  @override
  String get callDetailNoReplayer => 'No replayer attached';
  @override
  String get callDetailNoReplayerHint =>
      'No replayer attached — use JalaDio.attach(dio)';
  @override
  String get callDetailImportedNoMock =>
      "Imported entries can't be mocked from";
  @override
  String get callDetailImportedNoResend =>
      "Imported entries can't be edited & resent";
  @override
  String get callDetailImportedNoReplay => "Imported entries can't be replayed";
  @override
  String get callDetailPending => 'Pending…';
  @override
  String get callDetailCancelled => 'Cancelled';
  @override
  String get callDetailBinaryBody => '(binary)';
  @override
  String get callDetailPrefillMock => 'Prefill a mock rule from this call';
  @override
  String get callDetailReplayOf => 'Replay of';
  @override
  String callDetailErrorStatus(int? statusCode) =>
      statusCode == null ? 'Error' : 'Error ($statusCode)';
  @override
  String callDetailTransferred(String sent, String received) =>
      'Sent $sent · Received $received';
  @override
  String get sectionGrpcStatus => 'gRPC status';
  @override
  String get diffRequestHeaders => 'Request headers';
  @override
  String get diffResponseHeaders => 'Response headers';
  @override
  String get diffRequestBody => 'Request body';
  @override
  String get diffResponseBody => 'Response body';
  @override
  String get diffNotStructural =>
      'Not a structural diff — one or both bodies are not JSON.';
  @override
  String get tooltipMocked => 'Mocked';

  @override
  String get mockEditorUntitled => 'Untitled rule';
  @override
  String throttleDropRate(int percent) => 'Drop rate: $percent%';
  @override
  String throttleMidStreamDropRate(int percent) =>
      'Drop mid-download: $percent%';
  @override
  String get throttleMidStreamDropHelp =>
      'Kills connections that already established, partway through the '
      'response. Long transfers die; short ones complete.';
  @override
  String get throttleScopeAdapter =>
      'Covers attached clients only — Image.network and unattached clients '
      'are unaffected.';
  @override
  String get throttleScopeSocket =>
      'Covers all dart:io traffic, including Image.network.';
  @override
  String get bodyStreamOnly => 'Stream — metadata only, body not captured';
  @override
  String bodyBinaryOnly(String size) =>
      'Binary — $size bytes captured (metadata only)';
  @override
  String bodyTruncated(int shown, String size) =>
      'Truncated — $shown chars shown of $size bytes captured';
  @override
  String get wsFieldStatus => 'Status';
  @override
  String get wsStatusConnecting => 'Connecting…';
  @override
  String get wsStatusOpen => 'Open';
  @override
  String get wsStatusClosed => 'Closed';
  @override
  String get wsStatusError => 'Error';
  @override
  String get wsFramePreviewTitle => 'Frame preview';
  @override
  String headersHideCommon(int count) => 'Hide $count common headers';
  @override
  String headersShowCommon(int count) =>
      'Show $count common headers (date, server, …)';
  @override
  String get headersHideSensitive => 'Hide sensitive headers';
  @override
  String headersShowSensitive(int count) =>
      'Show $count sensitive (cookie, authorization, …)';
  @override
  String tooltipThrottledBy(String profile) => 'Throttled by $profile';
  @override
  String sectionTrailers(int count) => 'Trailers ($count)';
  @override
  String get callDetailStreamingNoMessages =>
      'Response messages are not captured for streaming RPCs. The gRPC '
      'interceptor cannot read them without taking the subscription your '
      'app needs — the call itself, its status and its trailers are '
      'recorded above.';
  @override
  String sectionQueryParams(int count) => 'Query parameters ($count)';
  @override
  String get sectionSubscriptionPayloads => 'Subscription payloads';
  @override
  String callDetailPayloadsTruncated(int shown, int total) =>
      'Showing last $shown of $total payloads';
  @override
  String get fieldMethod => 'Method';
  @override
  String get fieldPath => 'Path';
  @override
  String get fieldUrl => 'URL';
  @override
  String get fieldStatus => 'Status';
  @override
  String get fieldDuration => 'Duration';
  @override
  String get fieldRequestSize => 'Request size';
  @override
  String get fieldResponseSize => 'Response size';
  @override
  String get fieldStartTime => 'Start time';
  @override
  String get fieldClient => 'Client';
  @override
  String get fieldThrottledBy => 'Throttled by';
  @override
  String get fieldTransferred => 'Transferred';
  @override
  String get sectionError => 'Error';
  @override
  String get sectionHeaders => 'Headers';
  @override
  String get sectionQuery => 'Query';
  @override
  String get sectionVariables => 'Variables';
  @override
  String get sectionBody => 'Body';
  @override
  String get callDetailNoVariables => 'No variables';

  @override
  String get mocksTitle => 'Mocks';
  @override
  String get mocksAddRule => 'Add mock rule';
  @override
  String get mocksEmpty =>
      'No mock rules yet.\n'
      'Add one, or use “Mock this” on a captured call.';
  @override
  String get mockEditorNewTitle => 'New mock';
  @override
  String get mockEditorEditTitle => 'Edit mock';
  @override
  String get mockEditorName => 'Name';
  @override
  String get mockEditorMethod => 'Method';
  @override
  String get mockEditorMethodAny => 'ANY';
  @override
  String get mockEditorUrlPattern => 'URL pattern (glob, * wildcards)';
  @override
  String get mockEditorBodyContains => 'Body contains (optional)';
  @override
  String get mockEditorAction => 'Action';
  @override
  String get mockEditorActionResponse => 'Response';
  @override
  String get mockEditorActionFailure => 'Failure';
  @override
  String get mockEditorActionDelay => 'Delay';
  @override
  String get mockEditorStatusCode => 'Status code';
  @override
  String get mockEditorHeaders => 'Headers (Name: value per line)';
  @override
  String get mockEditorBody => 'Body';
  @override
  String get mockEditorFailureKind => 'Failure kind';
  @override
  String get mockEditorDelayRequired => 'Delay (ms, required)';
  @override
  String get mockEditorDelayOptional => 'Delay (ms, optional)';

  @override
  String mockEditorMatches(int count) =>
      'Matches $count captured call${count == 1 ? '' : 's'}';

  @override
  String get composerTitle => 'Edit & resend';
  @override
  String get composerSend => 'Send';
  @override
  String get composerSent => 'Request sent';
  @override
  String get composerInvalidUrl => 'Enter a valid absolute URL';
  @override
  String get composerMethod => 'Method';
  @override
  String get composerUrl => 'URL';
  @override
  String get composerHeaders => 'Headers (Name: value per line)';
  @override
  String get composerBody => 'Body';

  @override
  String get throttleTitle => 'Throttle';
  @override
  String get throttleOff => 'Off';
  @override
  String get throttleOffSubtitle => 'No simulated network conditions';
  @override
  String get throttleCustom => 'Custom';
  @override
  String get throttleCustomSubtitle => 'Configure your own profile below';
  @override
  String get throttleHostPattern => 'Host pattern (glob, optional)';
  @override
  String get throttleHostPatternHint =>
      '*.example.com — empty applies to all hosts';
  @override
  String get throttleLatency => 'Latency (ms)';
  @override
  String get throttleJitter => 'Jitter ± (ms, optional)';
  @override
  String get throttleDownload => 'Download KB/s (optional, unlimited if blank)';
  @override
  String get throttleUpload => 'Upload KB/s (optional, unlimited if blank)';
  @override
  String get throttleApply => 'Apply custom profile';

  @override
  String get wsDetailTitle => 'WebSocket detail';
  @override
  String get wsDetailUnavailable => 'This connection is no longer available.';
  @override
  String get wsCopySummary => 'Copy connection summary';
  @override
  String get wsCopyFramePreview => 'Copy frame preview';
  @override
  String get wsFilterFramesHint => 'Filter frames…';
  @override
  String get wsNoFramesCaptured => 'No frames captured yet.';
  @override
  String get wsFieldUri => 'URI';
  @override
  String get wsFieldOpened => 'Opened';
  @override
  String get wsFieldClosedAt => 'Closed at';
  @override
  String get wsFieldCloseCode => 'Close code';
  @override
  String get wsFieldCloseReason => 'Close reason';
  @override
  String get wsFieldFrames => 'Frames';

  @override
  String wsNoFramesMatch(String query) => 'No frames match "$query".';
  @override
  String wsFramesTruncated(int total, int shown) =>
      '$total (showing last $shown)';

  @override
  String get bodyEmpty => 'empty';
  @override
  String get bodyViewTree => 'Tree';
  @override
  String get bodyViewPretty => 'Pretty';
  @override
  String get bodyViewRaw => 'Raw';
  @override
  String get bodyMultipartNoParts => 'Multipart body with no parts';
  @override
  String get bodyPartName => 'Name';
  @override
  String get bodyPartFilename => 'Filename';
  @override
  String get bodyPartContentType => 'Content-Type';
  @override
  String get bodyPartSize => 'Size';
  @override
  String get jsonSearchHint => 'Search in JSON…';

  @override
  String get headersEmpty => 'No headers';
  @override
  String get headersSearchHint => 'Search headers…';

  @override
  String headersNoMatch(String query) => 'No headers match "$query"';

  @override
  String get filterHelpTitle => 'Filter grammar';
  @override
  String get filterHelpIntro =>
      'Space-separated terms are ANDed together. All matching is '
      'case-insensitive.';
  @override
  String get filterHelpStatus =>
      'exact code (status:404), class (status:4xx), s:error, s:pending';
  @override
  String get filterHelpMethod => 'HTTP method; comma list allowed (m:get,post)';
  @override
  String get filterHelpHost =>
      'host match; * wildcard allowed (host:*.example.com)';
  @override
  String get filterHelpPath => 'substring of the URL path';
  @override
  String get filterHelpType => 'substring of the response content-type';
  @override
  String get filterHelpLargerThan =>
      'responseSize > n bytes (k/m suffixes, e.g. 10k, 2m)';
  @override
  String get filterHelpSlowerThan => 'duration > n milliseconds';
  @override
  String get filterHelpIsReplay => 'the call is a replay of another entry';
  @override
  String get filterHelpIsMocked => 'the call was handled by a mock rule';
  @override
  String get filterHelpOp =>
      'GraphQL operationName match; * wildcard allowed (op:Get*)';
  @override
  String get filterHelpIsGraphql =>
      'the call carries GraphQL operation metadata';
  @override
  String get filterHelpIsSubscription =>
      'the call is a GraphQL subscription operation';
  @override
  String get filterHelpIsWs => 'WebSocket connection entries (merged list only)';
  @override
  String get filterHelpBody =>
      'substring in captured request or response body';
  @override
  String get filterHelpBareText => 'substring of method + full URL';
  @override
  String get filterHelpNegate => 'prefix any term with - to negate it';
}
