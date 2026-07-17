# r/FlutterDev post (draft — user posts, do not submit)

**Subreddit:** r/FlutterDev  
**Problem:** Reddit’s site-wide spam filter may remove package posts even with few links (“Sorry, this post was removed by Reddit’s filters”). That is **not** usually a human mod. After **two** removals, do **not** keep reposting the same shape — it makes the filter worse.

---

## Immediate recovery (after 2nd filter)

1. **Stop reposting** for 24–48 hours on this account in this sub (or use the steps below once, carefully).  
2. **Modmail r/FlutterDev** (best path for a real package):

   ```text
   Hi mods — twice my Showoff/self-promo style post about an open-source
   Flutter network inspector (Jala) was removed by Reddit’s site-wide
   filters, not by you. It’s a real pub.dev package under publisher ketok.id.

   Could you either:
   (a) approve a filtered post if you still see it, or
   (b) advise if self-posts about open-source packages need a different
       flair / process in this sub?

   Account: <your username>
   Post URL(s) if still visible to me: <url>
   Package: https://pub.dev/packages/jala
   ```

3. **Check account signals**  
   - New account / low karma / email not verified → filter is much harsher  
   - Verify email, wait, build a little non-promo karma (helpful comments)  
   - Don’t use VPN/datacenter IP if you can avoid it for the post  

4. **Optional:** Reddit help → “My post was removed by the filters” appeal (slow, hit-or-miss).

---

## Why you got filtered (likely)

| Risk | Mitigation |
|---|---|
| Account new / low karma | Comment helpfully for a few days first |
| “I built a package + install” pattern | Frame as **discussion / feedback**, not launch |
| Any outbound link in OP | **Zero links** in OP; links only after it’s live |
| Code / yaml / domain-looking text | No code fences; no pub.dev / github in OP |
| Same post twice | Completely different title + body on retry |
| Image + promo text | Text-only first; image in comment later |

---

## Attempt 3 — zero-link OP (strongest filter dodge)

**Title (pick one — must differ from previous titles):**

1. **(Recommended)** How do you inspect HTTP on a real device without Charles? I open-sourced my approach  
2. Looking for feedback: in-app network inspector for Flutter (replay + Slow 3G + session share)  
3. What would make you try another network inspector if you already use Alice?  

**Body (copy-paste — NO urls, NO code blocks):**

```text
I'm the author (disclosure). I got tired of needing a laptop proxy to debug
Flutter networking on a physical phone, so I built an in-app inspector
(Chrome DevTools Network–style list, filters, detail panes).

What it does that I still don't get from Alice alone:
• Replay a captured call through the live Dio / package:http client
• Mock this / edit-and-resend without the network
• On-device throttle (Slow 3G, flaky, offline) — new for me vs other Flutter inspectors
• Export a session as JSON so QA can hand eng a failing capture
• GraphQL + WebSocket in the same list
• Redact secrets at capture time; off by default in release builds

I'll drop the pub.dev / demo / docs links in a comment if this post is
allowed to stay up (Reddit filtered my earlier posts that had links).

Questions for people who've tried in-app inspectors:
1) Multi-Dio apps — how do you want attach / replay to work?
2) Is on-device throttle actually useful vs just using a proxy?
3) Anything that would block you from adding this to a brownfield app?

Happy to answer design questions here either way.
```

**Wait until the post is visible to logged-out / another account**, then:

**First comment (links OK once OP survived):**

```text
Links (posted after the OP so Reddit's filter is less angry):

• Package: https://pub.dev/packages/jala  (0.5.1)
• Live demo: https://ketok-id.github.io/jala-flutter/
• Brownfield guide: https://github.com/ketok-id/jala-flutter/blob/main/docs/ADOPTION.md
• Repo: https://github.com/ketok-id/jala-flutter

Minimal wire-up if anyone wants to try: Jala.initialize() + JalaDio.attach(dio) + wrap with JalaOverlay. Flutter ≥3.35; lockstep 0.5.x packages.
```

---

## If zero-link still dies

Then it’s almost certainly **account/reputation**, not the text:

1. Modmail only — ask mods to **approve** or to say if new accounts can’t self-promo.  
2. Post from an **older account** if you have one (still disclose authorship).  
3. Skip Reddit for a bit; use **X / LinkedIn / Flutter Weekly / Discord** from `docs/announcements/`.  
4. Comment on *other* networking threads with useful answers and a soft “I open-sourced X for this” later.  

Do **not** create a brand-new throwaway just to spam the same post.

---

## Alternate channel if Reddit keeps blocking

| Channel | Draft |
|---|---|
| Flutter Weekly | `docs/announcements/flutter-weekly.md` |
| X / LinkedIn | `docs/announcements/x-linkedin.md` |
| Discord Flutter / community servers | Short version of zero-link body + one link |

---

## Posting checklist (attempt 3)

- [ ] Different title than both failed posts  
- [ ] Zero URLs and zero code fences in OP  
- [ ] Discussion questions at the end (not pure launch pitch)  
- [ ] Author disclosure once  
- [ ] Wait for post to stay up → then first comment with links  
- [ ] Modmail if filtered again — no 4th identical try  

---

## Older variants (do not use if already filtered)

Filter-safe one-link and multi-link versions were tried and filtered for some accounts. Prefer **zero-link OP** above after two removals.
