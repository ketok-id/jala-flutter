# ketok_example

Manual QA rig for Ketok v0.1. Wraps the app in `KetokOverlay`, attaches Dio
via `KetokDio.attach`, and provides buttons that hit httpbin.org (and
jsonplaceholder as backup).

## Run

From the workspace root:

```bash
flutter pub get
cd examples/ketok_example
flutter run -d macos   # or chrome / ios / android
```

Tap the floating **K** bubble (or the bug icon in the app bar) to open the
inspector after firing a few requests.

## Scenarios covered

| Button | What to verify |
|---|---|
| GET / POST json | list + detail + JSON tree |
| 404 / 500 | status colors, error status |
| Slow | pending spinner, duration |
| Redirect | follow + capture |
| Image / Large | bytes metadata / truncation |
| Gzip | text/json body decode |
| Multipart | FormData summary (no file bytes) |
| Cancel | cancelled status |
| Bad host | error entry |
| Auth header | redacted as `***` in inspector |
