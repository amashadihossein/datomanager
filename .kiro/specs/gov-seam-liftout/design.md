# Design Document: GOV_SEAM Lift-out (datomanager side)

## Overview

This design specifies how `datomanager` receives and reimplements the nine GOV_SEAM
write helpers, exports the five renamed `gov_*` functions, and passes `R CMD check`
cleanly against the new `datom` interface. The architecture is driven by two
non-negotiable constraints from the cross-package contract:

1. **Pure separation (D2):** datomanager reaches into datom for nothing gov-related.
   Gov-repo git uses its own `git2r`; gov-storage IO uses its own
   `paws.storage`/`jsonlite`/`fs` dispatch.
2. **Two-repos invariant (C4):** datomanager commits only to the gov clone; data-repo
   mutations only via `datom::datom_repo_*()` / `datom::datom_storage_*()`.

The result is a two-layer internal stack — a **git layer** (commit/push/pull on the gov
clone) and a **storage IO layer** (read/write JSON to gov storage) — composed by the
higher-level helpers and the five exported functions.

## Architecture

### Layer Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                      EXPORTED SURFACE (gov_*)                        │
│  gov_init  gov_attach  gov_decommission  gov_sync_dispatch  gov_pull│
│  R/init.R  R/init.R    R/decommission.R  R/sync.R          R/sync.R│
└──────────────┬──────────────────────────────────────────────────────┘
               │ orchestrates
┌──────────────▼──────────────────────────────────────────────────────┐
│              GOV-WRITE HELPERS (internal, R/utils-gov.R)             │
│  .datom_gov_commit        .datom_gov_push        .datom_gov_pull    │
│  .datom_gov_write_dispatch  .datom_gov_write_ref                    │
│  .datom_gov_register_project  .datom_gov_unregister_project         │
│  .datom_gov_record_migration  .datom_gov_destroy                    │
└──────────┬────────────────────────────┬─────────────────────────────┘
           │                            │
┌──────────▼──────────┐    ┌────────────▼────────────────────────────┐
│  GIT LAYER          │    │  GOV-STORAGE IO LAYER (R/utils-storage.R)│
│  (inline git2r)     │    │  .gov_storage_write_json                 │
│  pull/stage/commit  │    │  .gov_storage_read_json                  │
│  /push on gov_clone │    │  .gov_storage_delete_prefix              │
│  Auth: conn$        │    │  Dispatches on conn$gov_backend          │
│    github_pat       │    │  ("s3" → paws, "local" → fs/jsonlite)   │
└─────────────────────┘    └──────────────────────────────────────────┘

                     ┌────────────────────────────────────────────────┐
                     │  DATOM CROSS-PACKAGE CALLS (decommission only) │
                     │  datom::datom_repo_delete()                    │
                     │  datom::datom_storage_delete_prefix()          │
                     └────────────────────────────────────────────────┘
```

### File Layout

| File | Contents | Exported? |
|------|----------|-----------|
| `R/utils-gov.R` | 9 gov-write helpers (`.datom_gov_*`) | No |
| `R/utils-storage.R` | Gov-storage IO dispatch layer | No |
| `R/init.R` | `gov_init()`, `gov_attach()` | Yes |
| `R/decommission.R` | `gov_decommission()` | Yes |
| `R/sync.R` | `gov_sync_dispatch()`, `gov_pull()` | Yes |
| `R/utils-validate.R` | Conn validation, shared guard helpers | No |

## Components and Interfaces

### 1. Gov-Storage IO Layer (`R/utils-storage.R`)

The gov-storage IO layer provides backend-agnostic read/write/delete for gov
JSON objects. It dispatches on `conn$gov_backend` (never inferred).

#### Interface

```r
# Write an R list as JSON to gov storage.
# key: relative to gov namespace, e.g. "projects/{name}/dispatch.json"
.gov_storage_write_json(conn, key, data)

# Read and parse JSON from gov storage.
.gov_storage_read_json(conn, key)

