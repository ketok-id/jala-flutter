# Compatibility policy (0.x)

Jala is pre-1.0. This document states what consumers can rely on while the
packages remain on **0.x** lockstep versions (`jala`, `jala_core`,
`jala_dio`, `jala_http`, `jala_graphql`, `jala_websocket`, `jala_ui`).

## Lockstep versions

All seven packages share the same **major.minor** (and typically the same
patch). When you depend on more than one, pin them together:

```yaml
dependencies:
  jala: ^0.6.0
  jala_dio: ^0.6.0
  # if used:
  jala_http: ^0.6.0
  jala_graphql: ^0.6.0
  jala_websocket: ^0.6.0
```

Do not mix `0.5.x` adapters with `0.6.x` core/ui.

## What 0.x means here

| Change type | Example | How we ship it |
|---|---|---|
| Docs / pub metadata only | README, screenshots, topics | Patch (`0.5.0` → `0.5.1`) |
| New features, backward compatible | New filter term, optional field with default | Minor (`0.5` → `0.6`) preferred; sometimes patch if tiny |
| Breaking API or behavior | Rename public type, remove event field, change default redaction | Minor on 0.x (`0.5` → `0.6`) with CHANGELOG callout |

We follow [semver](https://semver.org/) with the usual **0.x exception**:
breaking changes may land in a minor bump until **1.0.0**. We still:

- Document breaks in each package `CHANGELOG.md`
- Prefer additive APIs over renames
- Keep production-safety defaults (`enabled: kDebugMode`, capture-time
  redaction, no-op when disabled)

## Runtime floors

| Constraint | Current (0.5.x) |
|---|---|
| Dart SDK | `^3.11.0` |
| Flutter (packages that need it: `jala`, `jala_ui`) | `>=3.35.0` |

Raising floors is a **minor** bump when it excludes previously supported
toolchains.

## Public API surface

Treat as public (semver-covered):

- Exports from each package’s library barrel (`jala.dart`, `jala_core.dart`, …)
- Documented constructors and members on those types

Treat as unstable / do not depend on:

- `src/` imports outside the published barrels
- Undocumented experimental symbols
- Exact wording of error strings / snackbars (unless a test API is documented)

## Adapter contracts

- **Capture** must never break host networking (try/catch on capture paths).
- **Replay** uses the last registered replayer (`JalaDio.attach` /
  `JalaHttp.wrap`). Multi-client apps should attach the primary client last
  or see [ADOPTION.md](ADOPTION.md).
- **Throttle** applies to HTTP adapters only; WebSocket frames are not
  throttled (documented on `jala_websocket`).

## After 1.0

At 1.0 we will:

- Treat minor bumps as non-breaking
- Use major bumps for intentional breaks
- Keep lockstep across the seven packages unless a package is split out
  with its own stability promise

## See also

- [ADOPTION.md](ADOPTION.md) — brownfield install
- [ROADMAP.md](ROADMAP.md) — tracks and horizon
