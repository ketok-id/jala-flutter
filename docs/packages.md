# Package map

Which package to install, what it depends on, and when you need it.

**Lockstep:** all seven packages share one version (currently **`0.7.x`**).
Do not mix minors — see [COMPAT.md](COMPAT.md).

---

## Quick pick

| Your stack | Install |
|---|---|
| Flutter app + Dio | `jala` + `jala_dio` |
| Flutter app + `package:http` | `jala` + `jala_http` |
| GraphQL (`graphql_flutter` / ferry / `gql_link`) | `jala` + `jala_graphql` (+ HTTP adapter only if you also want non-GraphQL traffic) |
| WebSockets (`web_socket_channel`) | `jala` + `jala_websocket` |
| Custom client / CLI / headless tooling | `jala_core` only |
| Custom inspector UI | `jala_ui` + `jala_core` (unusual — most apps use `jala`) |

---

## Layering (dependency direction is strict)

```
jala (facade, Flutter)  →  jala_ui  →  jala_core
jala_dio / jala_http / jala_graphql / jala_websocket  →  jala_core
```

- Adapters **never** import `jala_ui` or `jala`.
- `jala_core` has **zero Flutter** dependency.
- Apps almost always depend on **`jala`**, not on `jala_ui` directly.

---

## Packages

### `jala` — facade (install this in apps)

| | |
|---|---|
| **Depends on** | `jala_ui`, `jala_core` (Flutter) |
| **Public surface** | `Jala.initialize`, `Jala.open` / `close`, `JalaOverlay`, mock file persistence |
| **Install if** | You are building a Flutter app |

Wires the process-wide binding, mounts the inspector overlay, and is the
only package that offers a file-backed mock store (`dart:io` conditional
import). Default: `enabled: kDebugMode`.

→ [packages/jala/README.md](../packages/jala/README.md)

### `jala_ui` — inspector screens

| | |
|---|---|
| **Depends on** | `jala_core` (Flutter) |
| **Public surface** | Call list/detail, filter bar, JSON tree, diff, import, throttle UI, overlay bubble, theme |
| **Install if** | Rarely — pulled in by `jala`. Use directly only for a custom host shell |

Owns its **theme and navigator** (sibling of the host `MaterialApp`, not a
child of host `Theme`).

→ [packages/jala_ui/README.md](../packages/jala_ui/README.md)

### `jala_core` — pure Dart engine

| | |
|---|---|
| **Depends on** | None (Dart only) |
| **Public surface** | Binding, store, events, redactor, filter, exporters, import codecs, mocks, throttle, session codec, diff |
| **Install if** | Writing an adapter, headless tooling, or tests without Flutter |

Everything adapters emit into, and everything the UI reads. No widgets.

→ [packages/jala_core/README.md](../packages/jala_core/README.md)

### `jala_dio` — Dio adapter

| | |
|---|---|
| **Depends on** | `jala_core`, `dio` |
| **Public surface** | `JalaDio.attach`, `JalaDioInterceptor`, `JalaDioReplayer` |
| **Install if** | Traffic goes through `Dio` |

Captures request/response/error/cancel/progress; registers replay.
**Interceptor order matters** — see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
and the package README.

→ [packages/jala_dio/README.md](../packages/jala_dio/README.md)

### `jala_http` — `package:http` adapter

| | |
|---|---|
| **Depends on** | `jala_core`, `http` |
| **Public surface** | `JalaHttp.wrap`, `JalaHttpClient`, `JalaHttpReplayer` |
| **Install if** | Traffic goes through `http.Client` |

Full throttle support (including upload/download pacing where streams allow).

→ [packages/jala_http/README.md](../packages/jala_http/README.md)

### `jala_graphql` — GraphQL (`gql_link`) adapter

| | |
|---|---|
| **Depends on** | `jala_core`, `gql` / `gql_exec` / `gql_link` |
| **Public surface** | `JalaGraphQLLink` |
| **Install if** | You use `graphql_flutter`, ferry, or any `gql_link` stack |

Insert **before** the terminating link. Avoid also attaching Dio/http on the
**same** transport if you do not want double rows — see [ADOPTION.md](ADOPTION.md).

→ [packages/jala_graphql/README.md](../packages/jala_graphql/README.md)

### `jala_websocket` — WebSocket adapter

| | |
|---|---|
| **Depends on** | `jala_core`, `web_socket_channel` |
| **Public surface** | `JalaWebSocketChannel.wrap` |
| **Install if** | You use `WebSocketChannel` |

Connections live in a **parallel** store collection (not HTTP entries).
Frame timeline is not throttled (HTTP-only in v0.5+).

→ [packages/jala_websocket/README.md](../packages/jala_websocket/README.md)

---

## Example app

| Path | Role |
|---|---|
| [`examples/jala_example`](../examples/jala_example) | Manual QA rig + source of the [GitHub Pages demo](https://ketok-id.github.io/jala-flutter/) |

Built and deployed from `main` on every push (`.github/workflows/deploy-demo.yaml`).

---

## See also

- [overview.md](overview.md) — capture flow and invariants  
- [ADOPTION.md](ADOPTION.md) — multi-client, migration, PR checklist  
- [CONFIG.md](CONFIG.md) — `JalaConfig` / `JalaRedactor`  
