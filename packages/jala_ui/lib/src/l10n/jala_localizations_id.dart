import 'jala_localizations.dart';

/// Indonesian (id) strings.
///
/// Translation rule for this table (Track H, decision 2026-08-05): **keep
/// the common language.** Developer vocabulary that Indonesian Flutter
/// developers already speak in English stays in English — `request`,
/// `response`, `header`, `body`, `payload`, `replay`, `mock`, `session`,
/// `status`, `frame`, `throttle`. Rendering those as `permintaan` /
/// `tanggapan` / `muatan` reads as machine-translated to the audience this
/// locale exists for.
///
/// What *is* translated: the connective prose around that vocabulary —
/// empty states, action verbs, confirmations, error sentences, help text.
/// Test for a borderline word: would an Indonesian Flutter developer say it
/// in English in a standup? If yes, leave it.
///
/// Also untranslated by design (see `docs/plans/track-h-v0.8.1-l10n.md`):
/// the filter DSL terms themselves, HTTP method names, and header names.
class JalaLocalizationsId extends JalaLocalizations {
  /// Creates the Indonesian table.
  const JalaLocalizationsId();

  @override
  String get actionCancel => 'Batal';
  @override
  String get actionClear => 'Bersihkan';
  @override
  String get actionSave => 'Simpan';
  @override
  String get actionImport => 'Impor';
  @override
  String get actionSend => 'Kirim';
  @override
  String get actionReplace => 'Ganti';
  @override
  String get actionAppend => 'Tambahkan';
  @override
  String get tooltipCopyValue => 'Salin nilai';
  @override
  String get tooltipClearSearch => 'Bersihkan pencarian';
  @override
  String get tooltipExpandAll => 'Buka semua';
  @override
  String get tooltipCollapseAll => 'Tutup semua';
  @override
  String get labelEmptyValue => '(kosong)';
  @override
  String get labelNoValue => '(tanpa nilai)';
  @override
  String get labelNoMatches => 'Tidak ada hasil';

  @override
  String copied(String label) => '$label disalin';

  @override
  String get inspectorTitle => 'Jala';
  @override
  String get inspectorClose => 'Tutup inspector';
  @override
  String get inspectorClearConfirmTitle =>
      'Bersihkan semua call yang tertangkap?';
  @override
  String get inspectorMocks => 'Mocks';
  @override
  String get inspectorComfortableList => 'List longgar';
  @override
  String get inspectorCompactList => 'List ringkas';
  @override
  String get inspectorCopySessionAsHar => 'Salin session sebagai HAR';
  @override
  String get inspectorSession => 'Session';
  @override
  String get inspectorExportSessionFull => 'Ekspor session (lengkap)';
  @override
  String get inspectorExportSessionNoBodies => 'Ekspor session (tanpa body)';
  @override
  String get inspectorExportSessionHeadersOnly =>
      'Ekspor session (header saja)';
  @override
  String get inspectorImportSession => 'Impor session';
  @override
  String get inspectorImportHarMenu => 'Impor HAR…';
  @override
  String get inspectorImportCurlMenu => 'Impor cURL…';
  @override
  String get inspectorImportHarTitle => 'Impor HAR';
  @override
  String get inspectorImportCurlTitle => 'Impor cURL';
  @override
  String get inspectorOpenInComposer => 'Buka di composer';
  @override
  String get inspectorFilterHint => 'Filter: method:get  s:4xx  host:api.*';
  @override
  String get inspectorCurlHint => "curl 'https://…' -H '…' -d '…'";
  @override
  String get inspectorEmpty => 'Belum ada network call yang tertangkap.';
  @override
  String get inspectorCopiedUrl => 'URL disalin';

  @override
  String inspectorMocksEnabled(int count) => 'Mocks ($count aktif)';
  @override
  String inspectorThemeMode(String mode) => 'Tema: $mode';
  @override
  String inspectorNoCallsMatch(String query) =>
      'Tidak ada call yang cocok dengan "$query".';
  @override
  String inspectorCopiedHar(int count) => 'HAR disalin untuk $count call';
  @override
  String inspectorImportedSessionBanner(int count) =>
      'Session hasil impor ($count entry) — Bersihkan untuk kembali ke '
      'live capture';

