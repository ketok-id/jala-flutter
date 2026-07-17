# r/FlutterDev post (draft — user posts, do not submit)

**Suggested title:**
Jala 0.5: in-app Flutter network inspector with throttling, session share, replay, and mocking

**Suggested flair:** Tool / Package release (whatever r/FlutterDev's release tag is)

---

**Body:**

I've been building [Jala](https://pub.dev/packages/jala) — an in-app network inspector for Flutter, basically a Chrome DevTools Network tab you drop into your own app. It's a Ketok project. Just shipped **0.5.x** with power tools that (as far as I can tell) still aren't in Alice / chucker_flutter / talker:

- **In-app network throttling** — Slow 3G / Fast 3G / Flaky / Offline (+ custom) with host globs. No Charles/Proxyman required on the phone.
- **Session export/import** — versioned JSON via clipboard so QA can paste a failing session to eng; Replay is disabled on imported rows (by design).
- **One-tap replay** through the *live* Dio / `package:http` client (still unique).
- **Rule-based mocking** + edit-and-resend (`is:mocked`).
- **GraphQL + WebSocket** — operation-aware GraphQL (including subscription payload timelines) and WS frame timelines in one merged list.

Also: capture-time redaction (tokens never enter the store), `enabled` defaults to `kDebugMode` with a true no-op when off, all six Flutter platforms.

**Adding to an existing app?** Brownfield guide (multi-Dio, GraphQL double-capture, Alice migration, PR checklist):  
https://github.com/ketok-id/jala-flutter/blob/main/docs/ADOPTION.md

```yaml
dependencies:
  jala: ^0.5.1
  jala_dio: ^0.5.1
  dio: ^5.9.0
```

```dart
Jala.initialize(); // enabled: kDebugMode
JalaDio.attach(dio);
runApp(JalaOverlay(child: MyApp(dio: dio)));
```

Requires Dart ^3.11 / Flutter >=3.35. Lockstep the Jala packages on the same 0.5.x.

Live demo (no install): **https://ketok-id.github.io/jala-flutter/**  
pub.dev: **https://pub.dev/packages/jala**  
Repo: **https://github.com/ketok-id/jala-flutter**

Feedback welcome — especially throttle + session-share in real QA workflows.
