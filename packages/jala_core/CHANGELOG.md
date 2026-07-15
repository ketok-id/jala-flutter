## 0.1.0

- Initial release: `NetworkCallEntry` / `CapturedBody` models with a 512 KB
  per-body cap and safe handling of binary, oversize, and malformed-UTF8
  data.
- `JalaEventBus` + `JalaStore` ring buffer (default 300 entries)
  correlating request/response/error/cancel events by call id, evicting
  oldest completed entries first.
- `JalaRedactor` — case-insensitive header redaction (`Authorization`,
  `Cookie`, `X-Api-Key`, etc. by default) and body pattern redaction,
  designed to run at capture time so secrets never enter the store.
- `JalaFilter` DevTools-style query grammar: `method:`/`m:`, `status:`/`s:`,
  `host:`/`d:`, `path:`, `type:`/`t:`, `larger-than:`, `slower-than:`,
  `is:replay`, `body:`, bare text, and `-` negation.
- `CurlExporter`, `DartSnippetExporter`, and `HarExporter` (HAR 1.2, single
  call or whole session).
- `JalaBinding` process-wide singleton and `JalaReplayRegistry` so client
  integrations (e.g. `jala_dio`) can wire capture and replay.
- `JalaConfig` with `enabled`, `maxEntries`, `maxBodyBytes`, and `redactor`.
