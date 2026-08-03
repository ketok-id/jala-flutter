# Jala documentation

**Jala** ("net" in Indonesian) is an in-app network inspector for Flutter —
a Chrome DevTools–style Network tab you drop into your own app.

**Live demo:** [ketok-id.github.io/jala-flutter](https://ketok-id.github.io/jala-flutter/)  
**Lockstep version:** `0.8.x` (all eight packages together — see [COMPAT.md](COMPAT.md))

---

## I want to…

| Goal | Doc |
|---|---|
| Install in a **new** app | [Root README – Quick start](../README.md#quick-start) |
| Add to an **existing** app | [ADOPTION.md](ADOPTION.md) |
| Understand **packages** and layering | [packages.md](packages.md) · [overview.md](overview.md) |
| Configure **enable / redaction / caps** | [CONFIG.md](CONFIG.md) · [SECURITY.md](SECURITY.md) |
| Fix **no traffic / missing token / replay** | [TROUBLESHOOTING.md](TROUBLESHOOTING.md) |
| Version / breaking-change policy | [COMPAT.md](COMPAT.md) |
| What shipped / what’s next | [ROADMAP.md](ROADMAP.md) |
| Original v0.1 binding contract | [SPEC-v0.1.md](SPEC-v0.1.md) |

---

## Package READMEs (pub.dev)

| Package | Role |
|---|---|
| [`jala`](../packages/jala) | Facade — `Jala.initialize()`, `JalaOverlay`, open/close |
| [`jala_core`](../packages/jala_core) | Pure Dart: models, store, redaction, filter, export/import |
| [`jala_ui`](../packages/jala_ui) | Inspector screens (usually via `jala`) |
| [`jala_dio`](../packages/jala_dio) | Dio interceptor + replay |
| [`jala_http`](../packages/jala_http) | `package:http` wrap + replay |
| [`jala_graphql`](../packages/jala_graphql) | `gql_link` GraphQL capture |
| [`jala_websocket`](../packages/jala_websocket) | WebSocket channel wrap |

App install path for most teams: **`jala` + one adapter** (`jala_dio` or `jala_http`).

---

## Maintainers

Internal feature plans live under [plans/](plans/). Architecture notes for
agents also appear in the repo root `CLAUDE.md` (kept aligned with
[overview.md](overview.md)).
