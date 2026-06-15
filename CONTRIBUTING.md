# Contributing to datomanager

Thank you for your interest in contributing. datomanager is a pre-release
companion governance package for [datom](https://github.com/amashadihossein/datom)
-- things change frequently.

## Status

This package is under active development. APIs may change without notice. If you
are considering a large contribution, open an issue first to discuss whether it
fits the current roadmap.

## How to contribute

1. **Bug reports**: Open an issue using the bug report template. Include a
   minimal reproducible example.
2. **Feature requests**: Open an issue using the feature request template.
3. **Pull requests**:
   - Fork the repository and create a branch from `main`.
   - Install development dependencies: `devtools::install_dev_deps()`.
   - Make your changes with tests: `devtools::test()` must pass.
   - Run `devtools::check()` -- aim for 0 errors and 0 warnings.
   - Open a PR against `main` with a clear description of what changed and why.

## Development setup

```r
# Install datom first (datomanager depends on it)
# devtools::install_github("amashadihossein/datom")

# Install dependencies
devtools::install_dev_deps()

# Load the package for interactive development
devtools::load_all()

# Run tests
devtools::test()

# Full check
devtools::check()
```

## Code style

- Flat over nested: use early returns and guard clauses.
- Functional: `purrr::` over for-loops.
- Exported functions: `gov_verb()` or `access_verb()`. Internal functions:
  `.gov_verb()` or `.datom_gov_verb()` (for reimplemented helpers).
- Use `cli::` for user-facing messages, `fs::` for filesystem, `glue::glue()`
  for string interpolation, `git2r` for gov-repo git operations.
- **No `datom:::`** -- every cross-package call goes through an exported
  `datom::datom_*()` symbol. If datomanager needs something datom keeps internal,
  the fix is a new datom export (coordinated, in datom's repo).

## Issue resolution workflow

Every code change starts as a GitHub issue. Once an issue is assigned or
self-assigned, follow these steps:

1. **Understand the issue.** Read the full issue body and any linked comments.
   Assess validity critically -- check whether it is coherent with the current
   codebase, design, and the cross-package contract
   (`.kiro/specs/gov-seam-liftout/contract.md`).

2. **Scope the work and comment if needed.** If the proposed solution is
   unclear, incomplete, or requires clarification, post a scoping comment on the
   issue before writing any code.

3. **Create a branch.** Branch off `main` with a descriptive name:
   ```
   git checkout -b issue-{number}-{short-slug}
   ```

4. **Plan (for non-trivial changes).** If the fix touches more than two files
   or requires more than one logical commit, write a short plan before coding:
   - What needs to change and why.
   - Which tests and documentation need updating.
   - Any invariants or must-never rules to keep in mind.

   For large cross-cutting work, follow the spec-driven workflow described in
   `dev/README.md` and `.github/copilot-instructions.md`.

5. **Develop.** Make the change. Run `devtools::test()` (unfiltered) before
   every commit and include the test count in the commit message. If the count
   drops, something was lost. Keep commits small and logically focused.

6. **Clean up.** Before opening a PR:
   - Remove dead code, debug prints, and stray comments.
   - Update any affected documentation (`man/`, vignettes).
   - Run `devtools::check()` -- aim for 0 errors and 0 warnings.
   - Verify no `datom:::` usage crept in.

7. **Open a PR against `main`.** Include:
   - A `Closes #N` reference in the description.
   - A concise summary of what changed and why.
   - The test count delta (e.g. `tests: 42 (+7)`).

   Before a second attempt at any remote-mutating action (`git push`,
   `gh pr create`, etc.), verify remote state first (`gh pr list`,
   `git log --remotes`) to avoid duplicates.

## Questions

Open an issue or email the maintainer at <amashadihossein@gmail.com>.