  @override
  String get callDetailTitle => 'Detail call';
  @override
  String get callDetailUnavailable => 'Call ini sudah tidak tersedia.';
  @override
  String get callDetailCompareWith => 'Bandingkan dengan…';
  @override
  String get callDetailCompareTitle => 'Bandingkan call';
  @override
  String get callDetailNoOtherCalls =>
      'Tidak ada call lain untuk dibandingkan';
  @override
  String get callDetailTabOverview => 'Ringkasan';
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
  String get callDetailMockThis => 'Mock ini';
  @override
  String get callDetailEditAndResend => 'Edit & kirim ulang';
  @override
  String get callDetailReplay => 'Replay';
  @override
  String get callDetailReplaySent => 'Replay terkirim';
  @override
  String get callDetailReplayThisCall => 'Replay call ini';
  @override
  String get callDetailEditAndResendThisCall =>
      'Edit dan kirim ulang call ini';
  @override
  String get callDetailNoReplayer => 'Tidak ada replayer terpasang';
  @override
  String get callDetailNoReplayerHint =>
      'Tidak ada replayer terpasang — gunakan JalaDio.attach(dio)';
  @override
  String get callDetailImportedNoResend =>
      'Entry hasil impor tidak bisa di-edit & dikirim ulang';
  @override
  String get callDetailImportedNoReplay =>
      'Entry hasil impor tidak bisa di-replay';
  @override
  String get fieldMethod => 'Method';
  @override
  String get fieldUrl => 'URL';
  @override
  String get fieldStatus => 'Status';
  @override
  String get fieldDuration => 'Durasi';
  @override
  String get fieldRequestSize => 'Ukuran request';
  @override
  String get fieldResponseSize => 'Ukuran response';
  @override
  String get fieldStartTime => 'Waktu mulai';
  @override
  String get fieldClient => 'Client';
  @override
  String get fieldThrottledBy => 'Di-throttle oleh';
  @override
  String get fieldTransferred => 'Ditransfer';
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
  String get callDetailNoVariables => 'Tidak ada variables';

  @override
  String get mocksTitle => 'Mocks';
  @override
  String get mocksAddRule => 'Tambah mock rule';
  @override
  String get mocksEmpty =>
      'Belum ada mock rule.\n'
      'Tambahkan satu, atau gunakan “Mock ini” pada call yang tertangkap.';
  @override
  String get mockEditorNewTitle => 'Mock baru';
  @override
  String get mockEditorEditTitle => 'Edit mock';
  @override
  String get mockEditorName => 'Nama';
  @override
  String get mockEditorMethod => 'Method';
  @override
  String get mockEditorMethodAny => 'ANY';
  @override
  String get mockEditorUrlPattern => 'Pola URL (glob, wildcard *)';
  @override
  String get mockEditorBodyContains => 'Body mengandung (opsional)';
  @override
  String get mockEditorAction => 'Aksi';
  @override
  String get mockEditorActionResponse => 'Response';
  @override
  String get mockEditorActionFailure => 'Failure';
  @override
  String get mockEditorActionDelay => 'Delay';
  @override
  String get mockEditorStatusCode => 'Status code';
  @override
  String get mockEditorHeaders => 'Headers (Name: value per baris)';
  @override
  String get mockEditorBody => 'Body';
  @override
  String get mockEditorFailureKind => 'Jenis failure';
  @override
  String get mockEditorDelayRequired => 'Delay (ms, wajib)';
  @override
  String get mockEditorDelayOptional => 'Delay (ms, opsional)';

  @override
  String mockEditorMatches(int count) => 'Cocok dengan $count call tertangkap';

  @override
  String get composerTitle => 'Edit & kirim ulang';
  @override
  String get composerSend => 'Kirim';
  @override
  String get composerSent => 'Request terkirim';
  @override
  String get composerInvalidUrl => 'Masukkan URL absolut yang valid';
  @override
  String get composerMethod => 'Method';
  @override
  String get composerUrl => 'URL';
  @override
  String get composerHeaders => 'Headers (Name: value per baris)';
  @override
  String get composerBody => 'Body';

