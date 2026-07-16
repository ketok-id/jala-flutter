## 0.2.0

- Image body capture: `BodyKind.image` plus `CapturedBody.bytes` /
  `CapturedBody.captureBytes`, gated by `JalaConfig.captureImageBodies`
  (default true) and `maxBodyBytes`.
- Multipart model: `JalaMultipartPart` and `CapturedBodyMultipart` with the
  `{"@multipart": [...]}` JSON convention for structured part metadata.
- Progress events: `NetworkProgressEvent` (sent/received byte counters) and
  `NetworkCallEntry.progress` updated live by the store.
- cURL exporter emits `-F` flags with filename placeholders for multipart
  bodies (never real file contents); image bodies export as size/mime
  placeholders.

## 0.1.1

- Add pub.dev topics.

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
