# Copilot Instructions for datomanager

## Quick Start for New Sessions

1. **Check active work**: Open `dev/README.md` -> "Active Specs" table.
2. **Load context**: Open the active spec under `.kiro/specs/{feature}/` -- read
   `requirements.md`, `design.md`, and `tasks.md`; the next unchecked task is where to resume.
3. **Read scope**: `dev/datomanager_scope.md` is the authoritative scope; the
   platform contract lives in the sibling repo at `../datom/dev/`.
4. **Continue work**: Check off each task in `tasks.md` in the same commit as its code
   (see datom's Chunk Delivery Checklist in `../datom/dev/README.md` -- it applies here
   verbatim).

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
- **Naming**: `gov_verb` for exports, `.gov_verb` (or `.datom_gov_*` for the reimplemented
  gov-write helpers) for internals. `cli::` for messages, `glue::glue()` for strings,
  `fs::` for filesystem, `yaml::`/`jsonlite::` for config.
- **ASCII only** in `R/*.R` (R CMD check warns on non-ASCII, even in comments):
  `--` not em-dash, straight quotes, `...` not ellipsis char.
- **Gov-write helpers are reimplemented, not lifted**: under pure separation datomanager
  implements the gov-write behaviors natively — gov-repo git via its own `git2r`, the
  gov-storage mirror via its own IO conforming to the contract's storage layout (C8). It does
  **not** copy datom's git-calling bodies and uses no `datom:::`. Keep them internal in
  `R/utils-gov.R`; the `# GOV_SEAM:` tag marks provenance.

## Interface Contract with datom

datomanager operates on `datom_conn` objects produced by `datom_get_conn()`. It
relies on these conn fields (do not expect datom to rename without a coordinated
bump): `gov_local_path`, `gov_root`, `gov_prefix`, `gov_region`, `gov_backend`,
`gov_client`, `github_pat`, `project_name`, `backend`, `root`, `prefix`, `region`.
Select the gov storage backend from `conn$gov_backend` — never infer it. datomanager
owns gov-repo git (its own `git2r`) and the gov-storage mirror (its own IO); it reaches
into datom only for these conn fields and the data-side platform surface below.

The stable platform surface datomanager orchestrates (datom Phase 22):
`datom_storage_list`, `datom_storage_copy`, `datom_storage_verify`,
`datom_storage_delete_prefix`, `datom_repo_set_data_store`, `datom_repo_delete`.

**Authoritative source**: the `gov-seam-liftout` spec contract
(`.kiro/specs/gov-seam-liftout/contract.md`, mirrored in `../datom`) is the source of truth
for the conn interface (C6), gov-repo git ownership (C7), gov storage layout (C8), and the
cross-repo execution sequence.

## Commit Message Convention (gov repo audit contract -- preserve exactly)

| Operation | Message |
|---|---|
| register project | `Register project {name}` |
| unregister project | `Unregister project {name}` |
| write dispatch | `Update dispatch for {name}` |
| write ref | `Update ref for {name}` |
| record migration | `Record migration for {name}: {summary}` |

## Operational Discipline (inherited verbatim from datom)

**Workflow model — spec = phase.** A unit of multi-step work is a **Kiro spec** under
`.kiro/specs/{feature}/` (`requirements.md` + `design.md` + `tasks.md`). It replaces the
legacy `dev/phase_*.md` phase doc. **Specs persist — they are NOT deleted on completion.**
Translate any legacy wording in datom's README the same way: "phase doc" -> "the spec";
"Chunks table" / "Progress Log" -> "tasks.md"; "Active Phases" -> "Active Specs". Works
identically in Kiro and Copilot.

See `../datom/dev/README.md` for the full chunk lifecycle, delivery checklist, branch
workflow, and spec completion procedure. Non-negotiables:

1. **Spec (`.kiro/specs/{feature}/`) + feature branch before multi-step work.** Never jump to code.
2. **Read before writing**: trace the full call chain (including datom callees)
   before editing.
3. **Full test suite before every commit** (`devtools::test()`); report the count.
4. **One logical change per commit.**
5. **Check in before implementing**: answer questions first; implement only on an
   explicit go-ahead ("go ahead", "yes", "do it", "proceed").
6. **Chunk checkpoint**: after committing a chunk, STOP and summarize; wait for an
   explicit go-ahead before the next chunk.
7. **Spec completion is mandatory**: migrate durable learnings (design -> spec docs;
   gotchas -> engineering notes; conventions -> these instructions), update the README
   Active Specs table, PR + merge + delete branch. **Specs persist — do NOT delete them.**

## Don'ts

- No `datom:::` (internal access). Need an internal? Export it from datom.
- No data-repo writes from datomanager except through `datom_repo_*()` helpers.
- No credentials in code, docs, committed files, git remotes, logs, or unmasked
  print output.
- No editing datom from datomanager work unless a spec explicitly scopes it.
