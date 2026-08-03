# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Jala — an in-app network inspector for Flutter, published on pub.dev under
the `ketok.id` publisher. A Dart **pub workspace** (root `pubspec.yaml`,
`name: jala_workspace`, `publish_to: none`) holding seven publishable
packages plus a QA example app. Dart `^3.11.0`, Flutter `>=3.35.0`.

## Commands

```bash
flutter pub get                       # resolves the whole workspace (one lockfile at root)
dart analyze --fatal-infos            # CI gate; run from root

# Tests — pure-Dart packages use `dart test`, Flutter packages `flutter test`
(cd packages/jala_core && dart test)
(cd packages/jala_dio && dart test)          # also: jala_http, jala_graphql, jala_websocket, jala_grpc
(cd packages/jala_ui && flutter test)        # also: jala, examples/jala_example

# Single file / single test
(cd packages/jala_core && dart test test/jala_filter_test.dart -n 'status class')
(cd packages/jala_ui && flutter test test/jala_json_tree_test.dart --plain-name 'expands')

# Example app (manual QA rig)
(cd examples/jala_example && flutter run -d macos)   # or chrome / ios / android

# On-device smokes (need a real device or simulator; not run in CI)
(cd examples/jala_example && flutter test integration_test/track_f_smoke_test.dart)

# Before a release
(cd packages/jala_core && dart pub publish --dry-run)
```

CI (`.github/workflows/ci.yaml`) runs exactly: `flutter pub get`,
`dart analyze --fatal-infos`, then each package's suite in the order above.
`deploy-demo.yaml` builds `examples/jala_example` for web on every push to
`main` and publishes it to GitHub Pages.

## Architecture

### Package layering (dependency direction is strict)

```
jala (facade, Flutter)  →  jala_ui  →  jala_core
jala_dio / jala_http / jala_graphql / jala_websocket / jala_grpc
                                                     →  jala_core
```

- `jala_core` is **pure Dart with zero Flutter dependency** — models, event
  bus, store, redaction, filter grammar, exporters, import codecs, diff,
  mocks, throttle, session codec. Never add a Flutter import here.
- Adapters (`jala_dio`, `jala_http`, `jala_graphql`, `jala_websocket`,
  `jala_grpc`) depend only on `jala_core` and their client library. They
  never import `jala_ui` or `jala`.
- `jala_ui` owns all screens/widgets; `jala` is a thin static facade
  (`Jala.initialize`, `Jala.open/close`, `JalaOverlay`) plus the only
  `dart:io` conditional-import in the tree (file-backed mock persistence).

### The binding singleton is the wiring

`JalaBinding.instance` (`jala_core/lib/src/binding/jala_binding.dart`) is a
process-wide singleton holding config, event bus, store, replay registry,
mock registry, and throttle registry. Adapters **read the binding at call
time rather than taking constructor parameters**, so one
`Jala.initialize()` in the host app configures every attached client. Before
`initialize()` the binding exists but `isEnabled` is false and every capture
path is a true no-op. `JalaBinding.resetForTesting()` swaps in a fresh
instance and disposes the old one.

### Capture flow

Adapter hook → `JalaEventBus.emit(JalaEvent)` → `JalaStore` correlates by
`callId` into a `NetworkCallEntry` → `store.watch` stream → UI.

- `JalaEvent` is a sealed hierarchy (`NetworkRequestEvent`,
  `NetworkResponseEvent`, `NetworkErrorEvent`, `NetworkCancelEvent`,
  `NetworkProgressEvent`, plus WS/subscription events). Every event carries
  `callId`; that id becomes `NetworkCallEntry.id`.
- `JalaStore` is a newest-first ring buffer (`maxEntries`, default 300).
  Eviction prefers the oldest **completed** entry; pending entries are only
  evicted when nothing completed remains. Events for an unknown/evicted id
  are silently dropped.
- WebSocket connections live in a **parallel** collection
  (`store.wsConnections` / `watchWs`) with their own caps and eviction —
  they are never merged into `entries`; the merged view is a UI-level
  concern.

### Invariants that constrain how adapter code is written

These are product promises, not style preferences — preserve them in any
change to a capture path:

1. **True no-op when disabled.** The first line of every hook checks
   `JalaBinding.instance.isEnabled` and forwards immediately if false.
   `JalaOverlay` returns its child unchanged.
