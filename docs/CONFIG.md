# Configuration reference

How to configure capture, caps, and redaction via `JalaConfig` /
`JalaRedactor`.

Lockstep packages: **0.7.x**. Threat model and residual risks:
[SECURITY.md](SECURITY.md). Missing traffic or tokens:
[TROUBLESHOOTING.md](TROUBLESHOOTING.md).

---

## Initialize

```dart
import 'package:flutter/foundation.dart';
import 'package:jala/jala.dart';
import 'package:jala_core/jala_core.dart';

void main() {
  // Default: enabled only in debug.
  Jala.initialize();

  // Or explicit:
  Jala.initialize(
    config: JalaConfig(
      enabled: kDebugMode,
      // …see fields below
    ),
  );
}
```

Notes:

- Call **once** at app start (e.g. `main` or a debug bootstrap).
- `initialize` is **idempotent**: later calls are ignored; the **first**
  config wins. Change config → **hot restart** (not hot reload).
- Core default without the facade is `enabled: false`. The `jala` facade
  defaults to `kDebugMode` when you omit `config`.

---

## `JalaConfig` fields

| Field | Default | Meaning |
|---|---|---|
| `enabled` | facade: `kDebugMode`; core: `false` | Master switch. When false, adapters no-op; overlay returns child. |
| `maxEntries` | `300` | HTTP/GraphQL ring buffer size |
| `maxBodyBytes` | `512 * 1024` | Per request/response body capture cap |
| `captureImageBodies` | `true` | Keep `image/*` bytes for inline preview (within cap) |
| `maxWsConnections` | `20` | WebSocket connection ring size |
| `maxWsFramesPerConnection` | `200` | Frames kept per WS connection |
| `maxSubscriptionPayloads` | `50` | GraphQL subscription payload ring per call |
| `redactor` | `JalaRedactor()` | Capture-time redaction (see below) |

---

## Redaction model

Redaction runs in **adapters before data enters `JalaStore`**. There is
**no UI “reveal”** and no way to recover a masked value later.

Replacement string: `JalaRedactor.mask` → `••••••`.

### Version matrix

| Capability | Since |
|---|---|
| Header redaction + custom body patterns | **0.1.0** |
| Expanded default headers; default JSON/form secret keys; `includeDefaultBodyPatterns` | **0.5.3** |
| URL query redaction (`redactedQueryParams`, `redactUri`); replay strips masked query params | **0.7.0** |

### `JalaRedactor` constructor

```dart
JalaRedactor({
  Set<String> redactedHeaders = JalaRedactor.defaultRedactedHeaders,
  List<Pattern> redactedBodyPatterns = const <Pattern>[],
  Set<String> redactedQueryParams = JalaRedactor.defaultRedactedQueryParams,
  bool includeDefaultBodyPatterns = true,
});
```

| Parameter | Behavior |
|---|---|
| `redactedHeaders` | Case-insensitive header **names**; values → mask |
| `redactedQueryParams` | Query param **names** (case / `-` / `_` normalized); values → mask |
| `includeDefaultBodyPatterns` | When true, mask common JSON/form secret keys |
| `redactedBodyPatterns` | Extra `Pattern`s applied after defaults |

---

## Defaults (what is masked out of the box)

### Headers (`defaultRedactedHeaders`)

`authorization`, `proxy-authorization`, `cookie`, `set-cookie`,
`x-api-key`, `api-key`, `x-auth-token`, `x-access-token`,
`x-refresh-token`, `x-csrf-token`, `x-xsrf-token`, `x-session-token`,
`x-session-id`, `x-amz-security-token`.

### Body keys (when `includeDefaultBodyPatterns: true`)

JSON string members and form-style pairs for names such as:
`password`, `passwd`, `pwd`, `secret`, `token`, `access_token`,
`refresh_token`, `id_token`, `api_key`, `client_secret`, `private_key`,
`auth_token`, `session_token`, `bearer`, `client_id` (and common
underscore/hyphen variants). Full regexes live on `JalaRedactor` in
`jala_core`.

### Query parameters (`defaultRedactedQueryParams`, 0.7+)

Includes `token`, `access_token`, `refresh_token`, `api_key`,
`client_secret`, `signature` / AWS-style signature params, etc.
Empty values (`?token=`) are left alone. Bare `key`, `code`, and
`client_id` are **not** default query masks (too generic / public).

Full lists: [SECURITY.md](SECURITY.md).

---

## Recipes

### Safer company defaults (add more secrets)

```dart
Jala.initialize(
  config: JalaConfig(
    enabled: kDebugMode,
    redactor: JalaRedactor(
      redactedHeaders: {
        ...JalaRedactor.defaultRedactedHeaders,
        'x-company-token',
        'x-device-secret',
      },
      redactedBodyPatterns: [
        RegExp(r'"ssn"\s*:\s*"[^"]*"', caseSensitive: false),
      ],
    ),
  ),
);
```

### Show real tokens (debug only)

Use only on trusted machines. Screenshots, session export, and cURL will
contain live credentials.

```dart
Jala.initialize(
  config: JalaConfig(
    enabled: true,
    redactor: JalaRedactor(
      redactedHeaders: const <String>{},
      redactedQueryParams: const <String>{},
      includeDefaultBodyPatterns: false,
      redactedBodyPatterns: const <Pattern>[],
    ),
  ),
);
```

### Unmask only Authorization (keep other defaults)

```dart
Jala.initialize(
  config: JalaConfig(
    enabled: kDebugMode,
    redactor: JalaRedactor(
      redactedHeaders: {
        ...JalaRedactor.defaultRedactedHeaders,
      }..removeAll({'authorization', 'proxy-authorization'}),
    ),
  ),
);
```

Requires **0.7.0+** if you also pass `redactedQueryParams`. Header-only
customization works from **0.1.0**; body-default toggle from **0.5.3**.

---

## UI notes (not config)

- Cookie / Authorization rows are **collapsed** under **Sensitive** in the
  headers table by default — expand to see the (already redacted or real)
  value.
- Changing the redactor does not rewrite **already stored** entries. Fire
  a new request after hot restart.

---

## Replay interaction

When a stored header or query value is the mask, replayers **drop** that
header/param rather than send `••••••` as a credential. If you disabled
redaction, real values are stored and can be resent.

---

## See also

- [SECURITY.md](SECURITY.md) — threat model, exports, mocks  
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — token not visible  
- [overview.md](overview.md) — capture pipeline  