  @override
  String get throttleTitle => 'Throttle';
  @override
  String get throttleOff => 'Mati';
  @override
  String get throttleOffSubtitle => 'Tanpa simulasi kondisi jaringan';
  @override
  String get throttleCustom => 'Kustom';
  @override
  String get throttleCustomSubtitle => 'Atur profil Anda sendiri di bawah';
  @override
  String get throttleHostPattern => 'Pola host (glob, opsional)';
  @override
  String get throttleHostPatternHint =>
      '*.example.com — kosong berlaku untuk semua host';
  @override
  String get throttleLatency => 'Latency (ms)';
  @override
  String get throttleJitter => 'Jitter ± (ms, opsional)';
  @override
  String get throttleDownload =>
      'Download KB/s (opsional, tanpa batas jika kosong)';
  @override
  String get throttleUpload =>
      'Upload KB/s (opsional, tanpa batas jika kosong)';
  @override
  String get throttleApply => 'Terapkan profil kustom';

  @override
  String get wsDetailTitle => 'Detail WebSocket';
  @override
  String get wsDetailUnavailable => 'Koneksi ini sudah tidak tersedia.';
  @override
  String get wsCopySummary => 'Salin ringkasan koneksi';
  @override
  String get wsCopyFramePreview => 'Salin preview frame';
  @override
  String get wsFilterFramesHint => 'Filter frame…';
  @override
  String get wsNoFramesCaptured => 'Belum ada frame yang tertangkap.';
  @override
  String get wsFieldUri => 'URI';
  @override
  String get wsFieldOpened => 'Dibuka';
  @override
  String get wsFieldClosedAt => 'Ditutup pada';
  @override
  String get wsFieldCloseCode => 'Close code';
  @override
  String get wsFieldCloseReason => 'Alasan penutupan';
  @override
  String get wsFieldFrames => 'Frames';

  @override
  String wsNoFramesMatch(String query) =>
      'Tidak ada frame yang cocok dengan "$query".';
  @override
  String wsFramesTruncated(int total, int shown) =>
      '$total (menampilkan $shown terakhir)';

  @override
  String get bodyEmpty => 'kosong';
  @override
  String get bodyViewTree => 'Tree';
  @override
  String get bodyViewPretty => 'Pretty';
  @override
  String get bodyViewRaw => 'Raw';
  @override
  String get bodyMultipartNoParts => 'Body multipart tanpa part';
  @override
  String get bodyPartName => 'Nama';
  @override
  String get bodyPartFilename => 'Nama file';
  @override
  String get bodyPartContentType => 'Content-Type';
  @override
  String get bodyPartSize => 'Ukuran';
  @override
  String get jsonSearchHint => 'Cari di JSON…';

  @override
  String get headersEmpty => 'Tidak ada header';
  @override
  String get headersSearchHint => 'Cari header…';

  @override
  String headersNoMatch(String query) =>
      'Tidak ada header yang cocok dengan "$query"';

  @override
  String get filterHelpTitle => 'Sintaks filter';
  @override
  String get filterHelpIntro =>
      'Term yang dipisah spasi digabung dengan AND. Semua pencocokan tidak '
      'membedakan huruf besar/kecil.';
  @override
  String get filterHelpStatus =>
      'kode persis (status:404), kelas (status:4xx), s:error, s:pending';
  @override
  String get filterHelpMethod =>
      'HTTP method; boleh daftar dipisah koma (m:get,post)';
  @override
  String get filterHelpHost =>
      'cocokkan host; wildcard * diperbolehkan (host:*.example.com)';
  @override
  String get filterHelpPath => 'potongan dari path URL';
  @override
  String get filterHelpType => 'potongan dari content-type response';
  @override
  String get filterHelpLargerThan =>
      'responseSize > n byte (akhiran k/m, mis. 10k, 2m)';
  @override
  String get filterHelpSlowerThan => 'durasi > n milidetik';
  @override
  String get filterHelpIsReplay => 'call ini adalah replay dari entry lain';
  @override
  String get filterHelpIsMocked => 'call ini ditangani oleh mock rule';
  @override
  String get filterHelpOp =>
      'cocokkan operationName GraphQL; wildcard * diperbolehkan (op:Get*)';
  @override
  String get filterHelpIsGraphql => 'call ini membawa metadata operasi GraphQL';
  @override
  String get filterHelpIsSubscription =>
      'call ini adalah operasi subscription GraphQL';
  @override
  String get filterHelpIsWs =>
      'entry koneksi WebSocket (hanya pada list gabungan)';
  @override
  String get filterHelpBody =>
      'potongan teks di body request atau response yang tertangkap';
  @override
  String get filterHelpBareText => 'potongan dari method + URL lengkap';
  @override
  String get filterHelpNegate =>
      'awali term apa pun dengan - untuk menegasikannya';
}
