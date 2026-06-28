# Incoming vignettes from datom (placeholder — do NOT wire into the build yet)

These two articles were authored in `datom` before the GOV_SEAM lift-out, when datom still
owned the governance write surface. They describe **governance workflows** that now belong
to `datomanager`:

| File | Original datom group | Why it moved here |
|------|----------------------|-------------------|
| `governing-a-portfolio.Rmd` | "Govern" | Portfolio register + decommission discipline — pure gov workflow. |
| `auditing-reproducibility.Rmd` | "Govern" | Opens with `datom_pull_gov()` + `datom_projects()` portfolio snapshot; the rest (history / SHA pinning / validate) is datom-scoped and datomanager may fold a trimmed datom-only audit story back upstream later. |

## Status

- **Parked, not built.** They live under `dev/` (build-ignored via `.Rbuildignore`), so
  neither `R CMD build` nor pkgdown renders them. They are reference material for when
  datomanager grows its own vignette suite.
- They reference functions that datomanager has **not yet implemented** (e.g.
  `gov_pull()` / the former `datom_pull_gov`, `datom_decommission` -> `gov_decommission`,
  `datom_attach_gov` -> `gov_attach`). Every chunk is `eval = FALSE`, so they will not error,
  but the prose and function names need rewriting against datomanager's real API before they
  are promoted into `vignettes/`.

## Future work (when datomanager's gov surface is functional)

1. Rename all gov calls to datomanager's API (`gov_attach`, `gov_pull`, `gov_sync_dispatch`,
   `gov_decommission`, etc.).
2. Re-thread the user-journey continuity. The original journey arc and its
   `resume_article_*.R` setup scripts were parked on the datom side under
   `dev/vignettes-deferred/` (see the `vignettes-gov-liftout` spec in
   `datom/.kiro/specs/`). Preserve that arc so the cross-package story stays coherent.
3. Decide whether a trimmed, datom-only "audit & reproducibility" article (history, SHA
   pinning, `datom_validate`) should be re-authored back in datom — that content does not
   require governance.

## Provenance

Copied verbatim from `datom/vignettes/` as part of the `vignettes-gov-liftout` phase
(datom side executed via Copilot). The datom copies are removed by that spec once this
preservation is in place.
