# datomanager Development Hub

## Documentation Hierarchy

datomanager follows the same documentation discipline as datom.

```
.github/copilot-instructions.md     <- Entry point for AI/developers (conventions, quick start)
         |
dev/README.md                       <- This file: navigation hub, phase status
         |
dev/datomanager_scope.md            <- Companion package scope (gov lifecycle + migration)
dev/datomanager_overview.md         <- Access enforcement design (roles, grants, IAM; forward-looking)
dev/draft_managed_migration.md      <- gov_migrate_data() spec (first concrete deliverable)
         |
dev/phase_{n}_{name}.md             <- Active development plans (temporary)
```

The authoritative datom design docs live in the sibling repo: `../datom/dev/`
(`datom_specification.md`, `datom_pathways.md`, `daapr_architecture.md`). Read
those for the platform contract datomanager builds on.

## START HERE (new session)

1. Read `.github/copilot-instructions.md` (conventions, prefix=package, no `:::`).
2. Read `dev/datomanager_scope.md` (scope + activation ordering + rename map).
3. Read `dev/draft_managed_migration.md` (the first concrete feature, Phase 19).
4. Skim `../datom/dev/README.md` for the chunk workflow + completion procedure.

**The scaffold (Phase 0) is done.** The next milestone is the **GOV_SEAM
lift-out**, and it *requires changing datom* -- so it only begins once a datom
change window is open. See the roadmap below.

## Relationship to datom

- **Dependency direction is one-way**: datomanager Imports datom; datom never
  depends on datomanager. Every cross-package call goes through an exported
  `datom::datom_*()` symbol -- no `:::`.
- **Prefix = package**: `gov_*` and `access_*` symbols are owned by datomanager;
  `datom_*` by datom. No symbol is exported by both packages.
- **datom is not modified by datomanager work** unless a phase explicitly calls
  for it (the GOV_SEAM lift-out is the first such phase).

> **Doc provenance note**: `datomanager_scope.md`, `datomanager_overview.md`, and
> `draft_managed_migration.md` were authored inside `datom/dev/` and copied here
> as datomanager's own home copies. The datom-side copies remain in place because
> datom is not being changed yet. When datom is next touched, reduce the
> datom-side copies to pointers to avoid drift. Until then, **this folder is the
> source of truth for datomanager design**; keep the two copies reconciled if
> either changes.

## Current Development State

### Active Phases

| Phase | Started | Status | Doc |
|-------|---------|--------|-----|
| -- | -- | No active phases | -- |

### Completed Phases

| Phase | Completed | Tests | Summary |
|-------|-----------|-------|---------|
| Phase 0: Package Scaffold | 2026-06-10 | 3 | Installable, check-clean empty package. `DESCRIPTION` (`Imports: datom`), package doc, MIT license, smoke test asserting datom's six Phase 22 platform exports are reachable, README/NEWS, dev hub + copilot-instructions, and the three design docs copied from datom. `R CMD check`: 0 errors / 0 warnings / 2 benign notes (future-timestamp; "Imports: datom not yet used" -- clears with the first `gov_*` function). No datom source changes. |

### Roadmap (planned, not started)

| Step | Summary | Prereq |
|------|---------|--------|
| GOV_SEAM lift-out | Move 9 `.datom_gov_*` write helpers from datom into datomanager; lift + rename the 5 exported gov functions to `gov_*` (`datom_init_gov`->`gov_init`, `datom_attach_gov`->`gov_attach`, `datom_decommission`->`gov_decommission`, `datom_sync_dispatch`->`gov_sync_dispatch`, `datom_pull_gov`->`gov_pull`); decouple `datom_init_repo()` from `.datom_gov_register_project()`. Extract `datom_repo_delete()` to stay in datom. **Requires changing datom (coordinated change window).** ~2 days. | datom change window |
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

datomanager inherits datom's chunk-based, phase-doc-driven workflow. See
`.github/copilot-instructions.md` for conventions and `../datom/dev/README.md`
for the full chunk lifecycle, delivery checklist, branch workflow, and phase
completion procedure -- they apply here verbatim.

Key reminders:

1. Multi-step work gets a phase doc + feature branch before any code.
2. Every chunk-completing commit updates the phase doc (Chunks table status,
   Status header, Progress Log) in the same commit.
3. Full test suite (`devtools::test()`) before every commit; report the count.
4. One logical change per commit; check in before implementing; stop at chunk
   checkpoints for explicit go-ahead.
