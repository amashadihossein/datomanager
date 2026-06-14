# Requirements Document

_Scope: **datomanager side** of the GOV_SEAM lift-out._

## Introduction

The GOV_SEAM lift-out is one atomic, coordinated change across two R packages. This
document specifies the changes **owned by `datomanager`** (the governance layer): receiving
the nine GOV_SEAM write helpers, exporting the five renamed `gov_*` functions, implementing
the `gov_decommission()` orchestration that reuses datom's data-side helpers, performing gov
registration in `gov_attach()`, and relocating the tests for the moved write surface.

The complementary subtractive changes in `datom` (removing the relocated helpers and
exports, extracting `datom_repo_delete()`, decoupling `datom_init_repo()`) are specified in
`datom/.kiro/specs/gov-seam-liftout/requirements.md`.

## Cross-Package Contract

The durable, bidirectional invariants that bind `datom` and `datomanager` — dependency
direction, prefix-equals-package, cross-package call discipline, the two-repos invariant,
the commit-message audit contract, and the `datom_conn` interface contract — are specified
in `contract.md` in this spec folder (a mirror of datom's source-of-truth copy). This
document covers only the one-time, datomanager-owned migration changes. Where a requirement
below realizes datomanager's side of a contract invariant, it cites the contract clause (for
example, C3, C4, C5).

## Glossary

- **Datom_Package**: The `datom` R package — the platform layer providing data read/write,
  versioning, git sync, and the `datom_storage_*` / `datom_repo_*` exports.
- **Datomanager_Package**: The `datomanager` R package — the governance layer that Imports
  Datom_Package and owns governed lifecycle writes (`gov_*`) and future access enforcement
  (`access_*`).
- **GOV_SEAM_Write_Helper**: An internal (`.datom_gov_*`) function that writes to the gov
  repo or gov storage. There are nine in scope for the move.
- **Gov_Clone**: The local working copy of the governance repository. Gov writes commit only
  to this clone.
- **Data_Repo**: A project's data repository (its `project.yaml` and data clone). Only
  Datom_Package mutates the Data_Repo.
- **Solo_Project**: A project whose location authority is `project.yaml` in the Data_Repo;
  no governance attached.
- **Governed_Project**: A project whose location authority is `ref.json` in the gov repo.
- **gov_decommission**: The Datomanager_Package function (renamed from
  `datom_decommission()`) that performs governance teardown and orchestrates the data-side
  teardown via Datom_Package helpers.

## Requirements

### Requirement 1: Implement the gov-write helpers natively in datomanager

**User Story:** As a datomanager maintainer, I want the nine gov-write helper behaviors
implemented natively in datomanager using its own git and storage tooling, so that the
governed write surface is owned by the governance package without reaching into datom
internals.

#### Acceptance Criteria

1. THE Datomanager_Package SHALL provide exactly the nine gov-write helper behaviors named
   `.datom_gov_commit()`, `.datom_gov_push()`, `.datom_gov_pull()`,
   `.datom_gov_write_dispatch()`, `.datom_gov_write_ref()`, `.datom_gov_register_project()`,
   `.datom_gov_unregister_project()`, `.datom_gov_record_migration()`, and
   `.datom_gov_destroy()`, and no additional `.datom_gov_*` write helper.
2. THE Datomanager_Package SHALL place these helpers in `R/utils-gov.R`, keep them internal,
   and exclude them from the `NAMESPACE` export list.
3. THE Datomanager_Package SHALL make each helper behavior-equivalent to the former
   Datom_Package helper (argument names, argument order, return value, and gov write side
   effect), reimplemented natively rather than depending on Datom_Package internals.
4. THE Datomanager_Package SHALL perform all gov-repo git operations within these helpers
   using its own git tooling (for example `git2r`) on `conn$gov_local_path`, authenticating
   with `conn$github_pat`, and SHALL NOT call Datom_Package for any gov-repo git operation
   (contract C7).
5. THE Datomanager_Package SHALL write gov files to gov storage using its own storage IO
   conforming to the gov storage layout and serialization, and SHALL NOT call Datom_Package
   for gov-storage IO (contract C8).
6. WHEN any of these helpers commits to the Gov_Clone, THE Datomanager_Package SHALL use the
   commit messages defined by the commit-message audit contract (C5).

### Requirement 2: Export the five renamed gov functions

**User Story:** As a governance user, I want the exported gov functions to use the `gov_*`
prefix in datomanager, so that the prefix identifies the owning package (contract C2).

#### Acceptance Criteria

1. THE Datomanager_Package SHALL export `gov_init()` that accepts the same argument names as
   the former `datom_init_gov()` and produces the same return value and the same Gov_Clone
   side effects, preserving the commit-message audit contract (C5) for any gov-repo commit
   it performs.
2. THE Datomanager_Package SHALL export `gov_attach()` that accepts the same argument names
   as the former `datom_attach_gov()` and produces the same return value and Gov_Clone side
   effects, including promotion of a Solo_Project to a Governed_Project, preserving the
   commit-message audit contract (C5).
3. THE Datomanager_Package SHALL export `gov_decommission()` that accepts the same argument
   names as the former `datom_decommission()` and produces the same governance-teardown
   return value and Gov_Clone side effects, preserving the commit-message audit contract
   (C5).
4. THE Datomanager_Package SHALL export `gov_sync_dispatch()` that accepts the same argument
   names as the former `datom_sync_dispatch()` and produces the same return value and
   Gov_Clone side effects, preserving the commit-message audit contract (C5).
5. THE Datomanager_Package SHALL export `gov_pull()` that accepts the same argument names as
   the former `datom_pull_gov()` and produces the same return value and Gov_Clone read
   result.
