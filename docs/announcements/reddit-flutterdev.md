# r/FlutterDev post (draft — user posts, do not submit)

**Suggested title:**
Jala: an in-app network inspector for Flutter with one-tap replay, DevTools-style filters, and redaction by default

**Suggested flair:** Tool / Package release (whatever r/FlutterDev's release tag is)

---

**Body:**

I've been building [Jala](https://pub.dev/packages/jala) — an in-app network inspector for Flutter, basically a Chrome DevTools Network tab you drop into your own app. It's a Ketok project, just hit 0.1 on pub.dev, and I wanted to put it in front of people who'd actually use it before pushing further.

The short version of why this exists: I like Alice, but I kept hitting the same three walls — no cURL export, no desktop support, and no way to just replay a request without going back to Postman or the app itself. So Jala focuses on three things:

- **One-tap replay through the live Dio instance.** Tap a captured request and it re-fires through the same interceptor chain your app is actually using — not a synthetic copy. As far as I can tell, no other Flutter inspector package does this.
- **A real filter grammar**, not a text box: `method:get status:4xx host:api.* larger-than:10k slower-than:500ms is:replay -host:*.cdn.com`. Terms are AND'd, `-` negates, malformed terms just degrade to free text instead of erroring.
- **Redaction on by default, at capture time.** `Authorization`, `Cookie`, `X-Api-Key`, etc. get masked before the entry ever reaches the in-memory store — the real value never exists in there, so there's no "oops, screenshot leaked a token" scenario.

Also: copy as cURL *and* as a Dart/Dio snippet, HAR 1.2 export, a JSON body viewer with in-body search that auto-expands matches, and it's tested across all six platforms — web, a real Android 13 device, and the iOS 26.5 simulator, plus desktop. `enabled` defaults to `kDebugMode`, and when it's off the overlay is a true no-op (returns your widget tree unchanged, interceptor just forwards) so it's safe to leave wired up in release builds.

Quick start:

```yaml
dependencies:
  jala: ^0.1.0
  jala_dio: ^0.1.0
  dio: ^5.9.0
```

```dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jala/jala.dart';
import 'package:jala_dio/jala_dio.dart';

void main() {
  Jala.initialize(); // enabled: kDebugMode
  final dio = Dio();
  JalaDio.attach(dio);
  runApp(JalaOverlay(child: MyApp(dio: dio)));
}
```

Tap the floating bubble to open the inspector.

**On Alice, chucker, and talker** — I want to be upfront about this since I'm posting a comparison of my own tool. Alice is genuinely the reason this category exists in Flutter at all, and a lot of Jala's list UX is a direct response to using it for years. Its gaps right now are concrete and fixable, not fundamental: no cURL export ([open issue #232](https://github.com/jhomlala/alice/issues/232)), no desktop support ([#243](https://github.com/jhomlala/alice/issues/243)), and the repo's been quiet for about 11 months. chucker_flutter is solid but Android/OkHttp only, so it's not really in the same lane as a cross-platform Dio inspector. talker is a structured logger/error-tracker — great at what it does, but it's not an inspector with a UI in this sense, so it's not a like-for-like comparison either.

Live demo in your browser, no install: **https://ketok-id.github.io/jala-flutter/**

Demo GIF: [attach here — request → filter → detail → replay loop]

Roadmap: `package:http` support and image/multipart previews are next (0.2), then GraphQL/WebSocket/storage explorers (0.3). Mocking and edit-and-resend are on the horizon after that.

Repo: https://github.com/ketok-id/jala-flutter

Would genuinely appreciate feedback — especially if you try it against your own Dio setup and something breaks, or if the filter grammar is missing a term you'd reach for. Issues and PRs welcome.
