# r/FlutterDev post (draft — user posts, do not submit)

**Subreddit:** r/FlutterDev  
**Flair:** Package / Tool / Showoff (use whatever matches the sub’s current flairs)  
**Format:** Self-text post (not a bare link). Prefer **few links in the OP** — Reddit’s site-wide spam filter often removes link-heavy package posts (“removed by Reddit’s filters”). Put extra URLs in the **first comment** after the post is live.

**Optional media:** attach `docs/screenshots/demo.gif` or a short screen recording if the sub allows images.

---

## Title options (pick one)

1. **(Recommended)** I built an in-app network inspector for Flutter (replay, mocking, Slow 3G) — feedback welcome  
2. Jala 0.5 — in-app Flutter network inspector with throttling, session share, and live-client replay  
3. Showoff: Chrome DevTools–style network tab inside your Flutter app  

Avoid ALL CAPS, “best ever”, or dunking hard on Alice in the title.

---

## Body — filter-safe (copy-paste)

Use this version first. **One main link** in the OP; rest go in a comment.

```text
I'm the author of Jala — an in-app network inspector for Flutter (Chrome DevTools–style Network tab inside your app). Just shipped 0.5.

Things I couldn't get cleanly from Alice / a desktop proxy alone:
- One-tap replay through the live Dio / package:http client
- Rule-based mocking ("Mock this") + edit-and-resend
- On-device throttling (Slow 3G / Flaky / Offline)
- Session export/import (clipboard JSON for QA → eng)
- GraphQL + WebSocket in the same list
- Redaction at capture time; off by default in release (kDebugMode)

Minimal wire-up: Jala.initialize() + JalaDio.attach(dio) + JalaOverlay.

Requires Flutter ≥3.35. Happy to take feedback, especially on multi-Dio apps or real QA use of throttle/session share.

Main link: https://pub.dev/packages/jala
```

---

## First comment (post immediately after OP is live)

```text
Links:
- Live demo: https://ketok-id.github.io/jala-flutter/
- Existing-app guide (multi-Dio, GraphQL double-capture, Alice migration): https://github.com/ketok-id/jala-flutter/blob/main/docs/ADOPTION.md
- Repo: https://github.com/ketok-id/jala-flutter

Why not just Alice / a proxy?
Alice is still fine for many apps. I wanted live-client replay, capture-time redaction, and (in 0.5) on-device throttle + session share without Charles. If a desktop proxy already works for you, you may not need this — that's OK.
```

---

## Longer body (only if the short post survives)

If the filter-safe post is fine and you want a follow-up comment with install snippet:

```text
Quick start (Dio):

dependencies:
  jala: ^0.5.1
  jala_dio: ^0.5.1
  dio: ^5.9.0

Jala.initialize(); // enabled: kDebugMode
JalaDio.attach(dio);
runApp(JalaOverlay(child: MyApp(dio: dio)));

Lockstep the Jala packages on the same 0.5.x. Dart ^3.11 / Flutter ≥3.35.
```

Do **not** put four+ outbound links in the OP again unless you’ve confirmed the account isn’t filter-sensitive.

---

## If Reddit removes the post (“removed by Reddit’s filters”)

That message is usually **site-wide anti-spam**, not a human mod.

1. Confirm: only you see the post + the red filter banner → filter; “removed by moderators” → mod action.  
2. **Modmail r/FlutterDev** (polite, short):

   > Hi — my package/Showoff post about an open-source Flutter network inspector was removed by Reddit’s filters (not a mod removal). Could you approve it if it looks fine?  
   > Link: &lt;post URL&gt;

3. Repost later with the **filter-safe body** (one link). Don’t spam the same multi-link text repeatedly.  
4. Optional: appeal via Reddit’s help flow for filtered content.

---

## Posting checklist

- [ ] Self-text post, filter-safe body (one main link)  
- [ ] Correct flair  
- [ ] Optional: demo.gif  
- [ ] First comment with demo + ADOPTION + repo (+ “why not Alice”)  
- [ ] Stay for the first hour to answer comments  
- [ ] Disclose you’re the author (already in the body)  

| Do | Don’t |
|---|---|
| Disclose authorship | Fake “found this cool package” |
| One primary link in OP | 4+ links + YAML wall in OP |
| Extra links in first comment | Argue with Alice fans |
| Invite specific feedback | Dump full CHANGELOG |

---

## Note on the live demo

If [ketok-id.github.io/jala-flutter](https://ketok-id.github.io/jala-flutter/) still feels pre–0.5, either rebuild gh-pages first or say in a comment that full power tools (throttle / session) are in the package and the hosted demo may lag.
