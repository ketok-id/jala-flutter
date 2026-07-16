# r/FlutterDev post (draft — user posts, do not submit)

**Suggested title:**
Jala 0.4.0: the Flutter network inspector with one-tap replay and rule-based mocking, now with GraphQL + WebSocket

**Suggested flair:** Tool / Package release (whatever r/FlutterDev's release tag is)

---

**Body:**

I've been building [Jala](https://pub.dev/packages/jala) — an in-app network inspector for Flutter, basically a Chrome DevTools Network tab you drop into your own app. It's a Ketok project. Just shipped 0.4.0; it's grown a lot since the 0.1 post here, so this isn't "another Alice clone" anymore — two things in particular I haven't seen in any other Flutter inspector:

- **One-tap replay through the live client.** Tap a captured request (Dio or `package:http`) and it re-fires through the same interceptor/client chain your app is actually using — not a synthetic copy.
- **Rule-based mocking.** Tap **"Mock this"** on any captured call and it becomes a rule — canned response, simulated failure, or delay — served without touching the network. Rules persist across restarts (`Jala.enableMockPersistence(dir)`). Combined with edit-and-resend and filtering with `is:mocked`, it's basically a Charles-style Map Local, except it lives inside your Flutter app instead of a separate proxy.

As far as I can tell, no other Flutter inspector package — Alice, chucker_flutter, talker — has replay *or* mocking.

**New in 0.4:** `jala_graphql` and `jala_websocket`. GraphQL support is built on `gql_link`, so it works with both `graphql_flutter` and `ferry` — operations show up with their `operationName`, a `QUERY`/`MUTATION` chip, and dedicated Query/Variables panes. WebSocket connections land in the same merged list with a live frame timeline: per-frame direction, size, preview, and close codes. Filter with `op:<name>`, `is:graphql`, `is:ws`.

Quick start (Dio):

```yaml
dependencies:
  jala: ^0.4.0
  jala_dio: ^0.4.0
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

Tap the floating bubble to open the inspector. Swap in `jala_http`, `jala_graphql`, or `jala_websocket` the same way if that's your stack.

Still there from earlier releases: a real DevTools-style filter grammar (`method:get status:4xx larger-than:10k slower-than:500ms is:replay -host:*.cdn.com`), a JSON body viewer whose search auto-expands collapsed nodes to the matches, copy as cURL *and* as a Dart/Dio snippet, HAR 1.2 export, redaction on by default at capture time (sensitive headers are masked before an entry ever reaches the store), image preview, a multipart parts table, transfer progress on pending calls, and a true no-op when disabled — `enabled` defaults to `kDebugMode`, so it's safe to leave wired up in a release build. All six platforms: Android, iOS, macOS, Windows, Linux, web.

**On Alice, chucker, and talker** — since I'm posting a comparison of my own tool, I want to be upfront about it. Alice is genuinely the reason this category exists in Flutter, but it still has no cURL export, no desktop support, no replay, and no mocking, and the repo's been quiet for a long while. chucker_flutter is Android-only (OkHttp), and while it does have cURL and HAR export, it doesn't do replay, mocking, or GraphQL beyond operation names. talker is a structured logger/error-tracker — genuinely good at that job, but it's not a network inspector with a UI in this sense, so it's not really a like-for-like comparison either.

Live demo, no install: **https://ketok-id.github.io/jala-flutter/**

Demo GIF: [attach docs/screenshots/demo.gif here]

Repo: https://github.com/ketok-id/jala-flutter

Would genuinely appreciate feedback — especially on the mocking workflow and the new GraphQL/WebSocket support, since those are the newest surface. Issues and PRs welcome.
