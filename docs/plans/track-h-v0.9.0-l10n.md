# Track H — v0.9.0: localization (en + id-ID)

Internationalize the inspector chrome — labels, tooltips, empty states,
snackbars, action names — behind a host-overridable delegate, shipping
`en` and `id-ID` first. UI-only: no capture path, no adapter, no core
model change. On-brand for Ketok, and the first track that makes the tool
feel local to its home market.

Written 2026-08-05. Roadmap row: Track H.

## Why 0.9.0 and not 0.8.x

The roadmap proposed this as "0.8.x", written before Track I claimed
0.8.1. Two things push it to a minor:

1. **It is a behaviour change by construction.** If the inspector follows
   the device/host locale (see H3 — and it should, or nobody who hasn't
   read the changelog ever sees a translation), then an app running on an
   Indonesian device renders a different inspector after upgrading.
   `COMPAT.md`'s own table puts "change default redaction" — the same
   shape of change — in the **minor** row.
2. **The public surface grows.** `JalaLocalizations` and its delegate go
   in the `jala_ui` barrel, which `COMPAT.md` defines as the
   semver-covered surface. That is more than the "sometimes patch if
   tiny" exception is meant to carry.

The escape hatch, if 0.9.0 feels too heavy: ship strictly opt-in (default
stays `en`, host must pass a locale), which makes 0.8.x defensible. It
also makes the feature invisible by default, which defeats the point. The
recommendation is 0.9.0.

**Ordering note.** Track I is planned as 0.8.1. If H ships first, I
becomes 0.9.1 and its "patch under the tiny exception" argument has to be
re-checked against the new base — the argument is about the size of the
change, not the digits, so it survives; only the file name and the
roadmap row need editing. If I ships first, nothing here moves.

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
- Resolve the locale, in order: an explicit `JalaConfig` override if set
  → the platform locale (`PlatformDispatcher.instance.locale`) → `en`.
  Reading the host's own `Locale` is not reliably possible from a
  sibling, which is why the platform is the middle rung rather than the
  host app.
- Add `JalaConfig.locale` (nullable, `null` = follow platform). It lives
  in `jala_core`, which is pure Dart — `Locale` is `dart:ui`, so store a
  **language tag `String`** (`'id-ID'`) there and parse it in `jala_ui`,
  rather than putting a Flutter type in core. This preserves the
  zero-Flutter-import rule for `jala_core`; do not weaken it for
  convenience.
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
- Keep developer jargon in English where the Indonesian dev community
  actually uses English (`request`, `response`, `header`, `payload`,
  `replay`, `mock`). Translating to `permintaan`/`tanggapan` reads as
  machine-translated to the target audience. This is a judgment call per
  string, and the user is the authority on it — flag the ~15 borderline
  ones for review rather than deciding unilaterally.
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
- `dart analyze --fatal-infos` from root, full suite, then the standing
  on-device smoke — with the device set to Indonesian, which is the only
  way the H3 locale resolution gets exercised for real.

## Open questions

1. **0.9.0, or opt-in-only at 0.8.x?** Recommendation above is 0.9.0
   with platform-locale following. Answering this first also settles
   whether Track I's number moves.
2. **How much stays English inside id-ID?** The `request`/`response`
   jargon question in H4. Needs the user's ear for the local dev
   community, not a translator's.
3. **The Material-strings seam** — accept English framework strings
   inside a translated inspector, or override the handful by hand? Defer
   until H3 is on a device and the seam is visible.
