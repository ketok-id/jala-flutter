# Track H — v0.8.1: localization (en + id-ID)

Internationalize the inspector chrome — labels, tooltips, empty states,
snackbars, action names — behind a host-overridable delegate, shipping
`en` and `id-ID` first. UI-only: no capture path, no adapter, no core
model change. On-brand for Ketok, and the first track that makes the tool
feel local to its home market.

Written 2026-08-05. Roadmap row: Track H.

## Why 0.8.1 — and the constraint that buys it

**Decision (user, 2026-08-05): stay at 0.8.x.** This lands as **0.8.1**,
under the same `COMPAT.md` "sometimes patch if tiny" exception Track I
invoked, and with the same precondition attached — which here is not a
formality but a design constraint that reaches into H3:

> **The track must stay strictly additive and opt-in. The inspector does
> not change its language unless the host asks it to.**

Concretely, that forbids one thing the obvious implementation would do:
**do not follow the device locale by default.** An app on an Indonesian
device must render exactly the same inspector after upgrading as before.
The moment id-ID resolves without the host opting in, this is a
behaviour change — `COMPAT.md`'s table puts "change default redaction",
the same shape of change, in the **minor** row — and the release becomes
0.9.0. This mirrors Track I's own hedge verbatim ("if socket mode ever
becomes the default … the release becomes 0.9.0").

The known cost, stated plainly so nobody is surprised later: **the
translation is invisible until a host sets `JalaConfig.locale`.** Nobody
who has not read the changelog will ever see Indonesian. That is the
accepted trade for the patch number, and it makes the README line and
the changelog entry load-bearing — they are the only discovery path the
feature has. If adoption data later says nobody found it, promoting
platform-locale following to the default is a clean, self-contained
0.9.0 follow-up: one resolution rule in H3, nothing else moves.

**Ordering note.** Track I also claims 0.8.1. Both cannot have it —
whichever ships second takes 0.8.2. H is the one currently being built,
so the roadmap now reads H → 0.8.1, I → 0.8.2; flip both rows if that
order changes. Neither track's version *argument* depends on the digits,
only on staying additive and opt-in, so the renumber is cosmetic.

## One helpful thing `COMPAT.md` already says

> Treat as unstable / do not depend on: … Exact wording of error strings
> / snackbars (unless a test API is documented) — `COMPAT.md:63`

So re-wording strings while translating them is free, and no host can
pin behaviour to a literal. That removes the main hidden cost of a
retrofit like this.

## The dependency decision — hand-rolled, not `gen-l10n`

The roadmap sketch said "via `flutter gen-l10n` / ARB". **Recommend
against it**, on evidence:

- `flutter_localizations` pins **`intl: 0.20.2` exactly** — not a caret
  range (verified in the Flutter 3.41.9 SDK in this repo).
- `intl` is **not in the workspace lockfile today**. Jala currently
  forces zero transitive version constraints on a host app beyond
  `flutter` itself.
- Adding it would mean a *debugging* library dictates the host app's
  `intl` version. For a tool whose whole pitch is "drops into a
  brownfield app without breaking anything", that is a real adoption tax
  and a predictable class of pub-solve failure — the exact thing
  `ADOPTION.md` exists to avoid.

The usual counter-argument to hand-rolling is ICU plurals and date
formatting. Neither bites here:

- **Three plural sites exist in the whole UI**, all already hand-rolled
  English ternaries:
  `jala_inspector_screen.dart:165` (`Copied HAR for N call/calls`),
  `jala_inspector_screen.dart:725` (`Imported session (N entry/entries)`),
  `jala_mock_editor_screen.dart:245` (`Matches N captured call/calls`).
- **Indonesian has no plural inflection** — the noun does not change with
  count — so the id-ID side of all three is a single form. The plural
  machinery would be carrying English's problem alone.
- Dates/bytes/durations already go through `jala_ui/lib/src/util/format.dart`
  and stay there, unlocalized (see below).

So: a plain abstract class with a const subclass per locale, a
`LocalizationsDelegate` over a `Map<String, JalaLocalizations>`, zero new
dependencies. If a third locale with real plural rules (Polish, Arabic,
Russian) ever lands, revisit — that is the trigger to reconsider, not
now.

Cost accepted by hand-rolling: no ARB tooling, no translator-friendly
file format, no automated "missing key" check from the framework. H1
buys the last one back with a test.

## What gets localized

~98 distinct literals by a conservative grep (`Text(…)`, `label:`,
`tooltip:`, `hintText:`, `labelText:`), across 12 files. The real number
is higher — that pattern misses `SnackBar` content, dialog titles, and
`AppBar` titles built indirectly. Budget **~130–150 strings**.

