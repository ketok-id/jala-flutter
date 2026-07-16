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
