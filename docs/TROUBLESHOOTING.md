# Troubleshooting

Common “it doesn’t show up” cases. Architecture background:
[overview.md](overview.md). Config/redaction: [CONFIG.md](CONFIG.md).

---

## Checklist (start here)

1. **`Jala.initialize()`** ran once before traffic (e.g. in `main`).
2. **`enabled`** is true for this build (`kDebugMode` in debug; release is
   off unless you set `JalaConfig(enabled: true)`).
3. **Client attached** — `JalaDio.attach(dio)` / `JalaHttp.wrap` /
   `JalaGraphQLLink` / `JalaWebSocketChannel.wrap` on **the same instance**
   that sends the call.
4. **`JalaOverlay`** wraps the app (for the bubble); or call `Jala.open()`.
5. **Hot restart** after changing `JalaConfig` / interceptor order (hot
   reload does not re-run `main`; `initialize` is first-config-wins).
6. Look at a **new** request (old store entries keep old redaction).

---

## Symptom table

| Symptom | Likely cause | Fix |
|---|---|---|
| No floating **J** bubble | Disabled, or overlay not at root | `enabled` / wrap above `MaterialApp` with `JalaOverlay` |
| No entries at all | Wrong Dio/`http` instance not attached | Attach **that** client; see multi-client in [ADOPTION.md](ADOPTION.md) |
| Entries but empty / wrong host | Traffic on another client | Attach all instances you care about |
| **Token not shown and not `••••••`** | Token never present at capture | See [Missing token](#missing-token-not-shown-and-not-redacted) |
| Token shown as `••••••` | Default redaction (expected) | See [CONFIG.md](CONFIG.md) to loosen in debug only |
| Auth row “missing” in UI | Collapsed under **Sensitive** | Expand “Show N sensitive (cookie, authorization, …)” or search headers |
| Replay greyed out | No replayer registered, or imported entry | Use `JalaDio.attach` / `JalaHttp.wrap` (not interceptor alone); clear import banner |
| Replay fails auth | Masked headers/query dropped on purpose | Expected when redacted; need live auth interceptor or unredacted debug capture |
| Duplicate GraphQL + HTTP rows | Dio/http + GraphQL link both capturing | Prefer `JalaGraphQLLink` only for that transport ([ADOPTION.md](ADOPTION.md)) |
| Works in debug, empty in release QA | Default `enabled: kDebugMode` | Internal flavor: `JalaConfig(enabled: true)` + privacy review |
| Large download not slow under Dio throttle | Non-stream response type | `ResponseType.stream` or test with `jala_http` |
| WebSocket not affected by Slow 3G | By design | Throttle is HTTP-only |
| cURL missing Authorization when exporting “unredacted” | Export cannot recover mask | `redacted: false` **drops** masked headers; secrets were never stored |
| Config change ignored | Second `initialize` or hot reload | Hot **restart**; first config wins |

---

## Missing token (not shown and not redacted)

If you see **neither** the real token **nor** `••••••`, Jala did not capture
that value. Redaction only rewrites values already in the header map, URL,
or body.

### 1. Dio interceptor order (most common)

`JalaDioInterceptor` snapshots `options.headers` in `onRequest`. Auth added
**after** Jala is invisible to the inspector.

```dart
// BAD: Jala runs before auth → Authorization never captured
JalaDio.attach(dio);
dio.interceptors.add(AuthInterceptor());

// GOOD: auth first, Jala last (sees final headers)
dio.interceptors.add(AuthInterceptor());
JalaDio.attach(dio);
```

`JalaDio.attach` uses `interceptors.add`, so anything added **after** attach
runs later and can be missing from capture.

### 2. Token not on that client

Token configured on `authDio` while only `apiDio` is attached (or the reverse).

### 3. Token not in headers

| Location | Where to look in the inspector |
|---|---|
| `Authorization` / `Cookie` / `x-api-key` | Request → Headers → expand **Sensitive** if needed |
| `?access_token=` query | URL / Query parameters table (0.7+) |
| JSON body field | Request → Body |
| Multipart field | Parts table (may be metadata-only) |
| Secure storage only until send | Not visible until actually on the request |

### 4. Empty credential at send time

`Authorization: Bearer $token` with `token == null` or `''` yields a blank
or useless value — not a useful redaction of a secret.

### 5. UI collapse

`authorization` / `cookie` / `set-cookie` / `proxy-authorization` are hidden
under **Sensitive** until expanded. Search the headers field for `auth`.

### 6. Redaction disabled but still empty

Empty redact lists only unmask values **if they were captured**. Fix attach
order first; then re-fire the request after hot restart.

---

## How to confirm capture

1. Open the call → **Request** tab → headers / query / body.  
2. Temporarily log at the last interceptor:

   ```dart
   dio.interceptors.add(
     InterceptorsWrapper(
       onRequest: (options, handler) {
         // ignore: avoid_print
         print(options.headers);
         handler.next(options);
       },
     ),
   );
   ```

   If the token is not in that map when Jala has already run, Jala cannot
   show it.  
3. Compare with the example app: `examples/jala_example` sets
   `Authorization` on `BaseOptions` **before** `JalaDio.attach` so the demo
   always shows a redacted bearer token.

---

## Multi-client replay

Only **one** replayer is active — **last** `JalaDio.attach` /
`JalaHttp.wrap` wins. Attach the primary API client last, or accept that
Replay targets the last-registered client.

---

## See also

- [ADOPTION.md](ADOPTION.md) — brownfield install and PR checklist  
- [CONFIG.md](CONFIG.md) — redactor recipes  
- [SECURITY.md](SECURITY.md) — why defaults mask tokens  
- Package READMEs under `packages/*` for adapter-specific limits  
