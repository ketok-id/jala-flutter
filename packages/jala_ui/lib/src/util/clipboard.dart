import 'package:flutter/services.dart';

/// Copies [text] to the system clipboard, reporting whether it landed.
///
/// Every copy action in the inspector used to `await Clipboard.setData`
/// with no `try`/`catch` and then show "Copied X" unconditionally. On
/// Android the clipboard rides the Binder transaction buffer (~1 MB shared
/// across the process), so copying a large body or a cURL command can fail
/// — and the UI would still claim success while the paste came out empty.
///
/// Returns false instead of throwing: a copy failing must never surface as
/// an exception in the host app.
Future<bool> jalaCopyToClipboard(String text) async {
  try {
    await Clipboard.setData(ClipboardData(text: text));
    return true;
  } on Object {
    return false;
  }
}

/// Snackbar text for a copy attempt on [label] of [text].
///
/// Names a likely cause on failure rather than a bare "failed" — size is
/// far and away the common one.
String jalaCopyMessage({
  required bool ok,
  required String label,
  required String text,
}) {
  if (ok) return 'Copied $label';
  final int kb = (text.length / 1024).round();
  return 'Could not copy $label (~$kb KB) — too large for the clipboard?';
}
