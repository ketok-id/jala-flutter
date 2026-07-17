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
