## 0.1.0

- Initial release: `NetworkCallEntry` / `CapturedBody` models with a 512 KB
  per-body cap and safe handling of binary, oversize, and malformed-UTF8
  data.
- `KetokEventBus` + `KetokStore` ring buffer (default 300 entries)
  correlating request/response/error/cancel events by call id, evicting
  oldest completed entries first.
- `KetokRedactor` — case-insensitive header redaction (`Authorization`,
  `Cookie`, `X-Api-Key`, etc. by default) and body pattern redaction,
  designed to run at capture time so secrets never enter the store.
- `KetokFilter` DevTools-style query grammar: `method:`/`m:`, `status:`/`s:`,
  `host:`/`d:`, `path:`, `type:`/`t:`, `larger-than:`, `slower-than:`,
  `is:replay`, `body:`, bare text, and `-` negation.
- `CurlExporter`, `DartSnippetExporter`, and `HarExporter` (HAR 1.2, single
  call or whole session).
- `KetokBinding` process-wide singleton and `KetokReplayRegistry` so client
  integrations (e.g. `ketok_dio`) can wire capture and replay.
- `KetokConfig` with `enabled`, `maxEntries`, `maxBodyBytes`, and `redactor`.
