# Track I — v0.8.3 proposal: socket-level throttling

Proposal written 2026-08-04, after auditing the 0.8.0 throttle work. **Not
part of 0.8.0.** Decide before starting — see "Open questions".

**Renumbered 0.8.1 → 0.8.2 → 0.8.3.** 0.8.1 went to an unrelated bug-fix
release (2026-08-11), and Track H — the one actually being built — takes
0.8.2. Nothing in the reasoning below changes —
the argument is about the change staying additive and opt-in, not about
the digits. Flip both roadmap rows if H and I swap order.

## Why a patch and not 0.9.0

`docs/COMPAT.md` ships new features as a **minor** by default —
"sometimes patch if tiny" is the exception this track claims. That is only
honest if the track stays **strictly additive and opt-in**:

- `JalaConfig` defaults unchanged; throttling behaves exactly as 0.8.0 does
  until a caller opts in.
- `HttpOverrides.global` is set **only** from an explicit
  `Jala.enableSocketThrottling()` call — never from `Jala.initialize`.
- No existing public type changes shape.

**If any of those stops holding — in particular if socket mode becomes the
default or replaces the adapter path — the release becomes 0.9.0.** Version
choice is a constraint on the design here, not a label applied afterwards.

Today's throttle is an honest simulation, but it simulates the wrong layer.
This proposes moving it down to the socket, which fixes both its scope
problem and most of its fidelity problem — without native code, entitlements
or a VPN.

## Why

Two complaints, one root cause: the delay is applied to a *decoded response*
inside an adapter Jala was explicitly attached to.

**Scope.** Only traffic through `JalaDio.attach`ed / `JalaHttp.wrap`ped
clients is affected. A raw `HttpClient`, an unattached `Dio`, and — most
visibly — `Image.network` all ignore the profile completely. "I set Slow 3G
and my images still load instantly" is the single most confusing thing about
the feature, and it looks like a bug.

**Fidelity.** Delaying an already-decoded body simulates elapsed time and
nothing else. Connection setup and the TLS handshake are free; a streamed
download is paced by an artificial timer rather than by bytes actually
arriving slowly.

## The two hooks (verified against the Dart SDK in this repo, 3.41.9)

- **`HttpClient.connectionFactory`** — `_http/http.dart:1547`. Returns
  `Future<ConnectionTask<Socket>>`, i.e. the caller supplies the actual
  socket. Wrap it and every byte of the connection is ours to pace.
- **`HttpOverrides.global`** — `_http/overrides.dart:32`. Replaces
  `HttpClient()` construction process-wide, so clients Jala never saw are
  covered too.

## What this does and does not buy

| | 0.8.0 (adapter-level) | Track I (socket-level) |
|---|---|---|
| What is delayed | decoded response body | real socket bytes |
| TCP connect + TLS handshake cost | free | ✅ shaped |
| `Image.network`, unattached `Dio`, Dart SDKs | untouched | ✅ covered |
| Streamed download pacing | artificial timer | ✅ bytes genuinely arrive slowly |
| Drop simulation | synthetic exception after the fact | ✅ connection actually fails |
| Latency | delay before the request is handed on | ✅ delay before connect, like real RTT |

**Explicitly still not solved** — say so in the README rather than letting
users assume otherwise:

- **Packet loss, jitter, reordering, DNS delay.** This is byte pacing on an
  established stream, not a network emulator.
- **HTTP/2.** `dart:io`'s `HttpClient` speaks HTTP/1.1 only
  (`http_impl.dart:1667`), so there is no h2 flow-control behaviour to
  observe either way. (An earlier draft of this claim was wrong.)
- **Native HTTP stacks.** `cronet_http`, `cupertino_http`, and any native
  SDK (Firebase native, ad SDKs) never touch `dart:io` and are unaffected.
- **Web.** No `dart:io`. Web keeps the adapter-level simulation.

For genuine network conditions the answer stays "use the real tool" —
Network Link Conditioner, the Android emulator's `-netspeed`, or a proxy.
Track I narrows that gap; it does not close it. An on-device VPN
(`NEPacketTunnelProvider` / `VpnService`) *would* close it and is
**rejected** for the same reason in-app breakpoints were: native code on
both platforms, an iOS Network Extension entitlement, App Store review, and
a system consent prompt make it a different product.

## I1. Core — `jala_core`, runs alone

- `JalaThrottledSocket` — a `Socket` decorator that paces reads and writes
  through the existing `JalaThrottleRegistry.paceFor`. No new profile model:
  `JalaThrottleProfile` already carries latency, jitter, both bandwidth
  directions and drop rate.
- `JalaSocketThrottle.connectionFactory(...)` — a factory matching
  `HttpClient.connectionFactory`'s signature that consults the registry,
  applies connect latency, fails the connection outright when `shouldDrop`,
  and otherwise returns a wrapped `ConnectionTask<Socket>`.
- Host scoping comes free: `connectionFactory` receives the `Uri`, so
  `hostMatches` applies exactly as it does today.

**Interface width is *not* the main cost — measured, see Open question 1.**
An earlier draft called it that, on the reasoning that `Socket` is a large
interface (`Stream<Uint8List>` + `IOSink` + address/port/option members).
Extending `StreamView<Uint8List>` collapses the `Stream` half to a single
`listen`, leaving ~21 members to write by hand rather than ~140.

The hazard is narrower than "wide interface" and should be tested as such: a
missed `setOption` or a mishandled `destroy` still breaks the host app's
networking, which violates the project's "capture never breaks host
networking" invariant. Test the delegation surface exhaustively — every
member forwarding correctly with throttling *off*, proving the decorator is
transparent — not just the pacing.

