# How Jala works

Architecture and product invariants. For “which package do I install?”, see
[packages.md](packages.md). For brownfield wiring, see [ADOPTION.md](ADOPTION.md).

---

## Product promise

Jala is an **in-app network inspector** for Flutter: capture HTTP / GraphQL /
WebSocket traffic inside the process, browse it with a DevTools-style filter
grammar, export (cURL, Dart snippet, HAR, session JSON), replay, mock, and
throttle — without Charles/Proxyman on the device.

Defaults:

- **Off in release** (`Jala.initialize()` → `enabled: kDebugMode`)
- **Redaction at capture time** (secrets never enter the store as raw values)
- **True no-op when disabled** (adapters skip work; overlay returns child)

---

## Package layering

```
jala (facade)  →  jala_ui  →  jala_core
adapters (dio / http / graphql / websocket)  →  jala_core only
```

Apps install **`jala` + adapters**. Adapters never depend on UI.

Details: [packages.md](packages.md).

---

## The binding singleton

`JalaBinding.instance` (`jala_core`) is a **process-wide** singleton holding:

- `JalaConfig` (enabled, caps, redactor)
- `JalaEventBus`
- `JalaStore`
- Replay registry, mock registry, throttle registry

Adapters **read the binding at call time** rather than taking constructor
config, so one `Jala.initialize()` configures every attached client.

Before `initialize()`, the binding exists but `isEnabled` is false and every
capture path is a no-op.

`Jala.initialize` is **idempotent**: a second call keeps the **first**
config. Tests use `JalaBinding.resetForTesting()`.

---

## Capture flow

```
Adapter hook
  → redact headers / URI / body (config.redactor)
  → JalaEventBus.emit(JalaEvent)
  → JalaStore correlates by callId → NetworkCallEntry
  → store.watch stream
  → jala_ui
```

- **HTTP / GraphQL** become `NetworkCallEntry` rows (GraphQL adds operation
  metadata and optional subscription payload ring).
- **WebSocket** connections live in a **parallel** collection
  (`wsConnections` / `watchWs`). The merged list is a **UI** concern.

### Events (sealed hierarchy)

Examples: `NetworkRequestEvent`, `NetworkResponseEvent`, `NetworkErrorEvent`,
`NetworkCancelEvent`, `NetworkProgressEvent`, subscription payload events,
WS connect/open/frame/close/error. Every network event carries `callId`.

### Store

Newest-first ring buffer (`maxEntries`, default 300). Eviction prefers the
oldest **completed** entry; pending entries are only evicted when nothing
completed remains. Events for an unknown/evicted id are dropped.

---

## Invariants (product promises)

Preserve these in any capture-path change:

1. **True no-op when disabled.** First line of every hook checks
   `JalaBinding.instance.isEnabled` and forwards immediately if false.
   `JalaOverlay` returns its child unchanged.
2. **Capture never breaks host networking.** Capture work is wrapped in
   `try`/`catch`; request/response/error is forwarded **exactly once**.
3. **Redaction happens at capture time.** Headers/bodies/sensitive query
   params are masked before emit — raw secrets never enter the store; there
   is **no reveal path**. See [CONFIG.md](CONFIG.md) and
   [SECURITY.md](SECURITY.md).
4. **Hard body caps.** `CapturedBody` truncates at `maxBodyBytes`
   (512 KB default).
5. **Inspector owns theme and navigator.** `jala_ui` does not inherit the
   host `Theme`; `JalaOverlay` mounts a private `Navigator` and localizations.

---

## Replay

`JalaReplayRegistry` holds a **single active replayer — last registration
wins**. `JalaDio.attach` / `JalaHttp.wrap` register one.

Multi-client apps: attach the **primary** client last (documented in
[ADOPTION.md](ADOPTION.md)). Replayed calls flow through the adapter again
and appear as new entries with `replayOf` set. Imported (HAR/session)
entries disable replay.

Masked header values and masked query params are **not** resent (Jala never
had the real secret).

---

## UI vs core

| Layer | Responsibility |
|---|---|
| Adapters | Observe client; emit redacted events; optional mock/throttle short-circuit |
| `jala_core` | Correlate, store, filter grammar, export/import codecs, registries |
| `jala_ui` | Present entries, filter bar, export actions, replay/mock UX |
| `jala` | One-line app API + overlay + optional mock file store |

---

## See also

- [CONFIG.md](CONFIG.md) — configuration reference  
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — common failure modes  
- [SPEC-v0.1.md](SPEC-v0.1.md) — original binding contract  
