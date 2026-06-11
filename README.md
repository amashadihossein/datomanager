# datomanager

<!-- badges: start -->
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

**datomanager** is the companion governance package for
[datom](../datom). datom owns version-controlled table storage; datomanager
owns the *governed* layer on top of it:

- **Gov lifecycle writes** -- governance repo bootstrap, project registration,
  dispatch routing, decommissioning.
- **Managed migration** -- `gov_migrate_data()`: atomic data copy + `ref.json`
  switch + migration-history record.
- **Access enforcement** (further out) -- roles, grants, and IAM-backed storage
  access points that gate `datom_read()`.

## Design principle: prefix = package

A function's prefix tells you which package owns it:

| Prefix | Package | Surface |
|---|---|---|
| `datom_*` | datom | Platform mechanics, all reads, solo-project self-serve writes |
| `gov_*` | datomanager | Governed lifecycle writes (init, attach, decommission, dispatch, migrate) |
| `access_*` | datomanager (future) | Access enforcement (roles, grants, IAM) |

The dependency direction is one-way: **datomanager Imports datom; datom never
depends on datomanager.** Every cross-package call goes through an exported
`datom::datom_*()` symbol -- no `:::`. datom remains fully functional without
datomanager installed.

## Status

Pre-creation scaffold. No `gov_*` functions exist yet. See `dev/README.md` for
the development hub and `dev/datomanager_scope.md` for the full scope.

## Installation

``` r
# install.packages("pak")
pak::pak("amashadihossein/datomanager")
```