# Delete all objects under a gov storage prefix.
.gov_storage_delete_prefix(conn, prefix_key)
```

#### Gov Namespace Resolution

The gov namespace is `{gov_prefix}/datom/` where `gov_prefix` is
`conn$gov_prefix` stripped of leading/trailing `/` (or `datom/` when
`gov_prefix` is empty or NULL). For S3, the full key is
`{gov_namespace}{key}` written to `conn$gov_root` (bucket). For local,
the full path is `{conn$gov_root}/{gov_namespace}{key}`.

```r
.gov_resolve_namespace <- function(conn) {

  prefix <- conn$gov_prefix
  if (is.null(prefix) || !nzchar(trimws(prefix))) return("datom/")
  paste0(gsub("^/+|/+$", "", prefix), "/datom/")
}
```

#### Backend Dispatch

```r
.gov_storage_write_json <- function(conn, key, data) {
  backend <- conn$gov_backend
  if (is.null(backend)) {
    cli::cli_abort("Cannot write to gov storage: {.field gov_backend} is NULL.")
  }
  switch(backend,
    s3    = .gov_s3_write_json(conn, key, data),
    local = .gov_local_write_json(conn, key, data),
    cli::cli_abort("Unsupported gov storage backend: {.val {backend}}")
  )
}
```

**S3 backend:** Uses `conn$gov_client` (a `paws.storage::s3()` client) to
`put_object` with the serialized JSON body, bucket = `conn$gov_root`,
key = `{gov_namespace}{key}`, content-type `application/json; charset=utf-8`.

**Local backend:** Writes to `{conn$gov_root}/{gov_namespace}{key}` using
`jsonlite::toJSON(data, auto_unbox = TRUE, pretty = TRUE)` via `writeLines()`.
Creates parent directories with `fs::dir_create()`.

#### Serialization Contract (C8)

All writes produce:
- UTF-8 encoded JSON
- Scalars unboxed (`auto_unbox = TRUE`)
- Pretty-printed (`pretty = TRUE`)
- `jsonlite::toJSON()` / `jsonlite::write_json()` with these flags

This ensures round-trip compatibility: what datomanager writes, datom's
`jsonlite::fromJSON(..., simplifyVector = FALSE)` parses identically.

### 2. Git Layer (inline in `R/utils-gov.R`)

Gov-repo git operations are performed directly via `git2r` calls within
the helpers. There is no separate "git layer" file — the pattern is simple
enough to inline. Each helper that touches git follows this sequence:

1. Open repo: `git2r::repository(conn$gov_local_path)`
2. Build credentials: `git2r::cred_user_pass("git", conn$github_pat)` for
   HTTPS remotes
3. Perform operation (fetch/merge, add/commit, push)

#### Key Git Patterns

**Pull (fetch + merge):**
```r
repo <- git2r::repository(gov_path)
remote_name <- git2r::remotes(repo)[[1L]]
remote_url <- git2r::remote_url(repo, remote_name)
cred <- git2r::cred_user_pass("git", conn$github_pat)
git2r::fetch(repo, name = remote_name, credentials = cred)
upstream <- git2r::branch_get_upstream(git2r::repository_head(repo))
if (!is.null(upstream)) {
  result <- git2r::merge(repo, upstream$name)
  if (isTRUE(result$conflicts)) cli::cli_abort(...)
}
```

**Commit (stage + commit):**
```r
repo <- git2r::repository(gov_path)
git2r::add(repo, paths, force = staged_deletions)
git2r::commit(repo, message = msg)
```

**Push:**
```r
repo <- git2r::repository(gov_path)
branch_name <- git2r::repository_head(repo)$name
git2r::push(repo, name = remote_name,
            refspec = glue::glue("refs/heads/{branch_name}"),
            credentials = cred)