Concentration, highest first — this is also the recommended migration
order, since the first two files will surface most of the API design
problems:

| File | Literals (grep floor) |
|---|---|
| `screens/jala_inspector_screen.dart` | 27 |
| `screens/jala_call_detail_screen.dart` | 24 |
| `screens/jala_mock_editor_screen.dart` | 14 |
| `screens/jala_throttle_screen.dart` | 13 |
| `widgets/jala_body_view.dart` | 9 |
| `screens/jala_ws_detail_screen.dart` | 7 |
| `screens/jala_request_composer_screen.dart` | 7 |
| `widgets/jala_headers_table.dart` | 5 |
| `widgets/jala_json_tree.dart` | 4 |
| `screens/jala_mocks_screen.dart` | 2 |
| `widgets/jala_call_list_tile.dart` | 1 |
| `screens/jala_call_diff_screen.dart` | 1 |

## What deliberately stays in English

State these in the README, because a half-localized UI reads as a bug
unless the line is drawn on purpose:

- **The filter DSL grammar** — `status:`, `is:ws`, `op:`, `method:`. It
  is a syntax, not prose. Translating the keywords would fork the
  grammar per locale and break every shared filter string. The *help
  sheet prose* around it (`widgets/jala_filter_help_sheet.dart`) does get
  translated; the terms it documents do not.
- **HTTP method names, status reason phrases, header names** — wire
  vocabulary.
- **gRPC status names** (`NOT_FOUND`, `DEADLINE_EXCEEDED`) — same
  reasoning, and they are what the developer greps for.
- **Byte/duration formatting** (`util/format.dart`) — `1.2 MB`, `340 ms`.
  Localizing number separators here would need `intl`, which is the
  dependency we just refused. Revisit only with the ARB decision.
- **Exported artifacts** — HAR, cURL, session JSON. These are
  machine-read and cross-tool; locale must not leak into them. Worth an
  explicit test (H5).

## H1. The delegate (`jala_ui`), runs alone

- `lib/src/l10n/jala_localizations.dart`: abstract `JalaLocalizations`
  with one getter per string, plus methods for the interpolated and
  plural cases (`copiedLabel(String label)`,
  `copiedHarForCalls(int count)`, …). Interpolation stays typed —
  no `Map<String, dynamic>` placeholder bags.
- `lib/src/l10n/jala_localizations_en.dart`, `…_id.dart`: const
  subclasses.
- `JalaLocalizationsDelegate` with `isSupported`, `load` (synchronous —
  `SynchronousFuture`), `shouldReload => false`.
- `static JalaLocalizations of(BuildContext)` — **must not return null
  and must not throw** when no delegate is installed. Fall back to the
  `en` instance. `jala_ui` widgets are individually exported and a host
  can mount `JalaCallListTile` anywhere; a hard assert would turn a
  missing delegate into a crash in someone else's app, which the
  project's "never break the host" posture forbids.
- Export both from the `lib/jala_ui.dart` barrel.
- The `en` subclass is the interface's own reference implementation;
  `id` must override every member. Because the base class is abstract
  with no defaults, **a missing id-ID string is a compile error, not a
  runtime fallback** — this is the main thing bought back from losing
  ARB tooling.

## H2. Migrate the call sites (`jala_ui`)

Mechanical but wide: 12 files, ~150 strings. Per file — thread
`JalaLocalizations.of(context)` in as a local `final JalaLocalizations
l10n`, replace literals, keep the existing widget structure untouched.

Two traps:

- **`context` availability.** Snackbars fired from callbacks
  (`jala_call_detail_screen.dart:63`, `jala_ws_detail_screen.dart:58`,
  `jala_headers_table.dart:248`) resolve `l10n` from the captured
  context; make sure it is read before any `await`, not after — the
  `use_build_context_synchronously` lint will catch the ones that matter.
- **Tests assert on literals.** Every `find.text('…')` in
  `packages/jala_ui/test/` and `examples/jala_example/test/` pointing at
  a translated string has to move to the `en` table. Do not leave
  hardcoded English in tests: that is exactly how `track_b`'s
  `find.text('/__down')` rotted silently for three releases.

This step is the bulk of the work and is the natural Sonnet delegation —
it is a wide mechanical edit against a fixed interface, with the
compiler and the test suite as the gate.

## H3. Locale resolution + overlay wiring (`jala`)

The interesting bug lives here. `packages/jala/lib/src/jala_overlay.dart:38`
hardcodes:

```dart
Localizations(
  locale: const Locale('en', 'US'),
  delegates: const <LocalizationsDelegate<Object?>>[…],
```

