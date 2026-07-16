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