`dart:io` in `jala_core` needs a conditional import — core is currently
Flutter-free *and* `dart:io`-free, and the web build must keep compiling.
Follow the `jala`-package pattern (`file_jala_mock_store_io.dart` /
`_stub.dart`).

## I2. Wiring — `jala` facade

- `Jala.enableSocketThrottling()` — opt-in, debug-only, sets
  `HttpOverrides.global`. **Never on by default**: it is process-wide and
  affects code that never asked for Jala.
- Must be idempotent and reversible (restore the previous overrides), and a
  no-op when the binding is disabled.
- **Adapter-level pacing must switch off while socket throttling is active**,
  or every call is charged twice. Per Open question 3 this is resolved by
  *replacement*, not coordination: when socket mode is on, the adapters skip
  latency, drop and pacing entirely and the socket layer owns all of it.
  One registry predicate (`JalaThrottleRegistry.socketModeActive`), consulted
  by the adapters, with a test asserting total elapsed time matches a single
  application of the cap.

## I3. UI + docs

- The throttle screen states which mode is active and what it covers
  ("adapter only" vs "all `dart:io` traffic").
- The per-entry throttle badge added in 0.8.0 already answers "did it apply
  to this call" and needs no change.
- `docs/CONFIG.md` / `ADOPTION.md` / `TROUBLESHOOTING.md`: what each mode
  covers, and a pointer to Network Link Conditioner for the rest.

## I4. Verification

The 0.8.0 audit is the template — measure, don't inspect:

- Elapsed time for a known payload at a known cap, asserted against both the
  app's observed wall time **and** `NetworkCallEntry.duration` (the 0.8.0
  bug was these two disagreeing by two seconds).
- `Image.network` under an active profile — the headline scope fix, and
  currently the most visible failure.
- Double-charge guard: adapter + socket throttling both configured, total
  elapsed still matches one application.
- Socket delegation: every `Socket` member forwards correctly with
  throttling off, proving the decorator is transparent.
- On-device smoke on real hardware, per the standing rules.

## Open questions

1. Is the scope fix (images, unattached clients) worth the `Socket`
   decoration risk on its own? If the honest answer is "developers reach for
   Network Link Conditioner anyway", the cheaper move is documentation plus
   a UI note that throttling covers attached clients only.

   **Measured 2026-08-11 against the Dart SDK in this repo (3.41.9) — the
   decoration risk is roughly 6x smaller than this plan assumed, so the
   argument that was supposed to kill the track is much weaker than
   written.**

   I1 above says `Socket` "is a large interface … tedious and easy to get
   subtly wrong", and calls that the main cost. That is true of the
   *interface* and false of the *work*. `Socket implements
   Stream<Uint8List>, IOSink`, and `Stream` alone declares ~119 members —
   but `dart:async` ships `class StreamView<T> extends Stream<T>`
   (`async/stream.dart:2309`), which implements every one of them by
   forwarding to an inner stream and needs only `listen`. So

   ```dart
   class _ThrottledSocket extends StreamView<Uint8List> implements Socket
   ```

   leaves a hand-written surface of about **21 members**, not ~140:

   - `Socket`'s own (10): `destroy`, `setOption`, `setRawOption`,
     `addError`, `port`, `remotePort`, `address`, `remoteAddress`, `close`,
     `done`
   - `IOSink` (11): `add`, `write`, `writeAll`, `writeln`, `writeCharCode`,
     `addError`, `addStream`, `flush`, `close`, `done`, `encoding`

   Both hooks are confirmed present as described: `connectionFactory`
   (`_http/http.dart:1547`) and `HttpOverrides.global`
   (`_http/overrides.dart:44`).

   The repo also already has this decorator shape twice, so it is not new
   ground: `_CapturingWebSocketSink implements WebSocketSink` and
   `JalaWebSocketChannel extends StreamChannelMixin`
   (`packages/jala_websocket/lib/src/jala_web_socket_channel.dart`).

   **What stays genuinely risky is not interface width:**

   - The **double-charge trap** already named in I2 — adapter pacing and
     socket pacing both applying to one call. One flag, checked in two
     places, with a test asserting total elapsed time matches a single
     application of the cap. This is the real correctness hazard.
   - **`jala_core` is currently `dart:io`-free**, so this needs a
     conditional import there following the
     `file_jala_mock_store_io.dart` / `_stub.dart` pattern in `jala`.
   - `setOption` / `setRawOption` semantics on a wrapped socket, which have
     no analogue in the existing WebSocket decorators.

   None of that is a reason not to start; all three are testable. **The
   decision this question was waiting on is therefore unblocked** — what
   remains is a scheduling call, not a feasibility one.
2. ~~`HttpOverrides.global` opt-in, or automatic wiring from
   `Jala.initialize`?~~ **Not actually open — I2 already answers it:
   "Never on by default: it is process-wide and affects code that never
   asked for Jala."** Opt-in via `Jala.enableSocketThrottling()`, closed.

3. ~~Replace the adapter-level path for `dart:io`, or run two mechanisms
   behind a flag?~~ **Answered 2026-08-12: replace.**

   The question mis-stated its own tradeoff. "Loses the web fallback" is
   false — web has no `dart:io` at all, so `HttpOverrides` and
   `connectionFactory` do not exist there. Scoping the replacement to
   platforms that *have* `dart:io` leaves web on the adapter path
   automatically. There is no fallback to lose.

   With that corrected the choice is one-sided: replacing **deletes the
   double-charge trap** that I2 calls "the sharpest correctness trap in the
   track", before a line of it is written. Running both behind a flag buys
   nothing and costs the bug most likely to ship.

   Concretely: while socket throttling is active, the adapters must skip
   their own latency/drop/pacing entirely rather than coordinating with it.
   One registry predicate, consulted by the adapters, is the whole
   mechanism.
