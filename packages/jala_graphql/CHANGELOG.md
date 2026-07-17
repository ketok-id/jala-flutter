## 0.5.0

- Subscription payload timeline: every payload delivered on an open
  subscription is now captured as a `NetworkSubscriptionPayloadEvent`
  (`seq` incrementing from 0), appended to the entry's `payloads` ring
  buffer (`JalaConfig.maxSubscriptionPayloads`, default 50) — superseding
  the v0.4 `{"@subscription": {"payloads": N}}` body convention, which is
  now removed. The completion response event (first payload as body,
  `statusMessage: 'subscription completed'`) is unchanged.

## 0.4.0

- Initial release: `JalaGraphQLLink extends Link` — a `gql_link` link that
  captures every GraphQL operation (query/mutation/subscription) sent
  through any `gql_link`-based client (`graphql_flutter`, `ferry`).
- Captures `operationName`/`operationType`, pretty-printed query text,
  variables (redacted via the shared body-pattern redactor), and the
  response's `data`/`errors` as standard `NetworkRequestEvent`/
  `NetworkResponseEvent`/`NetworkErrorEvent`s, with `client: 'graphql'`.
- GraphQL errors are captured with HTTP status `200` and
  `statusMessage: 'GraphQL errors'` (transport succeeded; the failure is
  application-level, per the GraphQL spec).
- Subscriptions: request event fires on subscribe; a single completion
  response event fires when the stream closes, using the first payload's
  body and tagging total payload count as `{"@subscription": {"payloads":
  N}}` — full payload-by-payload capture is out of scope for v0.4 (see
  README).
- Zero-cost passthrough when Jala is disabled; every capture path is
  wrapped in `try`/`catch` so a capture bug can never break the app's
  GraphQL flow, mirroring `jala_dio`/`jala_http`'s conventions.
