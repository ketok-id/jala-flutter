# awesome-flutter PR (draft — user opens the PR, do not submit)

Checked https://github.com/Solido/awesome-flutter directly (README.md,
contributing.md, source.md) on 2026-07-16. Notes below reflect what the repo
actually requires today — this **differs from the plan's assumption** of a
plain alphabetical README edit, so read before opening the PR.

## What's actually in that repo

- **There is no "Networking," "HTTP," or "Debugging" section.** The closest
  fit for an in-app inspector/dev-tool is the top-level **`## Utilities`**
  section (generic Flutter dev tooling: FVM, Melos, Dart Code Metrics, etc.).
  It is not the ideal category (it's tooling-in-general, not networking) but
  it's the best existing home — proposing a new section is allowed per their
  guidelines but raises the bar for acceptance.
- **Edit `source.md`, not `README.md`.** `contributing.md` says explicitly:
  "Do not commit on README, use SOURCE.md!" README.md appears to be generated
  (star counts etc. get filled in later). Sending a PR against README.md will
  likely get closed.
- **Entries are NOT alphabetical.** contributing.md: "Additions should be
  added to the bottom of the relevant category." So the entry goes at the end
  of the `## Utilities` list in source.md, not slotted alphabetically.
- **35-star minimum to apply**, per contributing.md ("35 stars minimum are
  required to apply, it mean your project hold interest"). Check
  github.com/ketok-id/jala-flutter's star count before opening the PR — if
  it's under 35, the PR is likely to be rejected on that basis alone and it
  may be worth waiting.
- **Format required:** `` [resource](link) - Description by [Author](link to author) ``
  - Use title-casing (AP style) for the resource name.
  - Don't mention "Flutter" in the description — it's implied by being in the
    list at all.
  - Start the description with a capital letter.
  - Keep the description short, no trailing whitespace.
  - One resource per PR, meaningful PR title (not "Update source.md").

## Exact entry to add

Append this line to the bottom of the `## Utilities` section in `source.md`:

```
- [Jala](https://github.com/ketok-id/jala-flutter) - In-app network inspector with one-tap replay, DevTools-style filters, and redaction by default by [Ketok](https://ketok.id)
```

(No star-count bracket — README.md's generator appears to add those; source.md
entries in the section didn't consistently include them either.)

## PR checklist for the user

1. Confirm github.com/ketok-id/jala-flutter has >= 35 stars.
2. Fork Solido/awesome-flutter, edit `source.md` (not `README.md`).
3. Add the line above to the end of the `## Utilities` list.
4. PR title: something like "Add Jala, an in-app network inspector" — not
   "Update source.md".
5. PR description: one or two sentences on why it's useful + link to the demo
   (https://ketok-id.github.io/jala-flutter/) as evidence it's real/working.
6. Expect review latency — this is a volunteer-curated list per
   contributing.md.
