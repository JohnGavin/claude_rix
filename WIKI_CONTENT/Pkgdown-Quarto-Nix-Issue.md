# Known Issue: pkgdown with Quarto Vignettes in Nix

> **Status**: Documented and resolved via workaround
> **Severity**: High (blocks local pkgdown builds)
> **Impact**: All R packages using Nix + pkgdown + Quarto vignettes
> **Solution**: Use r-lib/actions in CI instead of Nix for pkgdown

---

## Quick Summary

**The Problem**: `pkgdown::build_site()` fails when building Quarto (`.qmd`) vignettes in a Nix environment.

**The Cause**: Fundamental incompatibility between:
1. Nix's immutable `/nix/store` (read-only by design)
2. bslib package's behavior (copies JS/CSS files during runtime)
3. Quarto vignettes requiring Bootstrap 5/bslib

**The Solution**: Use **native R (r-lib/actions)** in GitHub Actions for pkgdown, while keeping Nix for all other development tasks.

---

## Error Symptoms

```r
pkgdown::build_site()
# Error: [EACCES] Failed to copy
#   '/nix/store/.../bslib/lib/bs5/dist/js/bootstrap.bundle.min.js'
#   to '/private/tmp/.../bootstrap.bundle.min.js': Permission denied
```

Or:

```r
# Warning messages:
# 1: In file.copy(...):
#   problem copying /nix/store/.../bslib/.../bootstrap.bundle.min.js
#   Permission denied
```

---

## Why This Happens

### The Nix Immutability Model

Nix stores all packages in `/nix/store/`, which is:
- ✅ **Read-only** - ensures reproducibility
- ✅ **Content-addressed** - versions verified by hash
- ❌ **Cannot be modified** - runtime writes forbidden

### How bslib Works

The bslib R package:
1. Ships with Bootstrap 5 JS/CSS assets in its package directory
2. During vignette rendering, **copies these files** to temp directories
3. Requires **write access** to its own package files

### The Incompatibility

```
Quarto vignettes → require Bootstrap 5 → require bslib →
requires file copying → BLOCKED by Nix immutability
```

This is not a bug in any component - it's a fundamental design conflict.

---

## What We Tried (All Failed)

### ❌ Attempt 1: Disable bslib in _pkgdown.yml

```yaml
template:
  bootstrap: 5
  bslib:
    enabled: false  # Doesn't work - Quarto still loads bslib
```

**Result**: Failed - Quarto renders vignettes and ignores this setting

### ❌ Attempt 2: Use Bootstrap 3 Template

```yaml
# No template section = Bootstrap 3
```

**Result**: Failed - Quarto vignettes **require** Bootstrap 5

### ❌ Attempt 3: Install bslib to Writable Location

```r
local_lib <- file.path(tempdir(), "local-lib")
install.packages("bslib", lib = local_lib)
```

**Result**: Failed - Nix blocks `install.packages()`

### ❌ Attempt 4: Pre-render Vignettes

```r
quarto::quarto_render("vignettes/my-vignette.qmd")
```

**Result**: Failed - Requires package installation (same Nix restriction)

---

## The Solution: Hybrid Workflow

### Use Different Tools for Different Tasks

| Task | Tool | Why |
|------|------|-----|
| Package development | **Nix** | Reproducibility, consistency |
| R CMD check | **Nix** | Same environment as local dev |
| Data pipelines | **Nix** | Reproducibility |
| pkgdown website | **r-lib/actions** | Needs writable package dirs |

### Implementation

#### Local Development (Nix)

```bash
# In nix-shell:
targets::tar_make()        # ✅ Works - data pipelines
devtools::load_all()       # ✅ Works - package dev
devtools::test()           # ✅ Works - testing
devtools::check()          # ✅ Works - R CMD check

# Build reference docs only (without vignettes):
pkg <- pkgdown::as_pkgdown(".")
pkgdown::init_site(pkg)
pkgdown::build_reference(pkg)  # ✅ Works
```

#### CI (GitHub Actions)

**File**: `.github/workflows/pkgdown.yml`

```yaml
name: pkgdown

on:
  push:
    branches: [ main, master ]
  workflow_dispatch:

jobs:
  pkgdown:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Quarto
        uses: quarto-dev/quarto-actions/setup@v2

      # Use r-lib/actions (native R), NOT Nix
      - name: Setup R
        uses: r-lib/actions/setup-r@v2
        with:
          use-public-rspm: true

      - name: Setup R dependencies
        uses: r-lib/actions/setup-r-dependencies@v2
        with:
          extra-packages: any::pkgdown, local::.
          needs: website

      # IMPORTANT: Clean docs/ before build
      - name: Clean docs directory
        run: rm -rf docs/

      - name: Build pkgdown site
        run: pkgdown::build_site_github_pages(new_process = FALSE, install = FALSE)
        shell: Rscript {0}

      - name: Deploy to GitHub pages
        if: github.event_name != 'pull_request'
        uses: JamesIves/github-pages-deploy-action@v4
        with:
          folder: docs
          branch: gh-pages
```

---

