# Copilot Instructions for datomanager

## Quick Start for New Sessions

1. **Check active work**: Open `dev/README.md` -> "Active Phases" table.
2. **Load context**: Open the active phase doc (e.g. `dev/phase_0_scaffold.md`).
3. **Read scope**: `dev/datomanager_scope.md` is the authoritative scope; the
   platform contract lives in the sibling repo at `../datom/dev/`.
4. **Continue work**: Update the phase doc as you go (see datom's Chunk Delivery
   Checklist in `../datom/dev/README.md` -- it applies here verbatim).

## Project Overview

datomanager is the companion governance package for **datom**. datom provides
version-controlled table storage (parquet bytes + git-tracked metadata).
datomanager owns the *governed* layer on top:

1. **Gov lifecycle writes** -- governance repo bootstrap, project registration,
   dispatch routing, decommissioning, managed migration.
2. **Access enforcement** (further out) -- roles, grants, IAM-backed storage
   access points that gate `datom_read()`.

**Pre-release status**: Not released. No backward-compatibility concerns --
rename freely, break APIs as needed.

## The One Rule That Defines This Package: prefix = package

| Prefix | Package | Surface |
|---|---|---|
| `datom_*` | datom | Platform mechanics, ALL reads, solo-project self-serve writes |
| `gov_*` | datomanager | Governed lifecycle WRITES (init, attach, decommission, dispatch, migrate) |
| `access_*` | datomanager (future) | Access enforcement (roles, grants, IAM) |

- **Dependency direction is one-way**: datomanager Imports datom. datom NEVER
  imports or references datomanager.
- **No `:::` ever**: every cross-package call goes through an exported
  `datom::datom_*()` symbol. If datomanager needs something datom keeps internal,
  the fix is a new datom export (coordinated, in datom's repo) -- never `datom:::`.
- **gov reads stay `datom_*`**: `gov_` means "a datomanager-owned governed
  *write*". Reads of governance state (`datom_projects`, `datom_pull`) remain in
  datom. datomanager WRITES gov.

## Authority Vocabulary

- **solo project** -- `project.yaml` (data repo) is the location authority. datom
  alone provides the complete lifecycle. No datomanager needed.
- **governed project** -- `ref.json` (gov repo) is the authority. Governed verbs
  live in datomanager and orchestrate datom helpers. `gov_attach()` promotes solo
  -> governed (one-way; gov is sticky).

datomanager **never touches the data repo directly**. Every data-repo mutation
goes through a datom-owned `datom_repo_*()` helper (e.g.
`datom_repo_set_data_store()`, `datom_repo_delete()`). This preserves datom's
two-repos invariant: gov code commits only to the gov clone.

## Coding Style (inherited from datom)

- **Flat over nested**: early returns, guard clauses. No nested if-else chains.
- **Functional**: `purrr::` over for-loops.
- **Small, composable functions**; single responsibility.
- **Naming**: `gov_verb` for exports, `.gov_verb` (or `.datom_gov_*` for lifted
  helpers) for internals. `cli::` for messages, `glue::glue()` for strings,
  `fs::` for filesystem, `yaml::`/`jsonlite::` for config.
- **ASCII only** in `R/*.R` (R CMD check warns on non-ASCII, even in comments):
  `--` not em-dash, straight quotes, `...` not ellipsis char.
- **GOV_SEAM marker**: gov-write helpers lifted from datom keep their
  `# GOV_SEAM:` tags. New gov-write code is added next to them.

## Interface Contract with datom

datomanager operates on `datom_conn` objects produced by `datom_get_conn()`. It
relies on these conn fields (do not expect datom to rename without a coordinated
bump): `gov_local_path`, `gov_root`, `gov_client`, `project_name`, `backend`,
`root`, `prefix`, `region`.

The stable platform surface datomanager orchestrates (datom Phase 22):
`datom_storage_list`, `datom_storage_copy`, `datom_storage_verify`,
`datom_storage_delete_prefix`, `datom_repo_set_data_store`, `datom_repo_delete`.

## Commit Message Convention (gov repo audit contract -- preserve exactly)

| Operation | Message |
|---|---|
| register project | `Register project {name}` |
| unregister project | `Unregister project {name}` |
| write dispatch | `Update dispatch for {name}` |
| write ref | `Update ref for {name}` |
| record migration | `Record migration for {name}: {summary}` |

## Operational Discipline (inherited verbatim from datom)

See `../datom/dev/README.md` for the full chunk lifecycle, delivery checklist,
branch workflow, and phase completion procedure. Non-negotiables:

1. **Phase doc + feature branch before multi-step work.** Never jump to code.
2. **Read before writing**: trace the full call chain (including datom callees)
   before editing.
3. **Full test suite before every commit** (`devtools::test()`); report the count.
4. **One logical change per commit.**
5. **Check in before implementing**: answer questions first; implement only on an
   explicit go-ahead ("go ahead", "yes", "do it", "proceed").
6. **Chunk checkpoint**: after committing a chunk, STOP and summarize; wait for an
   explicit go-ahead before the next chunk.
7. **Phase completion is mandatory**: migrate learnings, update README, delete the
   phase doc, PR + merge + delete branch.

## Don'ts

- No `datom:::` (internal access). Need an internal? Export it from datom.
- No data-repo writes from datomanager except through `datom_repo_*()` helpers.
- No credentials in code, docs, committed files, git remotes, logs, or unmasked
  print output.
- No editing datom from datomanager work unless a phase explicitly scopes it.
