# X / LinkedIn announcement drafts (draft — user posts, do not submit)

## X thread (3 tweets)

**Tweet 1/3** (must stand alone — attach the demo GIF here)

Shipped Jala 0.1: an in-app network inspector for Flutter.

One-tap replay through your live Dio instance, DevTools-style filters (`s:4xx host:api.* slower-than:500ms`), and redaction on by default at capture time.

Try it in your browser, no install: https://ketok-id.github.io/jala-flutter/

[attach demo.gif here]

---

**Tweet 2/3**

Why: Alice inspired this space but has no cURL export and no desktop support. chucker is Android/OkHttp-only. talker's a logger, not an inspector.

Jala also does copy-as-Dart-snippet, HAR export, and a JSON viewer with in-body search — across all 6 Flutter platforms.

---

**Tweet 3/3**

pub.dev: https://pub.dev/packages/jala
Repo: https://github.com/ketok-id/jala-flutter

Roadmap: package:http support next, then mocking + edit-and-resend. Issues/feedback welcome — especially if the filter grammar is missing a term you'd want.

---

## LinkedIn (single paragraph)

Just shipped Jala 0.1, an in-app network inspector for Flutter — think a Chrome DevTools Network tab you drop directly into your own app. The two things I think are genuinely new for this category in Flutter: one-tap replay of a captured request through your app's live Dio instance (not a synthetic copy), and a real DevTools-style filter grammar instead of a plain search box. Redaction of sensitive headers (Authorization, Cookie, API keys) is on by default and happens at capture time, so there's nothing sensitive sitting in memory to leak. It also supports copy-as-cURL and copy-as-Dart-snippet, HAR 1.2 export, and runs on all six Flutter platforms — tested on web, a real Android 13 device, and the iOS 26.5 simulator. Try the live browser demo (no install) at https://ketok-id.github.io/jala-flutter/, packages are on pub.dev under the verified publisher ketok.id, and the repo is at https://github.com/ketok-id/jala-flutter. Feedback and issues very welcome — mocking support is next on the roadmap.

[attach demo.gif or a short screen recording]
