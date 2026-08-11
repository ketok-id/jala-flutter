## 0.8.1 — 2026-08-11

Android bug-fix release. All four fixes were user-reported and are verified
on a physical device (Xiaomi, Android 13 / API 33).

### Fixed

- **Text fields in the inspector ignored Backspace on Android.** Delete
  arrives from Gboard as a `KEYCODE_DEL` *key event*, which needs
  `DefaultTextEditingShortcuts` to become a delete intent; the inspector is
  a sibling of the host app and so never inherited the shortcut/action chain
  `WidgetsApp` installs. iOS was unaffected because its soft keyboard sends
  delete over the IME channel. Affected every field — filter bar, throttle
  host pattern, mock editor, request composer.
- **Escape, Tab and Enter did nothing inside the inspector**, for the same
  reason (`WidgetsApp.defaultShortcuts`). Escape now dismisses dialogs and
  sheets, Tab traverses, Enter/Space activates. Reachable anywhere there is
  a keyboard: web, Chromebook, Android tablet, desktop.

### Changed (behavior)

- **The system back button/gesture now belongs to the inspector while it is
  open.** It pops the inspector's own stack, then closes the inspector, and
  never reaches the host app. Previously it fell through to the host —
  popping the host's route, or exiting the app entirely when the host sat on
  its root route.

  Two mechanisms were at fault: `WidgetsBinding` dispatches to observers in
  registration order and the host's `WidgetsApp` always registered first, so
  the inspector's handler never ran; and the host's `WidgetsApp` reports
  *its own* pop capability to Android, so with nothing to pop the platform
  finished the activity without ever dispatching to Dart.

  Jala now registers its back observer in `Jala.initialize()` (before
  `runApp`, so it precedes the host), claims `setFrameworkHandlesBack` while
  open, and handles the predictive-back gesture (API 33+).

  **Note for hosts:** `setFrameworkHandlesBack(true)` is not handed back on
  close, because the host's own value is unknowable from a sibling widget
  and guessing wrong would strand a host that still has routes to pop. The
  practical effect is that back is routed through Dart, where Jala declines
  it and the host's `WidgetsApp` handles it exactly as before.

### Added

- `Jala.enableFileExport(directory)` / `Jala.disableFileExport()` — routes
  session and HAR exports to timestamped files instead of relying on the
  clipboard alone. Under 512 KB the clipboard is still written too, so
  pasting into a ticket keeps working. Web has no file system and falls
  back to the clipboard. See `docs/ADOPTION.md`.
- `JalaExportSink` / `JalaExportOutcome` (from `jala_ui`) for hosts that
  want a custom export destination.

## 0.8.0 — 2026-08-03

### Fixed

- Picks up capture-time body redaction on every adapter, correct Dio
  bandwidth throttling, a bubble that keeps its dragged position across
  opening and closing the inspector, and replay that refuses to resend a
  truncated request body. See the individual package changelogs.

## 0.7.0

- Fix: screens pushed from the inspector (call detail, diff, mocks, mock
  editor, request composer, throttle, WebSocket detail) ignored the AppBar
  theme toggle and always rendered in system brightness. `JalaThemeScope`
  was built inside the root route's `pageBuilder`, and a pushed route is a
  sibling overlay entry rather than a descendant of that route, so it saw
  no scope and fell back to a different controller. The scope now sits
  above the inspector's `Navigator`.

## 0.6.0

- Lockstep with `jala_core` / `jala_ui` 0.6.0: call diff, virtualized JSON
  tree, cURL + HAR import. No changes to the `Jala` facade API itself —
  use the inspector overflow menu / Compare with…, or drive
  `JalaCurlCodec` / `JalaHarCodec` / `JalaEntryDiff` from app code (see
  the example Inspect deeper section).

## 0.5.3

- Docs: mock persistence security notes; lockstep with core/ui 0.5.3 security
  hardening.

## 0.5.2

- Overlay: hide the floating **J** bubble while the inspector is open so
  it does not cover list/detail actions (pairs with `jala_ui` 0.5.2 UX).
- Lockstep with `jala_ui` / `jala_core` 0.5.2.

## 0.5.1

- Pub metadata: `homepage`, `issue_tracker`, package screenshots on
  pub.dev, and a clearer description (throttle + session share).
- Docs: link brownfield [ADOPTION](https://github.com/ketok-id/jala-flutter/blob/main/docs/ADOPTION.md)
  guide; note Flutter `>=3.35` and lockstep 0.5.x versions.

## 0.5.0

- Lockstep with 0.5.0 core/ui: network throttling, session export/import,
  GraphQL subscription payload timeline, `is:subscription` filter. No
  changes to the `Jala` facade API itself — open the inspector speed icon
  / overflow menu, or drive `JalaBinding.instance.throttleRegistry` and
  `JalaSessionCodec` from app code (see the example Power tools section).

## 0.4.0

- Lockstep with 0.4.0 core/ui: GraphQL operation metadata, merged
  WebSocket list + connection detail, `op:`/`is:graphql`/`is:ws` filters.
  No changes to the `Jala` facade API itself — attach `jala_graphql`
  (`JalaGraphQLLink`) or `jala_websocket` (`JalaWebSocketChannel.wrap`)
  alongside `jala_dio`/`jala_http` to capture GraphQL and WebSocket traffic.

## 0.3.0

- `Jala.enableMockPersistence(directory)` — file-backed mock rules that
  survive app restarts (IO platforms; no-op store on web).
- Lockstep with 0.3.0 core/ui: mocking UI, `is:mocked`, edit-and-resend.

## 0.2.0

- Lockstep release with `jala_core` / `jala_ui` 0.2.0: image preview,
  multipart parts table, and transfer progress in the inspector UI.
- Pulls in the 0.2.0 capture surface (image bodies, multipart model,
  `NetworkProgressEvent`) via dependency bumps.

## 0.1.2

- Fix: snackbar actions (copy cURL/Dart/HAR/body, replay feedback) threw
  inside the inspector overlay and could crash release builds — the overlay
  now provides its own `ScaffoldMessenger`.

## 0.1.1

- Add pub.dev topics.
- Add a minimal `example/` app so pub.dev renders the Example tab.

## 0.1.0

- `Jala.initialize()` — idempotent setup that defaults `enabled` to
  `kDebugMode`.
- `Jala.open()` / `Jala.close()` / `Jala.isOpen` to control the
  inspector surface, plus `Jala.store` / `Jala.bus` accessors for
  building custom client integrations.
- `JalaOverlay` — drops the floating bubble and full-screen inspector
  host above the host app; returns `child` unchanged with zero overhead
  when Jala is disabled or uninitialized.
- Own `Navigator` and explicit theme for the inspector surface, isolated
  from the host app's navigation stack and `Theme`.
- Correct Android back-button handling: back pops the inspector's own
  navigator, then closes the inspector, before ever reaching the host
  app.
