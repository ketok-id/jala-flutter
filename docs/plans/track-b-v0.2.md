# Track B — v0.2.0: capture-surface growth

Four features. B1/B2 are independent and can run as parallel executors;
B3/B4 build on B1's package. Version bump 0.2.0 across all packages.

## B1. `jala_http` — package:http adapter (new package)

Highest-reach feature (`http` is the most-used Dart client) and the proof
that the jala_core plugin architecture works beyond Dio.

- New package `packages/jala_http`, deps: `http: ^1.2.0`, `jala_core`.
- API: `JalaHttpClient` implementing `http.BaseClient`, wrapping an inner
  client (`JalaHttpClient(inner: http.Client())`; default inner when
  omitted). Usage: `final client = JalaHttp.wrap(http.Client());`
- Capture in `send()`: same event flow as the Dio interceptor — request
  event (redacted headers, body via `CapturedBody.capture`; for
  `http.Request` use `bodyBytes`, for `MultipartRequest` summarize fields +
  file names/sizes, for `StreamedRequest` metadata only), stopwatch,
  response event from the `StreamedResponse` (buffer up to
  `maxBodyBytes` while re-streaming to the caller — must NOT consume the
  stream: use a tee/splitter so the app still receives the body), error
  event on exception.
- The stream-tee is the hard part: implement
  `Stream<List<int>> _teeAndCapture(Stream<List<int>>, onDone(bytes))`
  buffering at most maxBodyBytes and counting total length. Test with a
  slow/chunked fake.
- Replay: `JalaHttpReplayer implements JalaReplayer` re-issuing via the
  wrapped client; register in `JalaBinding.instance.replayRegistry` from
  `JalaHttp.wrap` (note: last-registered wins vs jala_dio — document).
- `client` field on the entry: `'http'` (list tile + HAR already carry it).
- Tests mirror jala_dio's: fake inner client, success/error/redact/
  truncation/disabled/replay + the tee (body delivered intact to caller AND
  captured, large body truncated in capture but complete for caller).
- Wire into workspace root, CI, README comparison table (`http` row: Alice
  yes / Jala yes), example app: add a toggle to fire the same buttons via
  package:http.

## B2. Image preview (closes the v0.1 gap found on the iOS simulator)

- `jala_core`: extend `JalaConfig` with `captureImageBodies: bool` (default
  true) and honor it in capture paths: when response content-type starts
  with `image/` and size <= maxBodyBytes, keep the raw bytes in
  `CapturedBody` (new `BodyKind.image`, `Uint8List? bytes` field —
  bytes currently are metadata-only).
- `jala_dio`/`jala_http`: on bytes/stream responses with image content-type
  and within cap, buffer and emit as `BodyKind.image` (dio: only for
  `ResponseType.bytes`; for streams keep metadata-only).
- `jala_ui` body view: `BodyKind.image` renders `Image.memory` (constrained,
  tap to view full-screen with InteractiveViewer/pinch-zoom), with size +
  dimensions caption; broken image falls back to the binary info card.
- Memory guard: image bytes count against the store the same as text bodies;
  ring-buffer eviction already bounds total. Add a widget test with a tiny
  1x1 PNG fixture.

## B3. Multipart detail

- Capture (both adapters): structured multipart summary — list of parts
  {name, filename?, contentType?, size} — stored as the request body's JSON
  (kind json) under `{"@multipart": [...]}` convention.
- `jala_ui`: request body view detects `@multipart` and renders a parts
  table instead of the raw JSON tree.
- cURL exporter: multipart requests emit `-F` flags with filename
  placeholders (never file contents).

## B4. Upload/download progress

- `jala_core`: new event `NetworkProgressEvent {id, sent, total?, received,
  receivedTotal?}`; store keeps latest progress on pending entries
  (`NetworkCallEntry.progress`).
- `jala_dio`: wire `onSendProgress`/`onReceiveProgress`? Not available from
  an interceptor — instead, for streamed/download responses count bytes in
  the response stream wrapper; for uploads wrap the request stream. Scope
  honestly: dio progress only where the interceptor can observe it; document
  the limitation.
- `jala_http`: the B1 tee already counts bytes — emit progress every ~100ms
  or 64KB.
- `jala_ui`: pending list tiles show a determinate progress bar when
  progress.total is known, else the existing spinner; detail Overview shows
  live transferred bytes.

## Release checklist

- All packages -> 0.2.0 (lockstep), CHANGELOGs, README updates (jala_http
  install, image preview note), publish dry-run x5 clean, live smoke test
  (web + one device): image preview renders, http client captured, progress
  bar visible on the Large (~1MB) button.
