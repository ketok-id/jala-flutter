# jala_graphql

GraphQL integration for Jala, the in-app Flutter network inspector: captures
every GraphQL operation (query/mutation/subscription) sent through any
`gql_link`-based client — including `graphql_flutter` and `ferry`, both of
which are built on `gql_link` — with operation name, pretty-printed query
text, variables, and the response's `data`/`errors`.

See the [repo README](../../README.md) for what Jala is and why (replay,
filter grammar, redaction-by-default) and the [`jala`](../jala) package
for the facade that wires this up in an app.

## Install

```yaml
dependencies:
  jala_graphql: ^0.4.0   # requires jala_core ^0.3.0
```

## Attach

Insert `JalaGraphQLLink` **before** the terminating link — the one that
actually performs the network call, e.g. `HttpLink`:

```dart
import 'package:gql_link/gql_link.dart';
import 'package:jala_graphql/jala_graphql.dart';

final uri = Uri.parse('https://api.example.com/graphql');
final link = Link.from([
  JalaGraphQLLink(endpoint: uri),
  HttpLink(uri.toString()),
]);
```

Both `graphql_flutter`'s `GraphQLClient` and `ferry`'s `Client` accept a
`Link`, so this same chain works for either.

### Endpoint URL

`gql_link` links never see the URL a downstream terminating link is
configured with — that's private to `HttpLink` (or whatever terminates the
chain). Pass `endpoint` so captured entries show the real GraphQL endpoint;
when omitted, entries fall back to a placeholder URL
(`graphql://unknown-endpoint`) so `NetworkRequestEvent.uri` — a required,
non-nullable field — always has *something* to show, while making clear
in the inspector that the real endpoint wasn't provided.

## What gets captured

- `operationName` / `operationType` (`query`/`mutation`/`subscription`),
  shown on the list tile in place of the usual method chip and host+path
  title (see `jala_ui`).
- The request body is captured as the standard GraphQL-over-HTTP shape —
  `{"operationName": ..., "query": "...", "variables": {...}}` — so the
  inspector's GraphQL detail view can render the query text and variables
  as separate panes.
- The response body is captured as `{"data": ..., "errors": [...]}` (the
  `errors` key is only present when the response actually returned GraphQL
  errors). The call is still recorded with HTTP status `200` and
  `statusMessage: 'GraphQL errors'` in that case — GraphQL reports
  application-level failures via `errors` in an otherwise-successful
  transport response, not via HTTP status codes.
- Variables (and anything else in the captured request body text) are
  redacted via the same body-pattern redactor every other Jala adapter
  uses (`JalaConfig.redactor`/`JalaRedactor.redactedBodyPatterns`).
- Transport-level failures (a `LinkException` from the terminating link, or
  any other stream error) are captured as a `NetworkErrorEvent`, same as a
  connection error in `jala_dio`/`jala_http`.

## Subscriptions

- The request event fires immediately when the subscription starts
  (`operationType: 'subscription'`), so the entry appears right away in
  the inspector, pending.
- Every payload delivered on the subscription is captured as a
  `NetworkSubscriptionPayloadEvent` (`seq` incrementing from 0) and
  appended to the entry's `payloads` timeline — a ring buffer capped at
  `JalaConfig.maxSubscriptionPayloads` (default 50; `payloadCount` always
  reflects the true total, even once older payloads have been evicted).
  Filter the inspector list with `is:subscription` to see only these
  entries.
- A single response event still fires when the subscription's stream
  closes — not on every payload. Its body uses the **first** payload's
  `data`/`errors`, with `statusMessage: 'subscription completed'`.
  `duration` is the total time the subscription was open (start to
  close), not the time to the first payload.
- v0.4 tagged the total payload count in the completion body as
  `{"@subscription": {"payloads": N}}`; that convention is **removed** as
  of v0.5 — superseded by the payload timeline above.

## Double-capture

If the app *also* wraps its HTTP transport with `jala_dio`/`jala_http` —
for example, `HttpLink` internally uses a `Dio`/`http.Client` instance that
already has a `JalaDioInterceptor`/is already `JalaHttp.wrap`ped — the same
operation is captured **twice**: once here as a GraphQL entry
(`operationName`/`operationType` set, `client: 'graphql'`), and once more
as a raw HTTP POST by the other adapter. Two ways to avoid the duplicate:

- Don't wrap the transport instance used by the GraphQL client, or
- Filter the inspector list with `-is:graphql` (hide GraphQL entries, keep
  the raw POST) or `is:graphql` (hide the raw POST, keep the GraphQL
  entry).

## Production safety

- `JalaGraphQLLink.request` checks `JalaBinding.instance.isEnabled` first
  and returns `forward(request)` untouched when Jala is disabled — zero
  capture work on the hot path, and safe to leave attached in release
  builds.
- A bug in Jala's own capture logic can never break the app's GraphQL
  flow: all capture work is wrapped in `try`/`catch`, and the real request
  is always forwarded — and any real response/error from downstream is
  always yielded/rethrown — exactly once, regardless of whether capture
  succeeded.
- Large bodies are hard-capped (`JalaConfig.maxBodyBytes`, default 512 KB)
  the same way every other Jala adapter caps them.