2. **Capture never breaks host networking.** Capture work is wrapped in
   `try`/`catch`, and the request/response/error is forwarded to the next
   interceptor **exactly once** regardless of whether capture succeeded.
3. **Redaction happens at capture time.** Headers/bodies are masked before
   the event is emitted, so raw secrets never enter the store and there is
   no "reveal" path. See `JalaRedactor`.
4. **Hard body caps.** `CapturedBody` truncates at `maxBodyBytes`
   (512 KB default).
5. **The inspector owns its own theme and navigator.** `jala_ui` screens
   wrap in `JalaThemedPage`/`JalaThemeScope` and never inherit the host
   `Theme`; `JalaOverlay` mounts a private `Navigator` and its own
   `Localizations` (it is a *sibling* of the host app, so it can't inherit
   from a `MaterialApp` inside the child).

### Replay

`JalaReplayRegistry` holds a **single active replayer — last registration
wins**. `JalaDio.attach` / `JalaHttp.wrap` register one. Multi-client apps
must attach their primary client last (documented in `docs/ADOPTION.md`).
Replayed calls flow back through the adapter and are captured as fresh
entries with `replayOf` set. Imported (HAR/session) entries disable replay.

## Conventions

- **Lockstep versioning.** All seven packages share one version and bump
  together — read the current one from any `pubspec.yaml` rather than
  trusting a number written here. A release touches seven `pubspec.yaml`
  files (version *and* the inter-package `^x.y.z` constraints), seven
  `CHANGELOG.md` files, the READMEs, `docs/COMPAT.md` and `docs/ROADMAP.md`,
  and lands as its own `Release x.y.z: …` commit. `docs/COMPAT.md` is the
  0.x policy — note that a behavior change (its own example: "change
  default redaction") ships as a **minor**, not a patch.
- **Public API = the barrel.** Each package's `lib/<name>.dart` export list
  is the semver-covered surface; anything under `src/` reached by direct
  import is not.
- **`// SPEC-NOTE:` comments** mark deliberate deviations from or
  extensions to `docs/SPEC-v0.1.md` (the binding v0.1 contract). Follow the
  same convention when the spec is ambiguous or silent rather than
  silently improvising.
- **Lints.** Root `analysis_options.yaml` applies to all packages with
  `strict-casts`/`strict-raw-types`/`strict-inference` plus explicit rules
  (`prefer_final_locals`, `always_declare_return_types`,
  `prefer_single_quotes`, `sort_constructors_first`, `avoid_print`,
  `unawaited_futures`, …). Code is written with explicit types on locals —
  match that.
- **Commit subjects** are one short line prefixed by area:
  `jala_ui: F2 virtualize JalaJsonTree via flattened ListView`,
  `docs: plan Track F`, `examples: …`. No trailer footers.

## Testing notes

- `jala_core`, `jala_dio`, `jala_http`, `jala_graphql`, `jala_websocket`,
  `jala_grpc` use `package:test`; `jala_ui`, `jala`, and the example use
  `flutter_test`. Each has a `test/test_helpers.dart` with entry/event
  builders (`makeEntry`, `emitCompletedCall`, `initJalaBinding`) — use them
  instead of hand-rolling fixtures.
- Because the binding is a process-wide singleton, widget tests do
  `tearDown(JalaBinding.resetForTesting)`.
- `jala_ui` tests must call `setUpAll(configureJalaUiTests)` — it sets
  `EditableText.debugDeterministicCursor`, without which the filter
  `TextField`'s cursor animation makes `pumpAndSettle` hang forever.

## Docs

Doc hub: `docs/README.md`. Architecture for humans: `docs/overview.md` and
package map: `docs/packages.md`. Config/redaction: `docs/CONFIG.md`.
Common failures (interceptor order, missing tokens):
`docs/TROUBLESHOOTING.md`.

Larger feature work is planned per "track" in `docs/plans/track-*.md`
(A → 0.1, B → 0.2, C → 0.3, D → 0.4, E → 0.5, F → 0.6); `docs/ROADMAP.md`
is the status table and is where a track's target version is claimed —
check it before picking a version, since smaller releases land between
tracks and push the lettered ones later. `docs/SPEC-v0.1.md` is the original binding contract,
`docs/ADOPTION.md` is the brownfield-install guide, `docs/SECURITY.md`
covers redaction/export risks, `docs/COMPAT.md` the version policy.