```

#### Local Identity Guarantee

On first interaction with a gov clone (during `gov_init`), datomanager sets
local git identity via `git2r::config(repo, user.name = ..., user.email = ...)`
so that commits succeed on CI runners without global git config.

### 3. Gov-Write Helpers (`R/utils-gov.R`)

Nine internal helpers, behavior-equivalent to the former datom implementations.
Each is prefixed `.datom_gov_` for provenance traceability.

| Helper | Git ops | Storage ops | Commit message (C5) |
|--------|---------|-------------|---------------------|
| `.datom_gov_commit(conn, paths, msg, staged_deletions)` | pull → stage → commit | — | caller-supplied |
| `.datom_gov_push(conn)` | push | — | — |
| `.datom_gov_pull(conn)` | fetch + merge | — | — |
| `.datom_gov_write_dispatch(conn, project_name, dispatch)` | commit + push | write `projects/{name}/dispatch.json` | `Update dispatch for {name}` |
| `.datom_gov_write_ref(conn, project_name, ref)` | commit + push | write `projects/{name}/ref.json` | `Update ref for {name}` |
| `.datom_gov_register_project(conn, project_name, dispatch, ref)` | commit + push | write 3 files | `Register project {name}` |
| `.datom_gov_unregister_project(conn, project_name)` | commit (deletions) + push | — | `Unregister project {name}` |
| `.datom_gov_record_migration(conn, project_name, event)` | commit + push | write `projects/{name}/migration_history.json` | `Record migration for {name}: {summary}` |
| `.datom_gov_destroy(gov_local_path, force)` | — (local delete) | — | — |

#### Execution Pattern (compound helpers)

Each compound helper (write_dispatch, write_ref, register, unregister, record_migration)
follows:

1. Write file(s) to `{gov_local_path}/projects/{project_name}/`
2. `.datom_gov_commit(conn, rel_paths, msg)` — which pull-firsts internally
3. `.datom_gov_push(conn)`
4. Mirror to gov storage via `.gov_storage_write_json(conn, key, data)`

The pull-before-commit in `.datom_gov_commit` prevents diverged histories.
The push-after-commit ensures the gov remote stays current.

### 4. Conn Validation (`R/utils-validate.R`)

A shared guard used by all five exported functions:

```r
.gov_validate_conn <- function(conn) {
  required <- c("gov_local_path", "gov_root", "gov_prefix", "gov_region",
                "gov_backend", "gov_client", "github_pat", "project_name",
                "backend", "root", "prefix", "region")
  missing <- setdiff(required, names(conn))
  if (length(missing) > 0L) {
    cli::cli_abort(c(
      "Invalid connection: missing field{?s} {.field {missing}}.",
      "i" = "Pass a {.cls datom_conn} from {.fn datom::datom_get_conn}."
    ))
  }
  if (!inherits(conn, "datom_conn")) {
    cli::cli_abort(c(
      "Expected a {.cls datom_conn} object.",
      "i" = "Use {.fn datom::datom_get_conn} to obtain a connection."
    ))
  }
  invisible(conn)
}
```

### 5. Exported Functions

#### `gov_init(conn, gov_repo_url)`

Creates (or reuses) the gov clone at `conn$gov_local_path`.

```
gov_init(conn, gov_repo_url)
  1. .gov_validate_conn(conn)
  2. Clone or reuse: git2r::clone(gov_repo_url, conn$gov_local_path, credentials = cred)
     OR validate remote URL matches if clone already exists
  3. Ensure local git identity
  4. Return invisible(conn$gov_local_path)
```

No gov-storage writes. No commits. Idempotent.

#### `gov_attach(conn)`

Promotes a Solo_Project to a Governed_Project by registering it in the gov repo.

```
gov_attach(conn)
  1. .gov_validate_conn(conn)
  2. Guard: abort if project already registered (dir exists in gov clone)
  3. Build initial dispatch, ref, empty migration_history
  4. .datom_gov_register_project(conn, conn$project_name, dispatch, ref)
     → commits "Register project {name}", pushes, mirrors to storage
  5. Return invisible(TRUE)
