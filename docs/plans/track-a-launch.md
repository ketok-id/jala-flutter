# Track A — Launch & adoption (ships as 0.1.1)

Goal: maximum discoverability while the release is fresh. Almost entirely
executor-suitable work. No feature code changes.

## A1. Live web demo on GitHub Pages

The single highest-leverage item. No competitor (Alice, talker, ispect,
requests_inspector) has a zero-install browser demo.

- Add `.github/workflows/deploy-demo.yaml`: on push to `main`, build
  `examples/jala_example` with `flutter build web --release --base-href
  /jala-flutter/`, deploy `build/web` to GitHub Pages via
  `actions/deploy-pages` (needs Pages enabled on the repo, source: GitHub
  Actions — repo Settings step, one click, user or gh api).
- CORS note: httpbin.org sends permissive CORS headers so the demo buttons
  work from the browser; the "Bad host" button will fail differently on web
  (DNS error surfaces as a generic XHR error) — acceptable, it still
  produces an error entry.
- Add to the top of the root README: `**[Try the inspector in your browser
  ->](https://ketok-id.github.io/jala-flutter/)**` (verify final URL after
  first deploy).
- Acceptance: URL loads, firing requests + opening the inspector works in a
  fresh incognito tab.

## A2. Demo GIF in the README

- Record the web demo (or Android build) covering, in one ~20s loop: fire
  requests -> open bubble -> type `s:4xx` in the filter -> open detail ->
  Request tab (redacted header visible) -> Replay tap -> new ↺ entry.
- Tooling: `ffmpeg` screen capture of the browser pane, or QuickTime + ffmpeg
  gif conversion (`fps=12, scale=480:-1, palettegen/paletteuse`). Keep under
  ~5 MB so GitHub renders it inline.
- Place at `docs/screenshots/demo.gif`, embed near the top of root README
  (above the static screenshot table).

## A3. pub.dev topics + 0.1.1 metadata release

- Add to all four package pubspecs: `topics: [network, debugging, devtools,
  http, dio]` (jala_core omits `dio`; jala_ui may swap `dio` for `ui`).
  Max 5 topics; check https://pub.dev/topics for canonical names first.
- Check pub.dev score (analysis runs ~1 day after publish): fix anything
  flagged under "Pass static analysis" / "Support up-to-date dependencies" /
  "Follow Dart file conventions". Expect near-max already (dry-runs were
  clean).
- Add an `example/` note: pub.dev shows the "Example" tab only if a package
  has `example/` inside it. For `jala`, add a minimal
  `packages/jala/example/lib/main.dart` (20 lines: initialize + attach +
  overlay) so the tab renders.
- Bump all packages 0.1.0 -> 0.1.1, CHANGELOG entries ("Add pub.dev topics
  and example"), publish in dependency order.

## A4. Repo hygiene

- GitHub repo topics: `flutter`, `dart`, `network-inspector`, `debugging`,
  `devtools`, `dio`, `http-inspector` (`gh api -X PUT
  repos/ketok-id/jala-flutter/topics -f "names[]=..."`).
- `.github/ISSUE_TEMPLATE/`: `bug_report.yml` (asks for jala version, client
  used, platform, capture vs UI area) and `feature_request.yml`.
- Pinned roadmap issue: "Jala roadmap" linking docs/ROADMAP.md, listing
  Track B/C bullets as checkboxes.
- Optional: enable GitHub Discussions (user click).

## A5. Announcements (user-driven; drafts are executor work)

Draft (do not post — user posts):
- **r/FlutterDev post** — title like "Jala: an in-app network inspector for
  Flutter with one-tap replay, DevTools-style filters, and redaction by
  default". Body: 3 differentiators, honest Alice comparison, demo link, GIF.
- **X/LinkedIn** short version with the GIF.
- **Flutter Weekly** submission (form/issue on their repo).
- **awesome-flutter PR** adding Jala under Networking/Debugging (follow that
  repo's contribution rules: alphabetical order, one-line description).

Acceptance for the track: demo URL live and linked, GIF in README, 0.1.1 on
pub.dev with topics + example tab, issue templates merged, four announcement
drafts delivered to the user as markdown files in `docs/announcements/`
(gitignored or committed — user's call at execution time).