## Why This Solution Works

### r-lib/actions Advantages

1. ✅ **Writable package locations**: Installs to `R_LIBS_USER` (writable)
2. ✅ **Fast with caching**: pak + GitHub Actions cache (1-2 min)
3. ✅ **bslib works**: Can copy files without permission issues
4. ✅ **Quarto works**: Full Bootstrap 5/bslib support

### What You Sacrifice

- ❌ **Local pkgdown builds**: Cannot test full site locally
- ❌ **Pure Nix workflow**: Need two different environments

### What You Gain

- ✅ **Working website**: pkgdown builds successfully in CI
- ✅ **Reproducible dev**: Nix still used for all development
- ✅ **Consistent testing**: R CMD check still uses Nix
- ✅ **Fast CI**: Binary caches prevent rebuilds

---

## Related Issues

- [Issue #49](https://github.com/JohnGavin/statues_named_john/issues/49) - pkgdown permissions (root investigation)
- [Issue #55](https://github.com/JohnGavin/statues_named_john/issues/55) - PR with initial fix attempts
- [Issue #61](https://github.com/JohnGavin/statues_named_john/issues/61) - CI performance and final solution

---

## Technical Documentation

### In This Repository

- [`R/setup/pkgdown_nix_solution.R`](https://github.com/JohnGavin/statues_named_john/blob/main/R/setup/pkgdown_nix_solution.R) - Comprehensive technical analysis with test results
- [`R/setup/session_log_20251202_pkgdown_fix.R`](https://github.com/JohnGavin/statues_named_john/blob/main/R/setup/session_log_20251202_pkgdown_fix.R) - Implementation session log
- [`R/setup/nix_docs_updates_20251202.md`](https://github.com/JohnGavin/statues_named_john/blob/main/R/setup/nix_docs_updates_20251202.md) - Documentation of updates to general Nix guides

### General Nix Documentation

- [NIX_TROUBLESHOOTING.md](https://github.com/JohnGavin/docs_gh/claude_rix/blob/main/NIX_TROUBLESHOOTING.md#pkgdown-with-quarto-vignettes) - Troubleshooting guide
- [NIX_WORKFLOW.md](https://github.com/JohnGavin/docs_gh/claude_rix/blob/main/NIX_WORKFLOW.md#known-limitations) - Known limitations section

---

## Workflow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    DEVELOPMENT WORKFLOW                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  LOCAL (Nix Shell)                                              │
│  ═════════════════                                              │
│  ✅ targets::tar_make()      → Data pipelines                   │
│  ✅ devtools::load_all()     → Package development              │
│  ✅ devtools::test()         → Unit testing                     │
│  ✅ devtools::check()        → R CMD check                      │
│  ✅ pkgdown reference only   → Function docs (no vignettes)     │
│                                                                 │
│  ❌ pkgdown::build_site()    → CANNOT work (Nix limitation)     │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  CI/CD (GitHub Actions)                                         │
│  ═══════════════════════                                        │
│                                                                 │
│  R-CMD-check workflow:                                          │
│    Uses: Nix environment                                        │
│    ✅ devtools::check()                                         │
│    ✅ Reproducible testing                                      │
│                                                                 │
│  pkgdown workflow:                                              │
│    Uses: r-lib/actions (native R)                               │
│    ✅ pkgdown::build_site()                                     │
│    ✅ Full website with Quarto vignettes                        │
│    ✅ Deploys to GitHub Pages                                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Key Takeaways

### For Developers

1. ✅ **Accept the limitation**: pkgdown with Quarto vignettes won't work in Nix
2. ✅ **Use the hybrid approach**: Nix for dev, r-lib/actions for pkgdown
3. ✅ **Test locally what you can**: Everything except full pkgdown builds
4. ✅ **Trust CI for pkgdown**: Let GitHub Actions build the website

### For Package Maintainers

1. ✅ **Document clearly**: Explain why different workflows for different tasks
2. ✅ **Set expectations**: Contributors need CI access to see pkgdown results
3. ✅ **Keep it simple**: Don't over-engineer solutions to unfixable problems

### For Nix Users

1. ✅ **Nix is still valuable**: Provides reproducibility where it matters most
2. ✅ **Not everything fits Nix**: Some tools need runtime mutability
3. ✅ **Hybrid workflows are okay**: Use the right tool for each job

---

## Questions?

If you encounter this issue or have questions:

1. Check the [technical analysis](https://github.com/JohnGavin/statues_named_john/blob/main/R/setup/pkgdown_nix_solution.R)
2. Review [Issue #49 discussion](https://github.com/JohnGavin/statues_named_john/issues/49)
3. Read [NIX_TROUBLESHOOTING.md](https://github.com/JohnGavin/docs_gh/claude_rix/blob/main/NIX_TROUBLESHOOTING.md#pkgdown-with-quarto-vignettes)
4. Open a new issue with the `nix` and `pkgdown` labels

---

**Last Updated**: December 2, 2025
**Affects**: All R packages using Nix + pkgdown + Quarto vignettes
**Status**: Workaround implemented and documented