The overlay mounts its **own** `Localizations` because it is a *sibling*
of the host app and cannot inherit from a `MaterialApp` inside `child`
(the same reason it owns its theme and navigator). So until this line
changes, **no translation can ever resolve**, no matter what H1 and H2
do. Ship H3 in the same release or the feature is dead code.

- Add `JalaLocalizationsDelegate` to that delegate list.
- Resolve the locale in exactly two rungs: **explicit `JalaConfig.locale`
  if set → `en`.** Nothing else. `PlatformDispatcher.instance.locale` is
  deliberately *not* consulted — that is the line the 0.8.1 decision
  draws (see the version section). It is one line to add later if the
  default is ever promoted; adding it now silently makes this a 0.9.0.
- Add `JalaConfig.locale` (nullable, `null` = **English**, not "follow
  platform"). It lives in `jala_core`, which is pure Dart — `Locale` is
  `dart:ui`, so store a **language tag `String`** (`'id-ID'`) there and
  parse it in `jala_ui`, rather than putting a Flutter type in core. This
  preserves the zero-Flutter-import rule for `jala_core`; do not weaken
  it for convenience.
- Document the opt-in on `JalaConfig.locale`'s doc comment, in
  `docs/CONFIG.md`, and in the `jala` README — per the version section,
  these are the feature's only discovery path.
- The platform delegates (`DefaultMaterialLocalizations` etc.) only
  supply `en`. If the resolved locale is `id`, Material's own widget
  strings ("Back", "Close") stay English unless `flutter_localizations`
  is added — which we refused. **Accept the seam and document it**: the
  handful of framework strings inside the inspector stay English. If
  that looks wrong in practice on a real device (H5), the fallback is
  overriding those few strings ourselves, not taking the dependency.

## H4. id-ID translation

- Draft `id` in one pass, then read it on a device rather than in a
  diff — screen labels have width constraints and Indonesian runs longer
  than English for most UI verbs.
- **Keep the common language (decision: user, 2026-08-05.)** Developer
  jargon the Indonesian dev community already speaks in English stays in
  English: `request`, `response`, `header`, `payload`, `replay`, `mock`,
  `body`, `status`, `endpoint`, `timeout`, `cache`. Do **not** reach for
  `permintaan`/`tanggapan`/`muatan` — those read as machine-translated to
  the target audience and make the tool feel less native, not more.

  What *does* get translated is the connective prose around the jargon —
  empty states ("No calls yet"), action verbs ("Copy", "Clear", "Export"),
  confirmations, error sentences, and help text. The test for a borderline
  word: would an Indonesian Flutter developer type it in English in a
  standup? If yes, leave it.
- Watch for overflow in: the throttle screen's profile rows, the call
  detail tab labels, and the filter help sheet.

## H5. Verification

- Widget test per locale for the two dense screens: pump the inspector
  wrapped in `Localizations` with `id`, assert on id strings.
- **Missing-delegate test**: mount `JalaCallListTile` with no
  `JalaLocalizations` ancestor at all, assert it renders English and does
  not throw. This is the H1 fallback contract.
- **Export purity test**: run a HAR export and a cURL export under an
  `id` locale, assert the output is byte-identical to the `en` run. No
  locale leakage into machine-read artifacts.
- **No new transitive deps**: assert `intl` is absent from the lockfile
  after the track lands. Cheap, and it is the whole premise of the
  dependency decision.
- **Opt-in guarantee test — the one that guards the patch number.** With
  the platform locale forced to `id` and `JalaConfig.locale` unset, the
  inspector must still render **English**. If this test ever goes red,
  the release is a 0.9.0, not a 0.8.1. Name it so that is obvious from
  the test name alone.
- `dart analyze --fatal-infos` from root, full suite, then the standing
  on-device smoke. Two passes on the device: once with
  `JalaConfig.locale: 'id-ID'` set in the example app (reads the
  translation, checks overflow), and once with the **device** language
  set to Indonesian and no config — which must stay English, confirming
  the opt-in guarantee on real hardware rather than only in a widget
  test.

## Open questions

1. ~~0.9.0, or opt-in-only at 0.8.x?~~ **Answered (user, 2026-08-05):
   0.8.x.** Ships as 0.8.1, opt-in only, no platform-locale following.
   Track I moves to 0.8.2. See the version section for the constraint
   this imposes on H3.
2. ~~How much stays English inside id-ID?~~ **Answered (user,
   2026-08-05): keep the common language.** English dev jargon stays
   English; the prose around it is translated. Rule of thumb and word
   list in H4.
3. **The Material-strings seam** — accept English framework strings
   ("Back", "Close") inside a translated inspector, or override the
   handful by hand? Defer until H3 is on a device and the seam is
   visible. Note this got smaller with Q1: since id-ID only appears when
   a host opts in, a developer seeing the seam has already chosen the
   locale deliberately.
