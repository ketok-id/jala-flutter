## 0.8.2 — 2026-08-11

### Added

- `JalaConfig.locale` — BCP-47 language tag selecting the inspector's UI
  language (`'id-ID'`, `'en'`). Optional, defaults to `null`, and `null`
  means **English, not "follow the device"**: the platform locale is
  deliberately never consulted, so upgrading changes nothing for a host that
  does not set it.

  Stored as a `String` rather than a `Locale` because `Locale` lives in
  `dart:ui` and `jala_core` stays free of Flutter; `jala_ui` parses it.

