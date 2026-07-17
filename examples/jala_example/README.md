# jala_example

Manual QA rig for Jala (current: **v0.5**). Wraps the app in `JalaOverlay`,
attaches Dio via `JalaDio.attach` and `package:http` via `JalaHttp.wrap`,
and provides buttons that hit public echo/demo hosts so you can exercise
filters, export, replay, redaction, mocks, GraphQL, WebSockets, throttling,
and session share in the inspector.

Adding Jala to **your** app? Start with
[docs/ADOPTION.md](../../docs/ADOPTION.md) rather than copying this rig
wholesale — the example deliberately wires everything at once for QA.

## Run

From the workspace root:

```bash
flutter pub get
cd examples/jala_example
flutter run -d macos   # or chrome / ios / android
```

Tap the floating **J** bubble (or the bug icon in the app bar) to open the
inspector after firing a few requests.

## Hosts

| Surface | Host |
|---|---|
| Echo / status / gzip / multipart | postman-echo.com |
| Large download (~1 MiB) | speed.cloudflare.com |
| Slow / image | httpbingo.org |
| Backup GET | jsonplaceholder.typicode.com |
| WebSocket echo | wss://ws.postman-echo.com/raw |
| GraphQL query | countries.trevorblades.com |

## Scenarios covered

| Button | What to verify |
|---|---|
| GET / POST json | list + detail + JSON tree |
| 404 / 500 | status colors, error status |
| Slow | pending spinner, duration |
| Redirect | follow + capture |
| Image / Large | image preview / truncation + progress |
| Gzip | text/json body decode |
| Multipart | FormData summary (no file bytes) |
| Cancel | cancelled status |
| Bad host | error entry |
| Auth header | redacted as `***` in inspector |
| HTTP: GET / 404 / Large | same paths via `jala_http` |
| WS: echo / binary | merged list `WS` chip + frame timeline |
| GraphQL: countries query | `QUERY` chip, Query/Variables panes |
| Throttle: Slow 3G + Large | throttle banner + latency under Slow 3G |
| Throttle: Off | clears active profile |
| Session: export → import | import banner; Replay disabled on imported rows |

### Inspector-only (no example buttons)

| Action | Where |
|---|---|
| Throttle presets / custom / host pattern | AppBar **speed** icon |
| Export / Import session (clipboard paste) | AppBar **overflow** menu |
| Mock this / Edit & resend | Call detail actions |
| Filter help (`is:subscription`, `is:ws`, …) | Filter field help |

## Integration smokes

Store-only integration tests under `integration_test/`:

```bash
cd examples/jala_example
flutter test integration_test/track_e_smoke_test.dart
# also: track_b / track_c / track_d_smoke_test.dart
```
