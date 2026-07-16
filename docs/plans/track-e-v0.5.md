# Track E — v0.5.0: power tools (throttling, session share, subscription payloads)

Scope decision (user, 2026-07-16): stay in the network lane while adoption
grows. Three features, no new packages, no new brand surface. Two of the
three are category-firsts (research: no in-app Flutter tool has throttling
or session sharing).

Execution order (proven pattern): E1 core alone first (one executor), then
E2 adapters and E3 UI as parallel executors (adapters and UI both depend
only on core), then E4 example/smoke/release. No new packages → no
publisher transfers this time.

## E1. Core (`jala_core`) — one executor, runs alone

**Throttle model.** `JalaThrottleProfile {id, name, latencyMs, jitterMs?,
downloadBytesPerSec?, uploadBytesPerSec?, dropRate (0..1)}` with const
presets: `slow3g` (400ms ±100, 50 KB/s down, 25 KB/s up), `fast3g`
(150ms ±50, 180 KB/s down), `flaky` (200ms ±200, drop 0.15), `offline`
(drop 1.0). `JalaThrottleRegistry` on the binding: `activeProfile`
(nullable = off), `hostPattern` (glob, null = all hosts), setter emits on a
`Stream<JalaThrottleProfile?> watch` for the UI banner, `shouldDrop()`,
`latencyFor()`, `paceFor(bytes, perSec) -> Duration` helpers. Active only
while `isEnabled` — a disabled binding always reports "off".

**Session codec.** `JalaSessionCodec.encode(store) -> String` /
`decode(String) -> JalaSession {version, exportedAt, entries,
wsConnections}` — versioned JSON envelope (`"jala-session"` marker field,
version 1). Round-trips every field of `NetworkCallEntry` (incl. captured
bodies — image bytes as base64, note size cost — operation metadata, mock
tags, progress dropped as transient) and `WsConnectionEntry` + frames.
Decode is defensive: unknown version or malformed → typed
`JalaSessionFormatException`, never a crash. `NetworkCallEntry` gains
`imported: bool` (default false, set by the store's import path only).

**Import path.** `JalaStore.importSession(JalaSession, {append = false})` —
default replaces current contents, sets `imported: true` on every imported
entry, emits on existing watch streams. `JalaStore.isViewingImport` flag +
cleared by `clear()`.

**Subscription payloads.** New event `NetworkSubscriptionPayloadEvent
{callId, seq, body: CapturedBody, timestamp}`; `NetworkCallEntry.payloads:
List<CapturedBody>` ring-capped by new `JalaConfig.maxSubscriptionPayloads`
(default 50) with `payloadCount` keeping the true total (mirror the WS
frame pattern). Filter grammar: `is:subscription` (operationType ==
'subscription').

Tests: profile preset values, registry watch/off-when-disabled, drop/pace
math, codec round-trip (incl. image bytes, ws frames, unicode), forward-
compat decode failure, import replace/append + imported flag, payload ring
cap. Target similar coverage to D1.

## E2. Adapters (`jala_dio`, `jala_http`, `jala_graphql`) — after E1

- **Throttling, jala_dio:** in `onRequest`, if registry active and host
  matches: `shouldDrop()` → reject with a connection-error DioException
  (entry records error, tagged `throttledBy: profileId` — add optional
  field on request event/entry in E1 if missed); else await latency.
  Bandwidth pacing only where the interceptor sees a stream
  (ResponseType.stream): wrap with timed chunk emission via `paceFor`.
  Document honestly: full-body dio responses get latency+drop only.
- **Throttling, jala_http:** latency+drop before `_inner.send`; pacing in
  the existing response tee (delay between chunk forwards) and request
  stream wrapper — http gets the complete treatment.
- **Subscription payloads, jala_graphql:** emit
  `NetworkSubscriptionPayloadEvent` per payload (body via
  CapturedBody.capture, seq increments), keep the existing completion
  event; remove the `{"@subscription": {"payloads": N}}` body convention
  (superseded — update its tests).
- Tests per adapter: drop produces error entry with tag; latency measurably
  delays (fake clock or generous bounds); pacing splits emission (http);
  disabled registry = zero added latency; graphql payload seq/cap.

## E3. UI (`jala_ui`) — after E1, parallel with E2

- **Throttle screen** off the inspector AppBar (speed icon): preset list
  with radio selection, "Off", custom profile editor (latency/jitter/
  bandwidth/drop sliders), host-pattern field. Active profile → persistent
  **banner** at the top of the inspector list ("Throttling: Slow 3G — tap
  to change") and a badge on the AppBar icon.
- **Session actions:** AppBar overflow menu: "Export session" (encodes via
  codec → Clipboard + snackbar with entry count; facade file-save comes via
  the example recipe, keep share_plus OUT of jala_ui) and "Import session"
  (paste-JSON dialog → store.importSession, replace/append choice). While
  `isViewingImport`: banner "Imported session (N entries) — Clear to return
  to live capture"; Replay / Mock-this / Edit-and-resend disabled on
  `imported` entries (tooltip explains why).
- **Subscription detail:** Response tab for `is:subscription` entries shows
  a payload timeline (seq, relative time, size; tap → body view — reuse the
  WS frame list pattern) with the trimmed-count note.
- Widget tests: preset selection activates banner; export puts versioned
  JSON on clipboard; import round-trip renders entries with disabled replay
  + banner; payload timeline renders/expands; `is:subscription` filter.

## E4. Example, smoke, release — after E2+E3

- Example: "Power tools" section — activate Slow 3G then fire Large
  (visible slowdown + progress), export session → import it back (paste
  flow), subscription demo only if a public GraphQL subscription endpoint
  is practical (else skip — do NOT stand up infrastructure for a demo).
- Integration smoke (store-only, per pattern): throttle drop + latency
  assertions with `flaky`/`offline`; codec round-trip through a real
  captured session on-device.
- Live smoke on simulator + real Android (remember the MIUI notes in
  memory: watch for install prompt; blank screen during store-only smokes
  is expected).
- Release: lockstep 0.5.0 ×7, CHANGELOGs, README (throttling + session
  share rows in comparison table — verify incumbents still lack them;
  filter grammar `is:subscription`; roadmap refresh), `--fatal-infos`,
  dry-runs ×7, publish core → adapters/ui → jala. No publisher transfers
  needed (no new packages).

## Explicitly out of scope (v0.5)

- HAR *import* (export exists; import is a different beast — v0.6
  candidate with session-share feedback).
- Per-request throttle rules (global profile + host pattern only; rules
  engine belongs with mocking if demand appears).
- WS throttling (frames pass through untouched; document).
- share_plus / file-picker dependencies in jala_ui (example shows the
  recipe with the facade instead).