```

Pre-condition: gov clone must exist (`gov_init` called first). The initial
`ref` is built from `conn$backend`, `conn$root`, `conn$prefix`, `conn$region`.
The initial `dispatch` is the default method-routing object.

#### `gov_decommission(conn)`

Tears down a Governed_Project: data-side first, then gov-side.

```
gov_decommission(conn)
  1. .gov_validate_conn(conn)
  2. Guard: abort if project NOT registered
  3. DATA-SIDE TEARDOWN (abort-on-failure, C4 via datom exports):
     a. datom::datom_storage_delete_prefix(conn, "projects/{name}")
        — removes data namespace from data storage
     b. datom::datom_repo_delete(conn, confirm = conn$project_name,
                                  force_gov_attached = TRUE)
        — deletes data GitHub repo + local clone
  4. GOV-SIDE CLEANUP (after data-side succeeds):
     a. .datom_gov_unregister_project(conn, conn$project_name)
        — deletes project dir from gov clone, commits "Unregister project {name}", pushes
     b. .gov_storage_delete_prefix(conn, "projects/{name}")
        — removes gov storage mirror for this project
  5. Return invisible(TRUE)
```

**Failure semantics:**
- If step 3a or 3b fails → abort, gov clone unchanged, error identifies failed step.
- If step 4a or 4b fails → error states data-side completed but gov cleanup incomplete;
  identifies the failed gov-side step for manual recovery.

#### `gov_sync_dispatch(conn, dispatch)`

Writes an updated dispatch.json to the gov clone + storage.

```
gov_sync_dispatch(conn, dispatch)
  1. .gov_validate_conn(conn)
  2. .datom_gov_write_dispatch(conn, conn$project_name, dispatch)
     → writes file, commits "Update dispatch for {name}", pushes, mirrors
  3. Return invisible(TRUE)
```

#### `gov_pull(conn)`

Pulls the gov clone from remote (fetch + fast-forward merge).

```
gov_pull(conn)
  1. .gov_validate_conn(conn)
  2. .datom_gov_pull(conn)
     → fetch + merge on gov clone
  3. Return invisible(TRUE)
