# X / LinkedIn announcement drafts (draft — user posts, do not submit)

X is friendlier than Reddit for package launches: media + links are normal,
no subreddit flair, less aggressive spam filter for established accounts.

**Media:** attach `docs/screenshots/demo.gif` (or a short screen recording)
on the first post — GIF/video gets more reach than link-only.

**Hashtags (optional, 1–2 max):** `#Flutter` `#FlutterDev` — don’t spam.

---

## Option A — single post (recommended)

Stands alone; easier to quote/share than a thread.

```text
Jala 0.5 — in-app Flutter network inspector (DevTools-style Network tab in your app)

• Live-client replay (Dio / package:http)
• Mock this + edit-and-resend
• On-device throttle: Slow 3G / Flaky / Offline
• Session export/import for QA → eng
• GraphQL + WebSocket in one list
• Redaction at capture; off in release by default

Demo: https://ketok-id.github.io/jala-flutter/
pub.dev: https://pub.dev/packages/jala
Guide: https://github.com/ketok-id/jala-flutter/blob/main/docs/ADOPTION.md
```

[attach demo.gif]

---

## Option B — 3-post thread

**1/3** (attach GIF; must make sense alone)

```text
Jala 0.5 is out: in-app Flutter network inspector with throttling + session share — plus one-tap live-client replay and rule-based mocking.

https://ketok-id.github.io/jala-flutter/
```

**2/3**

```text
Power tools in 0.5:
• Slow 3G / Flaky / Offline (host globs) — no Charles on the phone
• Export/import a session as versioned JSON (QA → eng)
• GraphQL subscription payload timelines + WS frames in one list

Filter: is:subscription, is:graphql, is:ws, is:mocked
```

**3/3**

```text
Brownfield guide (multi-Dio, GraphQL double-capture, Alice):
https://github.com/ketok-id/jala-flutter/blob/main/docs/ADOPTION.md

pub.dev: https://pub.dev/packages/jala (^0.5.1, Flutter ≥3.35)
Repo: https://github.com/ketok-id/jala-flutter

Feedback welcome.
```

---

## Option C — ultra-short (quote-friendly)

```text
Shipped Jala 0.5 for Flutter: on-device Slow 3G, session share, live replay, mocking, GraphQL/WS — in-app Network tab without a laptop proxy.

https://pub.dev/packages/jala
```

[attach demo.gif]

---

## Posting tips

| Do | Don’t |
|---|---|
| GIF or video on post 1 | Wall of text only |
| 1 clear CTA link (demo or pub) | 10 hashtags |
| Pin the post if it’s your main launch | Post 5 times the same day |
| Reply to questions with ADOPTION links | Ratio wars about Alice |

If the account is new on X, media + one link still usually works; Reddit’s filter is stricter.

---

## LinkedIn (single paragraph)

```text
Shipped Jala 0.5, an in-app network inspector for Flutter (Chrome DevTools Network tab inside your app). New: on-device throttling (Slow 3G / Flaky / Offline) and session export/import so QA can share a failing capture with engineering — alongside one-tap replay through the live Dio/http client, rule-based mocking, GraphQL (subscription payload timelines), and WebSocket frames. Secrets redacted at capture time; enabled defaults to kDebugMode. Existing-app guide: https://github.com/ketok-id/jala-flutter/blob/main/docs/ADOPTION.md · Demo: https://ketok-id.github.io/jala-flutter/ · pub.dev: https://pub.dev/packages/jala
```

[attach demo.gif or short screen recording]
