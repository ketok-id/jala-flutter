# X / LinkedIn announcement drafts (draft — user posts, do not submit)

## X thread (3 tweets)

**Tweet 1/3** (must stand alone — attach the demo GIF here)

Jala 0.5 is out: in-app Flutter network inspector with **throttling** and **session share** — still the only one with one-tap live-client replay + rule-based mocking.

https://ketok-id.github.io/jala-flutter/

[attach demo.gif here]

---

**Tweet 2/3**

New power tools:
• Slow 3G / Flaky / Offline (host globs) without a proxy
• Export/import a session as versioned JSON (QA → eng)
• GraphQL subscription payload timelines + WS frames in one list

Filter: `is:subscription`, `is:graphql`, `is:ws`, `is:mocked`, …

---

**Tweet 3/3**

Brownfield install guide (multi-Dio, GraphQL double-capture, Alice migrate):  
https://github.com/ketok-id/jala-flutter/blob/main/docs/ADOPTION.md

pub.dev: https://pub.dev/packages/jala (`^0.5.1`, Flutter ≥3.35)

---

## LinkedIn (single paragraph)

Shipped Jala 0.5, an in-app network inspector for Flutter (Chrome DevTools Network tab inside your app). New in this release: on-device network throttling (Slow 3G / Flaky / Offline + custom profiles) and session export/import so QA can share a captured session with engineering via clipboard JSON — still alongside one-tap replay through the live Dio/http client, rule-based mocking, GraphQL (including subscription payload timelines), and WebSocket frame inspection. Sensitive headers are redacted at capture time; enabled defaults to kDebugMode with a true no-op in release. Seven lockstep packages under verified publisher ketok.id. Existing-app guide: https://github.com/ketok-id/jala-flutter/blob/main/docs/ADOPTION.md · Live demo: https://ketok-id.github.io/jala-flutter/ · pub.dev: https://pub.dev/packages/jala

[attach demo.gif or a short screen recording]
