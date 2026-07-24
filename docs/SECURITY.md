# Security model — Jala

Jala is an **in-app network inspector** for Flutter. It observes traffic inside
the host app process; it is not a perimeter firewall, vault, or remote
security product.

This document describes defaults, residual risks, and recommended
configuration. Package version context: **0.6.0+**.

---

## Threat model (summary)

| Actor | Concern |
|---|---|
| Public store / end user | Inspector must not capture traffic unless explicitly enabled |
| Screenshot / screen share / debugger | Secrets must not sit in the store unmasked |
| Session clipboard / ticket paste | Exports may still contain business or personal data |
| Debug mock rules on disk | Local file may describe endpoints and canned responses |

---

## Guarantees (defaults)

### Production posture

- **`jala` facade:** `Jala.initialize()` uses `enabled: kDebugMode` unless you
  pass a custom [JalaConfig].
- **`jala_core`:** `JalaConfig(enabled: false)` if you wire the binding yourself.
- When **disabled**: adapters skip capture (true no-op on the hot path);
  `JalaOverlay` returns the child unchanged; `Jala.open()` is a no-op.
- **Mocking and throttling** only apply while enabled.

### Capture-time redaction

Redaction runs in adapters **before** data enters [JalaStore] — not only in
the UI.

**Default redacted headers** (case-insensitive; value → `••••••`):

- `authorization`, `proxy-authorization`
- `cookie`, `set-cookie`
- `x-api-key`, `api-key`, `x-auth-token`
- `x-access-token`, `x-refresh-token`
- `x-csrf-token`, `x-xsrf-token`
- `x-session-token`, `x-session-id`
- `x-amz-security-token`

**Default body patterns** (enabled unless you set
`includeDefaultBodyPatterns: false`):

- JSON string members: `password`, `passwd`, `pwd`, `secret`, `token`,
  `access_token` / `access-token`, `refresh_token`, `id_token`, `api_key` /
  `apiKey`, `client_secret`, `private_key`, `auth_token`, `session_token`,
  `bearer`, `client_id` (and common underscore/hyphen variants).
- Form / query-style pairs: same key names as `key=value`.

**Replay** drops headers whose stored value is the redaction mask — Jala never
had the secret to resend.

### Size limits

- Captured bodies: **512 KB** default (`JalaConfig.maxBodyBytes`).
- Store ring buffers: entries, WS frames, subscription payloads.
- Session **import**: max **8 MiB** of JSON text
  (`JalaSessionCodec.defaultMaxDecodeChars`) to limit pathological pastes.

### Host app integrity

Capture, mock, and throttle paths are designed so a bug in Jala should not
break Dio / `http` / GraphQL / WebSocket traffic (`try`/`catch` around
capture).

### Supply chain

- No analytics, phone-home, or remote config in these packages.
- Small dependency sets (dio / http / gql_* / web_socket_channel / Flutter).
- Published under verified publisher **ketok.id**.

---

## Residual risks (not fully mitigated by defaults)

| Risk | Why |
|---|---|
| Secrets in **non-standard headers** | Only the default name set is masked |
| Secrets in **bodies** with unusual key names | Defaults cover common keys only |
| **`enabled: true` in production** | Full (post-redaction) traffic held in memory |
| **Session export** | Clipboard JSON can include PII / business data |
| **Mock persistence file** | `{dir}/jala_mock_rules.json` is plaintext |
| **Screenshots of the inspector** | UI can still show non-redacted fields |
| **Image bodies** | `captureImageBodies: true` by default (within size cap) |

Jala is **not** a compliance product. Enabling capture in regulated environments
requires your own privacy review.

---

## Recommended configuration

```dart
import 'package:jala/jala.dart';
import 'package:jala_core/jala_core.dart';

void installJala() {
  Jala.initialize(
    config: JalaConfig(
      // Prefer default: enabled: kDebugMode via Jala.initialize() with no args.
      enabled: kDebugMode,
      redactor: JalaRedactor(
        // Merge company headers onto defaults by re-listing defaults + extras:
        redactedHeaders: {
          ...JalaRedactor.defaultRedactedHeaders,
          'x-company-token',
          'x-device-secret',
        },
        // Defaults already redact common password/token JSON keys.
        // Add org-specific string/regexp patterns as needed:
        redactedBodyPatterns: [
          RegExp(r'"ssn"\s*:\s*"[^"]*"', caseSensitive: false),
        ],
      ),
      // Optional: captureImageBodies: false,
    ),
  );
}
```

### Session share

| Mode | API | Use when |
|---|---|---|
| Full | `JalaSessionCodec.encode(store)` or UI **Export (full)** | Trusted eng channel only |
| No bodies | `options: JalaSessionExportOptions.noBodies` | Debugging status/headers without payloads |
| Headers only | `JalaSessionExportOptions.headersOnly` | Safest default for tickets |
| Strip images | `JalaSessionExportOptions.stripImages` | Keep text, drop image bytes |

Treat any export like a **log dump**: ticket ACLs, no public pastebins.

### Mock persistence

```dart
await Jala.enableMockPersistence(dir.path); // only when enabled
```

- Writes `jala_mock_rules.json` under the path you pass.
- Intended for **developer machines / internal builds**, not end-user devices.
- No encryption; protect the directory like other app support files.

---

## UI privacy helpers (0.5.2+)

- Sensitive headers (cookie / authorization) collapsed under **Sensitive**.
- Common noise headers collapsible.
- Floating bubble hidden while the inspector is open (reduces accidental
  overlap; not a security boundary).

---

## Reporting issues

Report security concerns via the GitHub issue tracker:
https://github.com/ketok-id/jala-flutter/issues

Please do **not** attach real production session exports containing customer
data.

---

## Related docs

- [ADOPTION.md](ADOPTION.md) — brownfield install + PR checklist  
- [COMPAT.md](COMPAT.md) — version lockstep  
- Package READMEs under `packages/*`
