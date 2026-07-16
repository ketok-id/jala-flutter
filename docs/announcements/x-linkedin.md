# X / LinkedIn announcement drafts (draft — user posts, do not submit)

## X thread (3 tweets)

**Tweet 1/3** (must stand alone — attach the demo GIF here)

Jala 0.4.0 is out: an in-app network inspector for Flutter — a Chrome DevTools Network tab that lives inside your own app.

One-tap replay through your live Dio/http client, plus rule-based mocking (canned responses, failures, delays — persists across restarts). No other Flutter inspector has either.

https://ketok-id.github.io/jala-flutter/

[attach demo.gif here]

---

**Tweet 2/3**

New in 0.4: `jala_graphql` (works with graphql_flutter *and* ferry, operation-aware capture with Query/Variables panes) and `jala_websocket` (frame-level timelines: direction, size, preview, close codes) — merged into the same inspector list.

Filter with `op:<name>`, `is:graphql`, `is:ws`, `is:mocked`.

---

**Tweet 3/3**

Mocking + edit-and-resend is basically a Charles-style Map Local — except it lives inside your Flutter app instead of a separate proxy.

pub.dev: https://pub.dev/packages/jala
Repo: https://github.com/ketok-id/jala-flutter

Feedback welcome, especially on the GraphQL/WS additions.

---

## LinkedIn (single paragraph)

Just shipped Jala 0.4.0, an in-app network inspector for Flutter — think a Chrome DevTools Network tab you drop directly into your own app. It now covers HTTP (Dio and package:http), GraphQL (via gql_link, so it works with both graphql_flutter and ferry), and WebSocket traffic in one merged, filterable list. Two things I think are still genuinely unique in this category: one-tap replay of a captured request through your app's live client, and rule-based mocking — tap "Mock this" on any captured call to turn it into a canned response, simulated failure, or delay that persists across restarts, filterable with is:mocked and editable with edit-and-resend. It's basically a Charles-style Map Local, except it lives inside your Flutter app instead of a separate desktop proxy. Redaction of sensitive headers happens at capture time and is on by default; enabled defaults to kDebugMode with a true no-op in release builds. Seven packages, all under the verified publisher ketok.id on pub.dev, running on all six Flutter platforms. Live browser demo (no install): https://ketok-id.github.io/jala-flutter/. Repo: https://github.com/ketok-id/jala-flutter. Feedback very welcome, especially on the new GraphQL and WebSocket support.

[attach demo.gif or a short screen recording]
