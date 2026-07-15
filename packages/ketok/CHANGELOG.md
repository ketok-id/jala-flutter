## 0.1.0

- `Ketok.initialize()` — idempotent setup that defaults `enabled` to
  `kDebugMode`.
- `Ketok.open()` / `Ketok.close()` / `Ketok.isOpen` to control the
  inspector surface, plus `Ketok.store` / `Ketok.bus` accessors for
  building custom client integrations.
- `KetokOverlay` — drops the floating bubble and full-screen inspector
  host above the host app; returns `child` unchanged with zero overhead
  when Ketok is disabled or uninitialized.
- Own `Navigator` and explicit theme for the inspector surface, isolated
  from the host app's navigation stack and `Theme`.
- Correct Android back-button handling: back pops the inspector's own
  navigator, then closes the inspector, before ever reaching the host
  app.