6. WHEN `gov_attach()` successfully promotes a Solo_Project, THE Datomanager_Package SHALL
   change the project's location authority from `project.yaml` in the Data_Repo to
   `ref.json` in the gov repo and register the project per the commit-message audit contract
   (C5).
7. IF `gov_attach()` is called on a conn that is already a Governed_Project, THEN THE
   Datomanager_Package SHALL abort without modifying gov state and return an error
   indicating the project is already governed.
8. IF any of `gov_init()`, `gov_attach()`, `gov_decommission()`, `gov_sync_dispatch()`, or
   `gov_pull()` is called with an argument that is not a `datom_conn` object providing the
   Conn_Interface_Contract fields, THEN THE Datomanager_Package SHALL abort without writing
   to the Gov_Clone and return an error indicating an invalid connection (contract C6).

### Requirement 3: gov_decommission orchestrates teardown across both packages

**User Story:** As a governance user, I want `gov_decommission()` to tear down both the data
side and the gov side, so that a single governed verb fully decommissions a Governed_Project.

#### Acceptance Criteria

1. WHEN `gov_decommission()` performs data-side teardown, THE gov_decommission SHALL call
   `datom::datom_repo_delete()` with `force_gov_attached = TRUE` and `confirm` equal to the
   conn's `project_name`.
2. WHEN `gov_decommission()` performs data-side namespace removal, THE gov_decommission
   SHALL call `datom::datom_storage_delete_prefix()`.
3. THE gov_decommission SHALL perform the gov unregister and gov-storage cleanup itself,
   using its own git tooling for the gov-repo unregister commit (C7) and its own storage IO
   for gov-storage cleanup (C8).
4. THE gov_decommission SHALL NOT mutate the Data_Repo directly (contract C4).
5. WHEN `gov_decommission()` runs, THE gov_decommission SHALL complete the data-side
   teardown steps before performing the gov unregister and gov-storage cleanup.
6. IF a data-side teardown step fails, THEN THE gov_decommission SHALL abort, leave the
   Gov_Clone unchanged, and return an error indicating which step failed.
7. IF a gov-side cleanup step fails after the data-side teardown has completed, THEN THE
   gov_decommission SHALL return an error stating that the data side was torn down but the
   gov cleanup did not complete, and identifying the failed step.

### Requirement 4: gov_attach performs gov registration

**User Story:** As a governance user, I want `gov_attach()` to perform the gov registration
that `datom_init_repo()` no longer does, so that attaching governance is the single path to
a Governed_Project.

#### Acceptance Criteria

1. WHEN `gov_attach()` is called, THE Datomanager_Package SHALL perform the gov registration
   step for the project using GOV_SEAM_Write_Helper functions.
2. WHEN `gov_attach()` registers a project, THE Datomanager_Package SHALL commit to the
   Gov_Clone with the message `Register project {name}` (contract C5).
3. THE Datomanager_Package SHALL NOT mutate the Data_Repo during `gov_attach()` except
   through an exported `datom::datom_repo_*()` helper (contract C4).

### Requirement 5: Relocate the tests for the moved write surface

**User Story:** As a maintainer, I want the tests for the moved helpers to live in
datomanager, so that each package tests what it owns.

#### Acceptance Criteria

1. THE Datomanager_Package SHALL contain, under `tests/testthat`, tests covering all nine
   moved GOV_SEAM_Write_Helper functions (`.datom_gov_commit()`, `.datom_gov_push()`,
   `.datom_gov_pull()`, `.datom_gov_write_dispatch()`, `.datom_gov_write_ref()`,
   `.datom_gov_register_project()`, `.datom_gov_unregister_project()`,
   `.datom_gov_record_migration()`, `.datom_gov_destroy()`), including `test-utils-gov.R`.
2. WHEN Datomanager_Package tests require gov registration, THE Datomanager_Package tests
   SHALL trigger it through `gov_attach()` rather than through `datom::datom_init_repo()`.
3. WHEN the Datomanager_Package test suite is run after the lift-out, THE
   Datomanager_Package SHALL report zero failing tests for the relocated helpers.

### Requirement 6: datomanager passes R CMD check clean after the lift-out

**User Story:** As a maintainer, I want datomanager to pass check cleanly, so that the
coordinated change is releasable.

#### Acceptance Criteria

1. WHEN `R CMD check` is run on Datomanager_Package after the lift-out, THE
   Datomanager_Package SHALL report zero errors and zero warnings.
2. WHEN the first `gov_*` function references Datom_Package, THE Datomanager_Package SHALL
   no longer produce the "Imports: datom not yet used" check note.
3. WHEN `R CMD check` is run on Datomanager_Package after the lift-out, THE
   Datomanager_Package SHALL report no check note other than a benign system-time
   verification note (a note arising solely from the build host clock or a future file
   timestamp, e.g. "unable to verify current time").

### Requirement 7: Bounded reach into datom

**User Story:** As a maintainer, I want datomanager's dependence on datom confined to a
small documented surface, so that gov git and gov storage stay fully owned by datomanager
and the packages can evolve independently.

#### Acceptance Criteria

1. THE Datomanager_Package SHALL reach into Datom_Package only via the Conn_Interface_Contract
   fields (C6) and the exported `datom_repo_*` and `datom_storage_*` functions used for
   Data_Repo and data-storage operations (for example during decommission and migration).
2. THE Datomanager_Package SHALL NOT call any Datom_Package function to perform a gov-repo
   git operation (C7).
3. THE Datomanager_Package SHALL NOT call any Datom_Package function to perform gov-storage
   IO; it implements gov-storage read/write itself conforming to C8.
4. THE Datomanager_Package SHALL NOT use the `datom:::` operator (C3).
5. THE Datomanager_Package SHALL select the gov storage backend from `conn$gov_backend`,
   not by inferring it from `conn$gov_client` or any other field (C6, C8).
