# Targets-Based Pkgdown Solution for Nix Projects

> **Status**: Production-ready solution (December 2025)
> **First Implementation**: [statues_named_john](https://github.com/JohnGavin/statues_named_john)
> **Related Issues**: [#49](https://github.com/JohnGavin/statues_named_john/issues/49), [#61](https://github.com/JohnGavin/statues_named_john/issues/61)

## Quick Summary

**Problem**: Quarto vignettes + bslib + pkgdown cannot work in Nix (fundamental incompatibility with `/nix/store` read-only file system).

**Solution**: Use targets to pre-build vignettes locally/CI, commit HTML to git, pkgdown uses pre-built files (fast builds, no Quarto rendering needed).

**Result**:
- ✅ Fully automated vignette rendering
- ✅ Fast pkgdown builds (5-10 min vs 20+ min)
- ✅ Works with Nix locally
- ✅ Reproducible via targets pipeline

---

## Table of Contents

1. [The Problem](#the-problem)
2. [Why This Happens](#why-this-happens)
3. [The Solution Architecture](#the-solution-architecture)
4. [Implementation Guide](#implementation-guide)
5. [Workflow Details](#workflow-details)
6. [Benefits & Trade-offs](#benefits--trade-offs)
7. [Monitoring & Troubleshooting](#monitoring--troubleshooting)
8. [Decision Guidelines](#decision-guidelines)

---

## The Problem

### Symptoms

```r
pkgdown::build_site()
# Error: [EACCES] Failed to copy
#   '/nix/store/.../bslib/lib/bs5/dist/js/bootstrap.bundle.min.js'
#   to '/private/tmp/.../bootstrap.bundle.min.js': Permission denied
```

### Affected Combinations

❌ **This combination CANNOT work**:
- Nix environment (read-only `/nix/store`)
- pkgdown (documentation website generator)
- Quarto vignettes (`.qmd` files)
- Bootstrap 5 / bslib (styling library)

✅ **These combinations DO work**:
- Nix + pkgdown + Rmarkdown vignettes (no Quarto)
- Nix + pkgdown + no vignettes
- Native R + pkgdown + Quarto vignettes + bslib

---

## Why This Happens

### Root Cause: Three Immutable Constraints

1. **Nix Immutability**: `/nix/store` is read-only by design (ensures reproducibility)
2. **bslib Behavior**: Copies JS/CSS files from package installation to temp directories at runtime
3. **Quarto Requirements**: Requires Bootstrap 5, which requires bslib

### The Incompatibility Chain

```
Quarto vignettes → require Bootstrap 5 → require bslib →
requires file copying from /nix/store → BLOCKED (read-only) → FAILS
```

**This is not a bug** - it's a fundamental architectural conflict between:
- Nix's immutability model (can't modify packages at runtime)
- bslib's operational requirements (must copy assets at runtime)

See also: [`NIX_TROUBLESHOOTING.md`](./NIX_TROUBLESHOOTING.md#pkgdown-with-quarto-vignettes)

---

## The Solution Architecture

### High-Level Strategy

**Separate concerns using different tools for different tasks**:

| Task | Tool | Environment | Why |
|------|------|-------------|-----|
| Package development | Nix | Local | Reproducibility |
| R CMD check | Nix | CI | Same as local |
| Data pipelines | Nix | Local + CI | Reproducibility |
| **Vignette rendering** | targets | Local (Nix) | Runs outside pkgdown |
| **pkgdown build** | r-lib/actions | CI | Uses pre-built vignettes |

### Dependency Chain

```
Data targets                    Vignette targets               pkgdown target
(memorial_analysis_plan)  →  (documentation_plan)  →  (documentation_plan)

fetch_data()
     ↓
process_data()
     ↓
analyze_data()              →    render_vignette_html          →    build_pkgdown_site
create_plots()                   (.qmd → inst/doc/*.html)           (uses pre-built HTML)
     ↓                                    ↓                              ↓
output objects                   Pre-built vignettes             Complete website
(for vignettes)                  (committed to git)              (fast build)
```

### Key Insight

**The breakthrough**: Render vignettes OUTSIDE of pkgdown:
- Quarto renders vignettes in Nix environment (works fine - not inside pkgdown)
- HTML committed to git
- pkgdown just copies pre-built HTML (no Quarto, no bslib issues)

---

## Implementation Guide

### Step 1: Create Documentation Plan

**File**: `R/tar_plans/documentation_plan.R`

```r
documentation_plan <- list(
  # Render vignette to HTML
  tar_target(
    vignette_my_analysis_html,
    {
      dir.create("inst/doc", recursive = TRUE, showWarnings = FALSE)

      quarto::quarto_render(
        input = "vignettes/my-analysis.qmd",
        output_file = "my-analysis.html",
        output_dir = "inst/doc",
        quiet = FALSE,
        execute_dir = "project"
      )

      normalizePath("inst/doc/my-analysis.html")
    },
    format = "file"
  ),

  # Build pkgdown site (depends on vignette HTML)
  tar_target(
    pkgdown_site,
    {
      stopifnot(file.exists(vignette_my_analysis_html))

      if (dir.exists("docs")) unlink("docs", recursive = TRUE)

      pkgdown::build_site(
        pkg = ".",
        preview = FALSE,
        install = FALSE,
        new_process = FALSE
      )

      "docs"
    },
    format = "file"
  )
)
```

### Step 2: Update _targets.R

```r
tar_option_set(
  packages = c(
    "yourpkg",
    # ... existing packages ...
    "quarto",      # For vignette rendering
    "pkgdown",     # For site building
    "sf"           # If using spatial data
  )
)

source("R/tar_plans/data_plan.R")
source("R/tar_plans/documentation_plan.R")  # NEW

list(
  data_plan,
  documentation_plan  # NEW
)
```

### Step 3: Update .gitignore

```
# targets cache (local only)
/_targets/

# Pre-built vignettes (COMMIT these!)
# inst/doc/*.html  # DO NOT ignore!
```

### Step 4: Update .Rbuildignore

```
^vignettes/        # Exclude source .qmd files
^_targets$
^_targets\.R$
# inst/doc/ is automatically included
```

### Step 5: Create GitHub Actions Workflow

**File**: `.github/workflows/targets-pkgdown.yml`

```yaml
name: targets + pkgdown (Automated)

on:
  push:
    branches: [ main, master ]
  workflow_dispatch:

permissions:
  contents: write
  pages: write

jobs:
  targets-pkgdown:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Quarto
        uses: quarto-dev/quarto-actions/setup@v2

      - name: Setup R
        uses: r-lib/actions/setup-r@v2
        with:
          use-public-rspm: true
          r-version: 'release'

      - name: Install system dependencies
        run: |
          sudo apt-get update -qq
          sudo apt-get install -y --no-install-recommends \
            libcurl4-openssl-dev \
            libssl-dev \
            libxml2-dev \
            libfontconfig1-dev \
            libharfbuzz-dev \
            libfribidi-dev \
            libfreetype6-dev \
            libpng-dev \
            libtiff5-dev \
            libjpeg-dev \
            libgit2-dev \
            libgdal-dev \
            libgeos-dev \
            libproj-dev \
            libudunits2-dev

      - name: Setup R dependencies
        uses: r-lib/actions/setup-r-dependencies@v2
        with:
          extra-packages: |
            any::targets
            any::tarchetypes
            any::quarto
            any::pkgdown
            local::.
          needs: website

      - name: Run targets pipeline
        run: Rscript -e 'targets::tar_make()'

      - name: Commit pre-built vignettes and site
        if: github.event_name != 'pull_request'
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add inst/doc/*.html docs/ || true

          if ! git diff --staged --quiet; then
            git commit -m "AUTO: Update pre-built vignettes and pkgdown site [skip ci]"
            git push
          fi

      - name: Deploy to GitHub Pages
        if: github.event_name != 'pull_request'
        uses: JamesIves/github-pages-deploy-action@v4
        with:
          folder: docs
          branch: gh-pages
```

---

## Workflow Details

### Local Development

```r
# 1. Edit vignette or data processing code
edit("vignettes/my-analysis.qmd")
edit("R/process_data.R")

# 2. Run targets (detects changes, rebuilds only what's needed)
targets::tar_make()
# → Fetches/processes data (if changed)
# → Renders vignette (if data or .qmd changed)
# → Builds pkgdown site (if vignette or code changed)

# 3. Preview site
pkgdown::preview_site()

# 4. Commit changes (including pre-built HTML)
gert::git_add(c(
  "vignettes/my-analysis.qmd",
  "R/process_data.R",
  "inst/doc/my-analysis.html"  # Pre-built vignette
))
gert::git_commit("Update analysis")
gert::git_push()
```

### CI/CD Execution

```
Push to main
    ↓
Setup (R, Quarto, system deps, R packages)
    ↓
targets::tar_make()
├─ Data targets (if sources changed)
├─ Vignette targets (if data or .qmd changed)
└─ pkgdown target (if vignettes or code changed)
    ↓
Commit inst/doc/*.html + docs/ [skip ci]
    ↓
Deploy docs/ to gh-pages
```

**Key Points**:
- Uses r-lib/actions (native R, not Nix)
- Pre-built vignettes in inst/doc/ used by pkgdown
- No Quarto rendering during pkgdown build (fast!)
- Auto-commits use `[skip ci]` to avoid loops

---

## Benefits & Trade-offs

### Benefits

✅ **Fully Automated**
- No manual vignette rendering
- No manual pkgdown builds
- One command: `targets::tar_make()`

✅ **Fast CI Builds**
- 5-10 minutes vs 20+ minutes
- Uses pre-built vignettes
- No compilation from source

✅ **Reproducible**
- Complete targets audit trail
- All outputs from pipeline
- Can reproduce any state

✅ **Cacheable**
- targets caches intermediate results
- Only rebuilds what changed
- Saves time and compute

✅ **Works with Nix Locally**
- Vignettes render in Nix shell
- No workarounds needed
- Full reproducibility maintained

### Trade-offs

⚠️ **Commits HTML to Git**
- Size: ~100-500 KB per vignette
- Mitigation: Git compression, only diffs tracked
- Common practice for complex vignettes

⚠️ **CI Makes Auto-Commits**
- Bot commits with "AUTO:" prefix
- Uses `[skip ci]` to avoid loops
- Only on main branch

⚠️ **Two-Step Process**
- Vignettes rendered separately from pkgdown
- Adds complexity vs traditional approach
- Well documented and automated

### Comparison with Alternatives

| Approach | Time | Complexity | Nix Compatible | Reproducible |
|----------|------|------------|----------------|--------------|
| **Pure Nix** | N/A | Low | Yes | Yes |
| Status | ❌ Impossible | - | - | - |
| **r-lib/actions (live render)** | 20+ min | Medium | No | Partial |
| Status | ⚠️ Works but slow | - | - | - |
| **targets + pre-build** | 5-10 min | Medium | Yes (local) | Yes |
| Status | ✅ **Recommended** | - | - | - |

---

## Monitoring & Troubleshooting

### Check Pipeline Status

```r
# What needs rebuilding?
targets::tar_outdated()

# What was built and when?
targets::tar_meta() %>%
  select(name, seconds, bytes, time) %>%
  arrange(desc(time))

# Visualize dependencies
targets::tar_visnetwork()
```

### Force Rebuild

```r
# Invalidate specific target
targets::tar_invalidate(vignette_my_analysis_html)
targets::tar_make()

# Rebuild everything
targets::tar_destroy()
targets::tar_make()
```

### Check Vignette Freshness

```r
vignette_qmd <- "vignettes/my-analysis.qmd"
vignette_html <- "inst/doc/my-analysis.html"

if (file.info(vignette_qmd)$mtime > file.info(vignette_html)$mtime) {
  warning("Vignette source newer than HTML - run targets::tar_make()")
}
```

### Common Issues

**Issue**: Vignette not updating

**Fix**:
```r
targets::tar_invalidate(vignette_my_analysis_html)
targets::tar_make()
```

**Issue**: pkgdown shows old vignette

**Fix**:
```r
# Clean and rebuild
unlink("docs", recursive = TRUE)
targets::tar_invalidate(pkgdown_site)
targets::tar_make()
```

**Issue**: CI "nothing to commit"

**Explanation**: Expected when targets cache prevents unnecessary rebuilds

**Action**: None needed - this is normal

---

## Decision Guidelines

### When to Use This Approach

✅ **Use targets + pre-build when**:
- Using Quarto vignettes (`.qmd` files)
- Using pkgdown for documentation
- Developing in Nix environment
- Need reproducibility + fast CI
- Have data processing pipeline

✅ **Also works well for**:
- Computationally expensive vignettes
- Vignettes with large datasets
- Vignettes requiring complex dependencies

### When NOT to Use This Approach

❌ **Don't use when**:
- Simple Rmarkdown vignettes (`.Rmd`) without Nix issues
- No Nix environment (use standard r-lib/actions)
- Very simple package with minimal vignettes
- No data processing pipeline (targets overhead not justified)

### Alternative for Non-Nix Projects

If NOT using Nix, standard r-lib/actions works fine:

```yaml
- name: Build pkgdown site
  run: Rscript -e 'pkgdown::build_site_github_pages(new_process = FALSE, install = FALSE)'
```

See: [NIX_VS_NATIVE_R_WORKFLOWS.md](./NIX_VS_NATIVE_R_WORKFLOWS.md) for complete decision guide.

---

## Real-World Example

**Project**: [statues_named_john](https://github.com/JohnGavin/statues_named_john)

**Setup**:
- Data from 3 APIs (GLHER, Wikidata, OpenStreetMap)
- Quarto vignette with interactive maps
- targets pipeline for data processing
- Nix environment for reproducibility

**Results**:
- CI time: 19+ minutes → 8 minutes
- Fully automated vignette updates
- Works perfectly in Nix locally
- Complete reproducibility maintained

**Files to Review**:
- [`R/tar_plans/documentation_plan.R`](https://github.com/JohnGavin/statues_named_john/blob/main/R/tar_plans/documentation_plan.R)
- [`.github/workflows/targets-pkgdown.yml`](https://github.com/JohnGavin/statues_named_john/blob/main/.github/workflows/targets-pkgdown.yml)
- [`_targets.R`](https://github.com/JohnGavin/statues_named_john/blob/main/_targets.R)

---

## Future Enhancements

### Parallel Vignette Rendering

```r
tar_target(
  all_vignettes,
  {
    vignettes <- list.files("vignettes", pattern = "\\.qmd$", full.names = TRUE)
    furrr::future_map_chr(vignettes, render_vignette)
  },
  pattern = map(vignettes),
  format = "file"
)
```

### Conditional Rendering

```r
tar_target(
  vignette_conditional,
  if (tar_older(vignette_html, data)) render_vignette() else vignette_html
)
```

### Multiple Output Formats

```r
tar_target(vignette_html, render_vignette(format = "html"))
tar_target(vignette_pdf, render_vignette(format = "pdf"))
```

---

## References

- **targets**: https://books.ropensci.org/targets/
- **pkgdown**: https://pkgdown.r-lib.org/
- **Quarto**: https://quarto.org/docs/computations/r.html
- **rix**: https://docs.ropensci.org/rix/
- **Nix**: https://nixos.org/manual/nix/stable/

## Related Documentation

- [`NIX_TROUBLESHOOTING.md`](./NIX_TROUBLESHOOTING.md#pkgdown-with-quarto-vignettes)
- [`NIX_WORKFLOW.md`](./NIX_WORKFLOW.md#known-limitations)
- [`NIX_VS_NATIVE_R_WORKFLOWS.md`](./NIX_VS_NATIVE_R_WORKFLOWS.md)
- [`AGENTS.md`](./AGENTS.md)

---

**Created**: December 2, 2025
**First Implementation**: statues_named_john package
**Status**: Production-ready, recommended approach
**Maintainer**: R + Nix development workflow team
