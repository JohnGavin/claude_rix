# Issues Grouped by Similarity and Difficulty

**Ordered**: Easiest → Hardest (within and between groups)
**Last Updated**: 2025-12-08

---

## Group A: Documentation & Features
**Theme**: Improving documentation, adding visibility features, no deep logic changes.

### A1. Move nix-related documentation to repository wiki (#1)
- **Status**: Open
- **Difficulty**: ⭐ Easy
- **Effort**: 30-60 mins
- **Risk**: Very Low
- **What**: Migrate static markdown docs to the GitHub Wiki for better accessibility and cleaner repo.
- **Why**: Purely content movement.

### A2. Embed Quarto presentations in pkgdown documentation (#7)
- **Status**: Open
- **Difficulty**: ⭐⭐ Medium-Easy
- **Effort**: 1-2 hours
- **Risk**: Low
- **What**: Ensure `.qmd` presentations render correctly and are accessible within the pkgdown site structure.
- **Why**: Requires `pkgdown` configuration and potentially some `iframe` or file copy logic.

### A3. Display target source code in vignettes (#8)
- **Status**: Open
- **Difficulty**: ⭐⭐ Medium-Easy
- **Effort**: 1-2 hours
- **Risk**: Low
- **What**: Show the code behind targets in vignettes (e.g., using `tar_source()` or `knitr` chunk options) to make analysis transparent.
- **Why**: modifying vignette templates; standard `targets` functionality but needs integration.

---

## Group B: Bug Fixes
**Theme**: Correcting errors in existing scripts and logic.

### B1. Literal '$HOME' folders created due to shell escaping issues (#9)
- **Status**: Open
- **Difficulty**: ⭐ Easy
- **Effort**: 15-30 mins
- **Risk**: Low
- **What**: Fix shell script variable expansion (likely change single quotes to double quotes or fix variable reference).
- **Why**: Isolated syntax fix in a shell script.

### B2. `default.sh` does not correctly handle `default.nix` generation and updates (#3)
- **Status**: Open
- **Difficulty**: ⭐⭐ Medium
- **Effort**: 1-2 hours
- **Risk**: Medium (Affects environment setup)
- **What**: Ensure the entry point script correctly detects when to regenerate nix files or handle updates.
- **Why**: Bash logic flow control, testing environment bootstrap.

---

## Group C: Infrastructure & Reorganization
**Theme**: Renaming, moving, and restructuring project assets.

### C1. Move shared development environment files from rix.setup to claude_rix (#4)
- **Status**: Open
- **Difficulty**: ⭐⭐ Medium-Easy
- **Effort**: 1-2 hours
- **Risk**: Low (Revertible)
- **What**: Consolidate setup files into the main repo to simplify the "two-tier" architecture.
- **Why**: File operations and updating paths in scripts.

### C2. Rename repository and folder from 'claude_rix' to 'projects' (#6, #2)
- **Status**: Open (Duplicate issues #2, #6)
- **Difficulty**: ⭐⭐⭐ Medium
- **Effort**: 2-3 hours
- **Risk**: Medium (Breaks remote links, requires local config updates)
- **What**: Rename the root directory and the GitHub repository.
- **Why**: simple concept, but "rename" in git/github involves updating remotes, CI/CD paths, and documentation references.

---

## Group D: Design & Architecture
**Theme**: Complex system design and implementation.

### D1. Robust strategy for generating project-specific default.nix from DESCRIPTION (#5)
- **Status**: Open
- **Difficulty**: ⭐⭐⭐⭐ Hard
- **Effort**: 10-15 hours
- **Risk**: Medium-High (Affects reproducibility of all projects)
- **What**: Design a system where `default.nix` is deterministically generated from `DESCRIPTION` files for each sub-project, possibly using templates or a master script.
- **Why**:
  - Requires architectural decisions (centralized vs decentralized).
  - Needs deep understanding of `rix`.
  - Must ensure consistent package versions across projects.
  - CI/CD integration.

---

## Recommended Implementation Plan

1.  **Quick Wins (Group A & B1)**:
    - Fix the `$HOME` bug (#9) immediately to prevent filesystem clutter.
    - Move docs (#1) to clear up the repo.

2.  **Infrastructure (Group C)**:
    - Move files (#4) to prep for the rename.
    - Rename repo (#6) - *Coordinate with user as this breaks URLs.*

3.  **Environment Stability (Group B2)**:
    - Fix `default.sh` (#3) to ensure the new infrastructure works reliably.

4.  **Feature Polish (Group A2, A3)**:
    - Implement vignette enhancements (#7, #8).

5.  **Core Architecture (Group D)**:
    - Tackle the `default.nix` generation strategy (#5) once the repo structure is stable.