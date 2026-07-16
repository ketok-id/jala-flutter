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
