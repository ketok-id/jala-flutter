# jala_graphql

**GraphQL** adapter for Jala (`gql_link`): captures query / mutation /
subscription with operation name, query text, variables, `data`/`errors`,
and a per-subscription payload timeline.

Works with **`graphql_flutter`**, **ferry**, and any `gql_link` chain.

> [What is Jala?](../../README.md) · [Package map](../../docs/packages.md) ·
> [Doc index](../../docs/README.md)

| | |
|---|---|
| **Audience** | Apps using GraphQL over `gql_link` |
| **Depends on** | `jala_core`, `gql` / `gql_exec` / `gql_link` |
| **Lockstep** | `0.8.x` — [COMPAT.md](../../docs/COMPAT.md) |
| **Requires** | Dart `^3.11` |

Wire the facade with [`jala`](../jala). Brownfield:
[ADOPTION.md](../../docs/ADOPTION.md#graphql).

---

## Install

```yaml
dependencies:
  jala: ^0.8.0
  jala_graphql: ^0.8.0
```

## Setup

Insert `JalaGraphQLLink` **before** the terminating link:

```dart
import 'package:gql_link/gql_link.dart';
import 'package:jala_graphql/jala_graphql.dart';

final uri = Uri.parse('https://api.example.com/graphql');
final link = Link.from([
  JalaGraphQLLink(endpoint: uri),
  HttpLink(uri.toString()),
]);
```

Pass `endpoint` so list/detail show the real URL. If omitted, entries use
placeholder `graphql://unknown-endpoint` (URI is required on the model).

---

## Public API

| API | Role |
|---|---|
| `JalaGraphQLLink({Uri? endpoint})` | Capture link; place before terminating link |

---

## What gets captured

- `operationName` / `operationType` (`query` / `mutation` / `subscription`)
- Request body as GraphQL-over-HTTP JSON (`operationName`, `query`,
  `variables`) — redacted via `JalaRedactor` body patterns
- Response as `{"data":…,"errors":…}`; GraphQL errors still use HTTP 200
  with `statusMessage: 'GraphQL errors'` when transport succeeded
- Transport failures → `NetworkErrorEvent` like other adapters

### Subscriptions

- Request event when the subscription starts (pending row immediately)
- Each payload → `NetworkSubscriptionPayloadEvent` ring
  (`maxSubscriptionPayloads`, default 50)
- Filter: `is:subscription`; Response tab shows the timeline
- Completion response uses first payload body; duration is open→close

---

## Double-capture (read this)

If the terminating `HttpLink` / ferry transport uses a `Dio` or
`http.Client` that you **also** attached with `JalaDio.attach` /
`JalaHttp.wrap`, each operation appears **twice** (GraphQL + raw HTTP POST).

| Goal | Do this |
|---|---|
| GraphQL-aware UI | Use `JalaGraphQLLink`; do **not** attach Jala on that transport’s Dio/http |
| Raw HTTP only | Attach Dio/http; skip `JalaGraphQLLink` |
| Both (noise OK) | Keep both; filter `is:graphql` / `-is:graphql` |

---

## Production safety

- No-op when `!isEnabled` (`forward(request)` only)
- Capture never drops or duplicates the real GraphQL stream
- Body caps + redaction — [CONFIG.md](../../docs/CONFIG.md)

---

## See also

- [docs/ADOPTION.md](../../docs/ADOPTION.md#graphql)  
- [docs/TROUBLESHOOTING.md](../../docs/TROUBLESHOOTING.md)  
- [CHANGELOG.md](CHANGELOG.md)