```

## Data Models

### Gov Storage Objects (C8)

All objects live under `{gov_prefix}/datom/projects/{project_name}/`.

#### `ref.json`

```json
{
  "current": {
    "type": "s3",
    "root": "my-bucket",
    "prefix": "trial",
    "region": "us-east-1"
  },
  "previous": [
    {
      "type": "s3",
      "root": "old-bucket",
      "prefix": "trial",
      "region": "us-west-2",
      "migrated_at": "2026-06-15T14:30:00Z",
      "sunset_at": "2026-09-15T00:00:00Z"
    }
  ]
}
```

Fields with NULL value are omitted from the `current` object. `previous` is
ordered most-recent-first (prepend on migration).

#### `dispatch.json`

```json
{
  "default": "datom::datom_read",
  "methods": {}
}
```

The method-routing object that datom's dispatch reader consumes. Shape is
preserved exactly as datom produces/expects it.

#### `migration_history.json`

```json
[
  {
    "event_type": "data_migrated",
    "occurred_at": "2026-06-15T14:30:00Z",
    "from": { "type": "s3", "root": "old-bucket", "prefix": "trial" },
    "to": { "type": "s3", "root": "new-bucket", "prefix": "trial" }
  }
]
```

Array, most-recent-first. Each entry has at least `event_type` and
`occurred_at` (UTC, `YYYY-MM-DDTHH:MM:SSZ`).

### `datom_conn` Fields Read by datomanager (C6)

| Field | Type | Used by |
|-------|------|---------|
| `gov_local_path` | character | All git ops |
| `gov_root` | character | Storage IO (bucket or dir) |
| `gov_prefix` | character | Storage namespace resolution |
| `gov_region` | character | S3 client region |
| `gov_backend` | `"s3"` or `"local"` | Storage dispatch |
| `gov_client` | paws s3 client or NULL | S3 backend writes |
| `github_pat` | character | Git authentication |
| `project_name` | character | File paths, commit messages |
| `backend` | `"s3"` or `"local"` | Building initial ref |
| `root` | character | Building initial ref |
| `prefix` | character | Building initial ref |
| `region` | character or NULL | Building initial ref |

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid
executions of a system -- essentially, a formal statement about what the system should do.
Properties serve as the bridge between human-readable specifications and machine-verifiable
correctness guarantees.*

### Property 1: Gov-storage serialization round-trip

*For any* valid gov data object (dispatch list, ref list, or migration_history list),
writing it to gov storage via `.gov_storage_write_json` and reading it back via
`.gov_storage_read_json` SHALL produce an equivalent R object.

**Validates: Requirements 1.3, 1.5**

### Property 2: Commit-message audit conformance

*For any* valid `project_name` string and *for any* of the five gov-write operations
(register, unregister, write dispatch, write ref, record migration), the git commit
message on the gov clone SHALL be byte-for-byte equal to the corresponding C5 template
with `{name}` (and `{summary}` where applicable) substituted by literal string
replacement only.

**Validates: Requirements 1.6, 2.6, 4.2**

### Property 3: Registration creates correct gov state

*For any* valid `project_name`, after `gov_attach(conn)` succeeds, the gov clone SHALL
contain `projects/{project_name}/ref.json`, `projects/{project_name}/dispatch.json`, and
`projects/{project_name}/migration_history.json`, and the gov storage mirror SHALL
contain the same three objects with equivalent content.

**Validates: Requirements 2.6, 4.1**

### Property 4: Double-attach is rejected

*For any* `project_name` that is already registered in the gov clone, calling
`gov_attach(conn)` SHALL abort without modifying gov state and return an error.

**Validates: Requirements 2.7**

### Property 5: Invalid conn is rejected without side effects

*For any* R object that is not a `datom_conn` with all twelve Conn_Interface_Contract
fields present, calling any of `gov_init`, `gov_attach`, `gov_decommission`,
`gov_sync_dispatch`, or `gov_pull` SHALL abort without writing to the gov clone or gov
storage.

**Validates: Requirements 2.8**

### Property 6: Data-side failure leaves gov unchanged

*For any* registered project, if a data-side teardown step within `gov_decommission`
fails, the gov clone and gov storage SHALL remain unchanged from their state before the
call.

**Validates: Requirements 3.5, 3.6**

### Property 7: Backend dispatch follows conn$gov_backend

*For any* conn where `conn$gov_backend` is set to `"s3"` or `"local"`, gov-storage IO
SHALL route to the corresponding backend implementation regardless of the value of
`conn$gov_client` or any other conn field.

**Validates: Requirements 7.5**

## Error Handling

### Guard Clauses (fail-fast, no side effects)

All five exported functions validate the conn as their first action. Failure
produces a `cli_abort` with a message identifying the missing field(s) or
invalid type. No git or storage operation is attempted.

### Operational Errors

| Error source | Behavior |
|--------------|----------|
| Git fetch/merge conflict | `cli_abort` with "Merge conflict detected" |
| Git push failure (auth) | `cli_abort` referencing `conn$github_pat` |
| S3 put_object failure | `cli_abort` with bucket/key context |
| Local fs write failure | `cli_abort` with path |
| Project already registered (gov_attach) | `cli_abort`, no gov mutation |
| Project not registered (gov_decommission) | `cli_abort`, no mutation |

### gov_decommission Partial-Failure Semantics

`gov_decommission` is the only function with a multi-phase commit structure
(data-side then gov-side). The error contract:

1. **Data-side failure:** Entire operation aborts. Gov clone and gov storage
   are unchanged. Error message identifies the failed data-side step
   (repo_delete or storage_delete_prefix) and the underlying error.

2. **Gov-side failure (after data-side succeeded):** Error message explicitly
   states that data-side teardown completed successfully but gov cleanup
   failed. It identifies whether the git unregister or the storage cleanup
   failed. This allows manual recovery (the project dir still exists in the
   gov clone and/or gov storage).

### Idempotency Notes

- `gov_init`: Idempotent. If clone exists with matching remote, no-op.
- `gov_pull`: Idempotent. Fetch + merge is safe to repeat.
- `gov_sync_dispatch`: Idempotent. Overwrites dispatch.json with the new value.
- `gov_attach`: NOT idempotent. Aborts on second call (project exists guard).
- `gov_decommission`: NOT idempotent. Aborts if project not registered.

## Testing Strategy

### Approach

Testing uses a **dual strategy**: unit/integration tests for specific scenarios
and property-based tests for universal invariants.

The package uses `testthat` (edition 3). Property-based tests use the
`hedgehog` R package (Haskell-style QuickCheck for R), which provides
generators and the `forall` combinator.

### Test Files

| File | Tests |
|------|-------|
| `tests/testthat/test-utils-gov.R` | 9 internal helpers (git + storage side effects) |
| `tests/testthat/test-utils-storage.R` | Gov-storage IO dispatch layer |
| `tests/testthat/test-init.R` | `gov_init`, `gov_attach` |
| `tests/testthat/test-decommission.R` | `gov_decommission` |
| `tests/testthat/test-sync.R` | `gov_sync_dispatch`, `gov_pull` |

### Unit Tests (example-based)

- `gov_decommission` calls `datom::datom_repo_delete` with correct args (mock)
- `gov_decommission` calls `datom::datom_storage_delete_prefix` (mock)
- `gov_decommission` partial failure: data-side fails → error message format
- `gov_decommission` partial failure: gov-side fails → error message format
- `gov_init` clone-or-reuse: existing clone with matching remote → no-op
- `gov_init` clone-or-reuse: existing clone with wrong remote → abort
- Structural: all 9 helpers defined, internal, not in NAMESPACE
- Structural: no `datom:::` in R/ files

### Property-Based Tests

Each property test runs a minimum of **100 iterations** using `hedgehog::forall`.
Each test is tagged with a comment referencing its design property.

| Property | Test description | Generators |
|----------|-----------------|------------|
| 1 | Serialization round-trip | Random nested lists (dispatch-shaped, ref-shaped, history-shaped) |
| 2 | Commit-message audit | Random alphanumeric project_name strings; random event_type strings |
| 3 | Registration creates correct state | Random project_name; random ref/dispatch objects |
| 4 | Double-attach rejected | Random project_name (pre-registered) |
| 5 | Invalid conn rejected | Random lists missing 1+ of the 12 required fields |
| 6 | Data-side failure → gov unchanged | Random project_name with mocked data-side failure |
| 7 | Backend dispatch follows gov_backend | Random conn with gov_backend in {"s3", "local"} |

**Property test configuration:**
- Library: `hedgehog` (R property-based testing)
- Min iterations: 100 per property
- Tag format: `# Feature: gov-seam-liftout, Property {N}: {title}`

### Test Infrastructure

Tests use a **local git repo** (created in a `withr::local_tempdir()`) as the
gov clone — no network needed. The local backend (`conn$gov_backend = "local"`)
is used for storage IO tests. `mockery::stub` mocks `datom::datom_repo_delete`
and `datom::datom_storage_delete_prefix` in decommission tests.

A shared test helper (`tests/testthat/helper-gov.R`) provides:
- `make_test_gov_clone()`: creates a bare git repo + working clone in a tempdir
- `make_test_conn()`: builds a minimal `datom_conn` with all 12 fields populated
- `read_last_commit_message(repo_path)`: reads the HEAD commit message for
  assertion

### R CMD check

The package must pass `R CMD check --as-cran` with 0 errors, 0 warnings, and
no notes other than benign system-time verification notes. The `Imports: datom`
note clears because the exported functions call `datom::datom_repo_delete()` and
`datom::datom_storage_delete_prefix()`.

