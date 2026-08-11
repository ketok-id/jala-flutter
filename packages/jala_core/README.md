# jala_core

Pure-Dart engine for **Jala**: models, event bus, ring-buffer store,
capture-time redaction, filter grammar, exporters, import codecs, mocks,
throttle, session codec, and call/JSON diff.

**Zero Flutter dependency.** Suitable for adapters, CLI tooling, and tests.

> [What is Jala?](../../README.md) · [Package map](../../docs/packages.md) ·
> [Doc index](../../docs/README.md)

| | |
|---|---|
| **Audience** | Adapter authors, headless tooling — **not** a typical app install |
| **Depends on** | Dart only (`dart:core` / `dart:convert`) |
| **Lockstep** | `0.8.x` — [COMPAT.md](../../docs/COMPAT.md) |
| **Requires** | Dart `^3.11` |

**Building an app?** Install [`jala`](../jala) instead (pulls in UI + core).

**Config / redactor:** [CONFIG.md](../../docs/CONFIG.md) ·
**Security:** [SECURITY.md](../../docs/SECURITY.md) ·
**Architecture:** [overview.md](../../docs/overview.md)

---

## Install

```yaml
dependencies:
  jala_core: ^0.8.1
```

## Setup (without Flutter)

```dart
import 'package:jala_core/jala_core.dart';

JalaBinding.instance.initialize(config: JalaConfig(enabled: true));

// Adapters emit into the bus; UI and tools read the store.
final entries = JalaBinding.instance.store.entries;
final filter = JalaFilter.parse('method:post s:error');
final matches = entries.where(filter.matches);

print(CurlExporter.export(matches.first));
```

Apps should call `Jala.initialize()` from package `jala`, which initializes
the same binding.

---

## Public surface (main types)

| Class | Role |
|---|---|
| `JalaBinding` | Process-wide singleton: config, bus, store, replay/mock/throttle registries |
| `JalaConfig` | `enabled`, caps, `redactor` — see [CONFIG.md](../../docs/CONFIG.md) |
| `JalaRedactor` | Capture-time header / body / query redaction |
| `JalaEvent` / `JalaEventBus` | Sealed capture events; no-op when disabled |
| `JalaStore` | Ring buffer of `NetworkCallEntry` + parallel WS connections |
| `NetworkCallEntry` / `CapturedBody` | One HTTP/GraphQL call and capped bodies |
| `WsConnectionEntry` / `WsFrame` | WebSocket connection + frame timeline |
| `JalaFilter` | DevTools-style query → `matches` / `matchesWs` |
| `JalaReplayRegistry` / `JalaReplayer` | Single active replayer (last wins) |
| `JalaMockRegistry` / `JalaMockRule` | Ordered mock rules |
| `JalaThrottleRegistry` / `JalaThrottleProfile` | Latency / drop / bandwidth profiles |
| `CurlExporter` / `DartSnippetExporter` / `HarExporter` | Export |
| `JalaCurlCodec` / `JalaHarCodec` | Import |
| `JalaSessionCodec` / `JalaSessionExportOptions` | Session JSON share |
| `JalaJsonDiff` / `JalaEntryDiff` | Structural diffs |

Semver surface = barrel `lib/jala_core.dart`. Prefer that over `src/`.

---

## Filter grammar

`JalaFilter.parse(query)` — space-separated terms, AND semantics, leading
`-` negates. Case-insensitive; malformed structured terms degrade to free
text.

| Term | Matches |
|---|---|
| `method:get` / `m:get` | HTTP method; comma list (`m:get,post`) |
| `status:404` / `s:404` | Exact status |
| `status:4xx` | Class; also `s:error`, `s:pending` |
| `host:api.example.com` / `d:` | Host; `*` wildcard |
| `path:/users` | Path substring |
| `type:json` / `t:json` | Response content-type substring |
| `larger-than:10k` | Response size (`k`/`m` suffixes) |
| `slower-than:500` | Duration (ms) |
| `is:replay` / `is:mocked` | Replay / mock flags |
| `is:graphql` / `is:subscription` / `is:ws` | Protocol surfaces |
| `op:<name>` | GraphQL operation name (`*` ok) |
| `body:token` | Body text substring |
| bare word | Method + full URL substring |
| `-<term>` | Negation |

Example: `method:get status:4xx larger-than:10k -host:*.cdn.com`.

---

## Invariants

Documented fully in [overview.md](../../docs/overview.md):

1. No-op when disabled  
2. Capture never breaks host networking  
3. Redaction at capture (no reveal)  
4. Hard body caps  
5. UI (in other packages) owns theme/navigator  

---

## See also

- [docs/CONFIG.md](../../docs/CONFIG.md) · [docs/SECURITY.md](../../docs/SECURITY.md)  
- [docs/SPEC-v0.1.md](../../docs/SPEC-v0.1.md) — original binding contract  
- [CHANGELOG.md](CHANGELOG.md)
