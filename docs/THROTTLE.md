# Throttling — simulating bad networks on-device

Jala can slow, jitter, cap and drop requests from inside the app, so a
tester can reproduce a "works on wifi, breaks on the train" bug without a
proxy on the device.

**Read the scope section first.** Almost every "throttling doesn't work"
report is traffic that was never in scope.

## Scope — what actually gets throttled

Throttling is applied by the **adapters**, inside a client you attached
Jala to. It is not a device-wide or process-wide network shim.

| Traffic | Throttled? |
|---|---|
| A `Dio` passed to `JalaDio.attach` | ✅ latency, jitter, drops, up/down bandwidth |
| A client from `JalaHttp.wrap` | ✅ latency, jitter, drops, up/down bandwidth |
| `Image.network`, `NetworkImage` | ❌ never sees an adapter |
| A `Dio`/`http` client you did **not** attach | ❌ |
| Raw `HttpClient` / `dart:io` sockets | ❌ |
| WebSocket frames (`jala_websocket`) | ❌ connection setup only, frames are not paced |
| gRPC (`jala_grpc`) | ❌ by design — `ClientInterceptor` cannot delay a response |
| Native HTTP stacks (`cronet_http`, `cupertino_http`) | ❌ |

If you need coverage below the adapter — including `Image.network` and
unattached clients — that is [Track I](plans/track-i-v0.8.3-socket-throttle.md),
not shipped yet. Until then, `Network Link Conditioner` (iOS/macOS) or
Android emulator network profiles remain the honest answer for whole-device
simulation.

## Using it from the inspector

1. Open Jala and tap the **Throttle** icon in the AppBar (its tooltip reads
   `Throttling: <name>` once a profile is active).
2. Pick a preset, or **Custom** and fill the fields, then **Apply custom
   profile**. **Off** clears it.
3. Optionally set a **host pattern** to scope it. Leave it **empty to
   apply to all hosts** — this is the field that most often silently
   disables the whole feature (see Troubleshooting).
4. A banner stays visible in the inspector while a profile is active.

### Built-in presets

| Preset | Latency | Bandwidth | Drop rate |
|---|---|---|---|
| **Slow 3G** | 400 ms ± 100 | 50 KB/s down, 25 KB/s up | — |
| **Fast 3G** | 150 ms ± 50 | 180 KB/s down | — |
| **Flaky** | 200 ms ± 200 | unlimited | 15 % |
| **Offline** | 0 ms | — | 100 % |

Dropped calls surface as a normal client error
(`Jala throttle: dropped by profile "<id>"`), so your app's error handling
runs exactly as it would on a real failure.

## Using it from code

Useful for integration tests and for wiring throttling to your own debug
menu.

```dart
final registry = JalaBinding.instance.throttleRegistry;

// A preset, everywhere.
registry.setActive(JalaThrottleProfile.slow3g);

// A custom profile scoped to one host (glob, case-insensitive).
registry.setActive(
  const JalaThrottleProfile(
    id: 'checkout-slow',
    name: 'Checkout slow',
    latencyMs: 800,
    jitterMs: 200,
    downloadBytesPerSec: 30 * 1024,
    dropRate: 0.1,
  ),
  hostPattern: '*.example.com',
);

registry.clear(); // off
```

`registry.watch` is a broadcast stream of the active profile, replayed to
each new listener.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Nothing is slowed at all | The traffic isn't going through an attached client | Check the scope table above |
| Nothing is slowed, and you set a host pattern | The glob doesn't match — `hostMatches` excludes everything and the profile silently no-ops | Clear the field to apply to all hosts; the pattern matches the **host only** (`api.example.com`), not the scheme or path |
| A download arrives all at once, but late | Buffered response types can't be delivered progressively | Expected — total duration still honors the cap. Use `ResponseType.stream` for chunk-by-chunk pacing |
| Throttling stopped after a hot restart | The registry lives on `JalaBinding`, which resets | Re-apply the profile |
| Nothing happens in release | Jala is disabled unless `JalaConfig(enabled: true)` | By design — see [SECURITY.md](SECURITY.md) |

Connection setup and the TLS handshake are **not** simulated: latency is
added around an already-established request. A cap of `50 KB/s` therefore
models steady-state bandwidth, not the full cost of a cold connection on a
bad network.

## Safety

Throttling only applies while Jala is enabled, and a disabled binding makes
every read a true no-op — a profile left active in code cannot affect a
release build where `JalaConfig.enabled` is false. See
[SECURITY.md](SECURITY.md).
