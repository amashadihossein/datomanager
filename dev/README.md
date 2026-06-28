# datomanager Development Hub

## Workflow model (read first): spec = phase

A unit of multi-step work is a **Kiro spec** under `.kiro/specs/{feature}/`
(`requirements.md` + `design.md` + `tasks.md`). **The spec replaces the legacy
`dev/phase_{n}_{name}.md` phase doc.** Specs persist as durable documentation — they are not
deleted on completion. datomanager inherits datom's chunk/branch/checkpoint discipline
(`../datom/dev/README.md`); translate legacy terms as you read: phase doc → the spec; Chunks
table / Progress Log → `tasks.md`; Active Phases → Active Specs. Works the same in Kiro and
Copilot.

## Documentation Hierarchy

datomanager follows the same documentation discipline as datom.

```
.github/copilot-instructions.md     <- Entry point for AI/developers (conventions, quick start)
         |
dev/README.md                       <- This file: navigation hub, spec status
         |
dev/datomanager_scope.md            <- Companion package scope (gov lifecycle + migration)
dev/datomanager_overview.md         <- Access enforcement design (roles, grants, IAM; forward-looking)
dev/draft_managed_migration.md      <- gov_migrate_data() spec (first concrete deliverable)
         |
.kiro/specs/{feature}/              <- Active work: requirements.md, design.md, tasks.md
```

The authoritative datom design docs live in the sibling repo: `../datom/dev/`
(`datom_specification.md`, `datom_pathways.md`, `daapr_architecture.md`). Read
those for the platform contract datomanager builds on.

## START HERE (new session)

1. Read `.github/copilot-instructions.md` (conventions, prefix=package, no `:::`).
2. Read `dev/datomanager_scope.md` (scope + activation ordering + rename map).
3. Read `dev/draft_managed_migration.md` (the first concrete feature, Phase 19).
4. Skim `../datom/dev/README.md` for the chunk workflow + completion procedure.

**The scaffold (Phase 0) is done. The datom side of the GOV_SEAM lift-out has now
landed** (datom `main` @ `a62ad5f`, installed locally as datom 0.0.0.9001: the five gov
exports are removed; `datom_repo_attach_governance()` / `datom_repo_delete()` are present).
The datom change window is therefore **open** and the datomanager side of the lift-out is
**ready to start**. See the roadmap below.

## Relationship to datom

- **Dependency direction is one-way**: datomanager Imports datom; datom never
  depends on datomanager. Every cross-package call goes through an exported
  `datom::datom_*()` symbol -- no `:::`.
- **Prefix = package**: `gov_*` and `access_*` symbols are owned by datomanager;
  `datom_*` by datom. No symbol is exported by both packages.
- **datom is not modified by datomanager work** unless a spec explicitly calls
  for it (the GOV_SEAM lift-out is the first such spec).

> **Doc provenance note**: `datomanager_scope.md`, `datomanager_overview.md`, and
> `draft_managed_migration.md` were authored inside `datom/dev/` and copied here
> as datomanager's own home copies. The datom-side copies remain in place because
> datom is not being changed yet. When datom is next touched, reduce the
> datom-side copies to pointers to avoid drift. Until then, **this folder is the
> source of truth for datomanager design**; keep the two copies reconciled if
> either changes.

## Current Development State

### Active Specs

| Spec | Started | Status | Location |
|------|---------|--------|----------|
| gov-seam-liftout (datomanager side) | 2026-06-13 | requirements + design + contract done; **tasks.md pending** (next action). datom side landed (datom 0.0.0.9001); datomanager side ready to start. | `.kiro/specs/gov-seam-liftout/` |

### Completed Phases

| Phase | Completed | Tests | Summary |
|-------|-----------|-------|---------|
| Phase 0: Package Scaffold | 2026-06-10 | 3 | Installable, check-clean empty package. `DESCRIPTION` (`Imports: datom`), package doc, MIT license, smoke test asserting datom's six Phase 22 platform exports are reachable, README/NEWS, dev hub + copilot-instructions, and the three design docs copied from datom. `R CMD check`: 0 errors / 0 warnings / 2 benign notes (future-timestamp; "Imports: datom not yet used" -- clears with the first `gov_*` function). No datom source changes. |

### Roadmap (planned, not started)

| Step | Summary | Prereq |
|------|---------|--------|
| GOV_SEAM lift-out | **Now specced** (`.kiro/specs/gov-seam-liftout/`). datom (lands first): add `conn$gov_backend`, decouple `datom_init_repo()` from gov registration, remove the 5 exported gov functions + 9 internal gov-write helpers. datomanager (second): **reimplement** the 9 gov-write helpers natively (pure separation -- git2r + own storage IO, not a code move) and export the 5 `gov_*` functions (`gov_init`/`gov_attach`/`gov_decommission`/`gov_sync_dispatch`/`gov_pull`). `datom_repo_delete()` stays in datom. See the spec contract for the cross-repo execution sequence. **datom side landed (a62ad5f / datom 0.0.0.9001); datomanager side ready to start -- author tasks.md first.** | done (datom landed) |
| Phase 19: `gov_migrate_data()` | Governed migration verb: atomic copy + `ref.json` switch + migration-history record. Orchestrates datom's Phase 22 storage API; gov writes behind `# GOV_SEAM:`. Full spec in `draft_managed_migration.md`. 2-3 sessions. | Lift-out |
| Access enforcement | Roles, grants, IAM-backed access points gating `datom_read()`. `access_*` surface. Design in `datomanager_overview.md`. | Phase 19 |

## Environment note (workspace path quirk)

If BOTH `..../dev` and `..../dev/datom` are open as workspace roots at the same
time, file-editing tools (and `execute_bash` `cwd`) misroute any
`..../dev/datomanager/...` path to `..../dev/datom/anager/...` -- because the
string `dev/datom` is a prefix of `dev/datomanager`. To avoid it, open only
`..../dev` (datom and datomanager both reachable beneath it) OR only the package
you are editing. Shell commands with `cwd` pinned to `..../dev` and relative
`datomanager/...` paths are unaffected.

## Development Workflow

datomanager inherits datom's chunk-based, **spec-driven** workflow. See
`.github/copilot-instructions.md` for conventions and `../datom/dev/README.md`
for the full chunk lifecycle, delivery checklist, branch workflow, and spec
completion procedure -- they apply here verbatim.

Key reminders:

1. Multi-step work gets a spec (`.kiro/specs/{feature}/`) + feature branch before any code.
2. Every chunk-completing commit checks off the task in `tasks.md` in the same commit.
3. Full test suite (`devtools::test()`) before every commit; report the count.
4. One logical change per commit; check in before implementing; stop at chunk
   checkpoints for explicit go-ahead.
