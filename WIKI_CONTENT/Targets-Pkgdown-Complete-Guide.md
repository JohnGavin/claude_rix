# Targets-Based Pkgdown Solution: Complete Implementation Guide

> **Purpose**: Complete step-by-step guide for implementing targets-based pkgdown automation
> **Status**: Production-ready (December 2025)
> **First Implementation**: [statues_named_john](https://github.com/JohnGavin/statues_named_john)

**→ Back to**: [Main Repo: TARGETS_PKGDOWN_OVERVIEW.md](https://github.com/JohnGavin/claude_rix/blob/main/TARGETS_PKGDOWN_OVERVIEW.md)

---

## Table of Contents

1. [Overview](#overview)
2. [When to Use This Approach](#when-to-use-this-approach)
3. [Complete Implementation](#complete-implementation)
4. [Step-by-Step Setup](#step-by-step-setup)
5. [Local Development Workflow](#local-development-workflow)
6. [CI/CD Workflow](#cicd-workflow)
7. [Monitoring & Verification](#monitoring--verification)
8. [Troubleshooting](#troubleshooting)
9. [Real-World Examples](#real-world-examples)

---

## Overview

### The Problem

Quarto vignettes + bslib + pkgdown cannot work in Nix due to fundamental incompatibility:
- Nix: Read-only `/nix/store`
- bslib: Must copy files at runtime
- Quarto: Requires Bootstrap 5/bslib

**→ See**: [Known Issue: Pkgdown + Quarto + Nix](Pkgdown-Quarto-Nix-Issue)

### The Solution

Use targets to automate vignette rendering and pkgdown building:

```
Data targets → Vignette targets → pkgdown target
(reproducible)   (pre-built HTML)    (uses pre-built)
```

### Key Benefits

✅ **Fully automated** - no manual vignette rendering
✅ **Fast CI builds** - 5-10 minutes vs 20+ minutes
✅ **Reproducible** - complete targets audit trail
✅ **Cacheable** - only rebuilds what changed
✅ **Works with Nix locally** - vignettes render outside pkgdown

---

## When to Use This Approach

### ✅ Use targets + pre-build when:

- ✅ Using Quarto vignettes (`.qmd` files)
- ✅ Using pkgdown for documentation
- ✅ Developing in Nix environment
- ✅ Need reproducibility + fast CI
- ✅ Have data processing pipeline

### ✅ Also works well for:

- ✅ Computationally expensive vignettes
- ✅ Vignettes with large datasets
- ✅ Vignettes requiring complex dependencies

### ❌ Don't use when:

- ❌ Simple Rmarkdown vignettes (`.Rmd`) without Nix issues
- ❌ No Nix environment (use standard r-lib/actions)
- ❌ Very simple package with minimal vignettes
- ❌ No data processing pipeline (targets overhead not justified)

---

## Complete Implementation

### Architecture Overview

```
┌────────────────────────────────────────────────────────────┐
│                     TARGETS PIPELINE                        │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  Data Targets (memorial_analysis_plan)                     │
│  ┌──────────────────────────────────────────────────────┐ │
│  │ fetch_data() → process_data() → analyze_data()       │ │
│  │      ↓              ↓                  ↓              │ │
│  │  data.parquet   cleaned.parquet   results.parquet    │ │
│  └──────────────────────────────────────────────────────┘ │
│                          ↓                                  │
│  Documentation Targets (documentation_plan)                │
│  ┌──────────────────────────────────────────────────────┐ │
│  │ vignette_memorial_analysis_html                       │ │
│  │   - Input: vignettes/memorial-analysis.qmd            │ │
│  │   - Depends on: data targets                          │ │
│  │   - Output: inst/doc/memorial-analysis.html           │ │
│  │   - Tool: quarto::quarto_render()                     │ │
│  └──────────────────────────────────────────────────────┘ │
│                          ↓                                  │
│  ┌──────────────────────────────────────────────────────┐ │
│  │ pkgdown_site                                          │ │
│  │   - Depends on: vignette HTML                         │ │
│  │   - Output: docs/                                     │ │
│  │   - Tool: pkgdown::build_site()                       │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

### Dependency Chain Explanation

1. **Data Targets**: Process data, create analysis outputs
2. **Vignette Target**: Renders `.qmd` to HTML using data outputs
3. **pkgdown Target**: Builds website using pre-built HTML

**Key Insight**: Vignette rendering happens OUTSIDE of pkgdown, so:
- Quarto works (not inside pkgdown context)
- HTML committed to git
- pkgdown just copies pre-built HTML (fast, no Quarto needed)

---

## Step-by-Step Setup

### Step 1: Create Documentation Plan

**File**: `R/tar_plans/documentation_plan.R`

```r
documentation_plan <- list(
  # Track vignette source files
  tar_target(
    vignette_sources,
    {
      sources <- list.files("vignettes", pattern = "\\\\.qmd$", full.names = TRUE)
      stopifnot(length(sources) > 0)
      sources
    },
    format = "file"
  ),

  # Render memorial-analysis vignette to HTML
  tar_target(
    vignette_memorial_analysis_html,
    {
      # Create output directory
      dir.create("inst/doc", recursive = TRUE, showWarnings = FALSE)

      # Render using Quarto
      quarto::quarto_render(
        input = "vignettes/memorial-analysis.qmd",
        output_file = "memorial-analysis.html",
        output_dir = "inst/doc",
        quiet = FALSE,
        execute_dir = "project"  # Execute in project root (has access to data)
      )

      # Return path to rendered HTML
      normalizePath("inst/doc/memorial-analysis.html")
    },
    format = "file",
    cue = tar_cue(mode = "always", depend = TRUE)
  ),

  # Build pkgdown site (depends on vignette HTML)
  tar_target(
    pkgdown_site,
    {
      # Verify vignette exists
      stopifnot(file.exists(vignette_memorial_analysis_html))

      # Clean docs/ directory
      if (dir.exists("docs")) {
        message("Removing docs/ directory")
        unlink("docs", recursive = TRUE)
      }

      # Build site
      pkgdown::build_site(
        pkg = ".",
        preview = FALSE,
        install = FALSE,
        new_process = FALSE
      )

      "docs"
    },
    format = "file",
    cue = tar_cue(mode = "always", depend = TRUE)
  ),

  # Verify pkgdown build
  tar_target(
    pkgdown_verification,
    {
      # Check key files exist
      required_files <- c(
        "docs/index.html",
        "docs/articles/memorial-analysis.html"
      )

      missing <- required_files[!file.exists(required_files)]

      if (length(missing) > 0) {
        stop("pkgdown build incomplete. Missing files:\n",
             paste("  -", missing, collapse = "\n"))
      }

      # Return verification status
      list(
        status = "success",
        files_checked = length(required_files),
        timestamp = Sys.time()
      )
    }
  )
)
```

**Key Features**:
- **`vignette_sources`**: Tracks `.qmd` file changes
- **`vignette_memorial_analysis_html`**: Renders to HTML using Quarto
  - `format = "file"` ensures targets tracks file modification time
  - `execute_dir = "project"` gives vignette access to data
  - Output goes to `inst/doc/` (standard R package location)
- **`pkgdown_site`**: Builds website from pre-built HTML
  - Depends on vignette HTML (won't run until vignette ready)
  - Cleans `docs/` before build (prevents stale files)
- **`pkgdown_verification`**: Checks build succeeded

### Step 2: Update _targets.R

**File**: `_targets.R`

```r
library(targets)
library(tarchetypes)

# Set global options
tar_option_set(
  packages = c(
    "yourpackagename",     # Your package
    "dplyr",               # Data manipulation
    "tidyr",
    "stringr",
    "ggplot2",             # Plotting
    "lubridate",           # Dates
    "arrow",               # Parquet format
    "quarto",              # Vignette rendering (NEW)
    "pkgdown",             # Site building (NEW)
    "sf"                   # Spatial data (if needed)
  ),
  format = "parquet",      # Use parquet for data objects
  error = "continue"       # Continue on error (optional)
)

# Source plan files
source("R/tar_plans/data_plan.R")            # Your data processing
source("R/tar_plans/documentation_plan.R")   # NEW

# Combine plans
list(
  data_plan,
  documentation_plan   # NEW
)
```

**Key Changes**:
- Added `quarto` package (for vignette rendering)
- Added `pkgdown` package (for site building)
- Sourced `documentation_plan.R`
- Included in pipeline list

### Step 3: Update .gitignore

**File**: `.gitignore`

```gitignore
# targets cache (local only - DON'T commit)
/_targets/

# Pre-built vignettes (COMMIT these!)
# inst/doc/*.html  # ← DO NOT ignore! Explicitly commented out

# pkgdown site (DON'T commit - regenerated in CI)
/docs/

# Other standard ignores
.Rproj.user
.Rhistory
.RData
.Ruserdata
```

**Critical**:
- `_targets/` ignored (cache is local only)
- `inst/doc/*.html` **NOT ignored** (pre-built vignettes must be committed)
- `docs/` ignored (regenerated in CI)

### Step 4: Update .Rbuildignore

**File**: `.Rbuildignore`

```
^.*\.Rproj$
^\.Rproj\.user$
^_targets$
^_targets\.R$
^vignettes/.*\.qmd$
^\.github$
^docs$
```

**Key Points**:
- `^vignettes/.*\.qmd$` - Exclude source `.qmd` files from package
- `_targets` and `_targets.R` excluded
- `.github` excluded (workflows not in package)
- `inst/doc/*.html` **NOT excluded** (included in package automatically)

### Step 5: Create GitHub Actions Workflow

**File**: `.github/workflows/targets-pkgdown.yml`

```yaml
name: targets + pkgdown (Automated)

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]
  workflow_dispatch:

permissions:
  contents: write   # For pushing commits
  pages: write      # For deploying to GitHub Pages
  id-token: write   # For GitHub Pages deployment

jobs:
  targets-pkgdown:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

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
          sudo apt-get install -y --no-install-recommends \\
            libcurl4-openssl-dev \\
            libssl-dev \\
            libxml2-dev \\
            libfontconfig1-dev \\
            libharfbuzz-dev \\
            libfribidi-dev \\
            libfreetype6-dev \\
            libpng-dev \\
            libtiff5-dev \\
            libjpeg-dev \\
            libgit2-dev \\
            libgdal-dev \\
            libgeos-dev \\
            libproj-dev \\
            libudunits2-dev

      - name: Setup R dependencies
        uses: r-lib/actions/setup-r-dependencies@v2
        with:
          extra-packages: |
            any::targets
            any::tarchetypes
            any::quarto
            any::pkgdown
            any::rmarkdown
            local::.
          needs: website

      - name: Run targets pipeline (renders vignettes + builds pkgdown)
        run: Rscript -e 'targets::tar_make()'

      - name: Commit pre-built vignettes and pkgdown site
        if: github.event_name != 'pull_request'
        run: |
          git config user.name \"github-actions[bot]\"
          git config user.email \"github-actions[bot]@users.noreply.github.com\"

          # Stage outputs
          git add inst/doc/*.html docs/ || true

          # Only commit if there are changes
          if ! git diff --staged --quiet; then
            git commit -m \"AUTO: Update pre-built vignettes and pkgdown site [skip ci]\"
            git push
          else
            echo \"No changes to commit\"
          fi

      - name: Deploy to GitHub Pages
        if: github.event_name != 'pull_request'
        uses: JamesIves/github-pages-deploy-action@v4
        with:
          folder: docs
          branch: gh-pages
```

**Key Features**:
- **Uses r-lib/actions** (native R, not Nix) - bslib works here
- **Runs full pipeline** - `targets::tar_make()` does everything
- **Auto-commits outputs** - inst/doc/*.html and docs/
- **`[skip ci]`** in commit message - prevents infinite loops
- **Deploys to GitHub Pages** - JamesIves action for deployment

### Step 6: Disable Old pkgdown Workflow (Optional)

If you had an old `pkgdown.yml` workflow:

```bash
# Rename to disable
mv .github/workflows/pkgdown.yml .github/workflows/pkgdown.yml.old

# Or delete
rm .github/workflows/pkgdown.yml
```

---

## Local Development Workflow

### First-Time Setup

```r
# 1. Install targets
install.packages("targets")

# 2. Verify setup
targets::tar_manifest()  # Shows all targets
targets::tar_visnetwork()  # Visualizes dependencies
```

### Daily Workflow

```r
# 1. Edit vignette or data processing code
edit("vignettes/my-analysis.qmd")
edit("R/process_data.R")

# 2. Run targets (detects changes, rebuilds only what's needed)
targets::tar_make()
# → Fetches/processes data (if changed)
# → Renders vignette (if data or .qmd changed)
# → Builds pkgdown site (if vignette or code changed)

# 3. Check what was built
targets::tar_progress()
targets::tar_meta() %>%
  select(name, seconds, bytes, time) %>%
  arrange(desc(time))

# 4. Preview site
pkgdown::preview_site()
# Or open docs/index.html in browser

# 5. Commit changes (including pre-built HTML)
gert::git_add(c(
  "vignettes/my-analysis.qmd",
  "R/process_data.R",
  "inst/doc/my-analysis.html"  # Pre-built vignette
))
gert::git_commit("Update analysis with new data")
gert::git_push()
```

### What Happens When You Run tar_make()

```
targets::tar_make()
    ↓
1. Check what changed (source files, data)
    ↓
2. Identify outdated targets
    ↓
3. Run outdated targets in dependency order:
   ├─ Data targets (if data sources changed)
   ├─ Vignette targets (if data or .qmd changed)
   └─ pkgdown target (if vignettes or code changed)
    ↓
4. Cache results in _targets/
```

---

## CI/CD Workflow

### Trigger Events

Workflow runs on:
- Push to `main` or `master` branch
- Pull requests (build only, no commit/deploy)
- Manual trigger via `workflow_dispatch`

### Execution Flow

```
1. Checkout code
    ↓
2. Setup: Quarto, R, system dependencies, R packages
    ↓
3. Run targets::tar_make()
   ├─ Loads _targets/ cache (empty on first run)
   ├─ Runs data processing
   ├─ Renders vignettes
   └─ Builds pkgdown site
    ↓
4. Commit outputs (main branch only)
   ├─ inst/doc/*.html
   └─ docs/
    ↓
5. Deploy docs/ to gh-pages branch
```

### First Run vs Subsequent Runs

**First Run** (no cache):
- Runs ALL targets from scratch
- Takes 5-10 minutes
- Commits all outputs

**Subsequent Runs** (with cache):
- Checks what changed
- Only reruns changed targets
- Takes 1-3 minutes if nothing changed
- Commits only if outputs differ

---

## Monitoring & Verification

### Check Pipeline Status

```r
# What needs rebuilding?
targets::tar_outdated()

# What was built and when?
targets::tar_meta() %>%
  select(name, type, seconds, bytes, time) %>%
  arrange(desc(time)) %>%
  print(n = 20)

# Visualize dependencies
targets::tar_visnetwork()
```

### Verify Vignette Freshness

```r
# Check if vignette source is newer than HTML
vignette_qmd <- "vignettes/my-analysis.qmd"
vignette_html <- "inst/doc/my-analysis.html"

qmd_time <- file.info(vignette_qmd)$mtime
html_time <- file.info(vignette_html)$mtime

if (qmd_time > html_time) {
  warning("Vignette source newer than HTML - run targets::tar_make()")
} else {
  message("Vignette HTML is up to date")
}
```

### Verify pkgdown Build

```r
# Check required files exist
required_files <- c(
  "docs/index.html",
  "docs/articles/my-analysis.html",
  "docs/reference/index.html"
)

all(file.exists(required_files))  # Should be TRUE
```

### Monitor CI Workflow

```bash
# List recent runs
gh run list --workflow=targets-pkgdown.yml --limit 5

# Watch current run
gh run watch

# View specific run
gh run view 19867282422 --log
```

---

## Troubleshooting

### Issue 1: Vignette Not Updating

**Symptoms**:
- Made changes to `.qmd` file
- Ran `targets::tar_make()`
- HTML not updated

**Diagnosis**:
```r
targets::tar_outdated()
# Should show vignette_..._html as outdated
```

**Fix**:
```r
# Invalidate vignette target
targets::tar_invalidate(vignette_memorial_analysis_html)

# Rebuild
targets::tar_make()
```

### Issue 2: pkgdown Shows Old Vignette

**Symptoms**:
- Vignette HTML updated
- pkgdown site shows old version

**Diagnosis**:
```r
# Check if pkgdown target is outdated
targets::tar_outdated()
```

**Fix**:
```r
# Clean and rebuild
unlink("docs", recursive = TRUE)
targets::tar_invalidate(pkgdown_site)
targets::tar_make()
```

### Issue 3: CI "Nothing to Commit"

**Symptoms**:
- Workflow runs
- Says "nothing to commit, working tree clean"

**Explanation**: Expected behavior when targets cache prevents unnecessary rebuilds

**Action**: None needed - this is normal and efficient

### Issue 4: Force Complete Rebuild

**When**: After major changes or suspected cache corruption

**How**:
```r
# Delete entire cache
targets::tar_destroy()

# Rebuild everything
targets::tar_make()
```

**Warning**: Takes 5-10 minutes

---

## Real-World Examples

### Example 1: statues_named_john

**Project**: London memorials R package

**Setup**:
- Data from 3 APIs (GLHER, Wikidata, OpenStreetMap)
- Quarto vignette with interactive maps
- targets pipeline for data processing
- Nix environment for reproducibility

**Results**:
- ✅ CI time: 19+ minutes → 8 minutes
- ✅ Fully automated vignette updates
- ✅ Works perfectly in Nix locally
- ✅ Complete reproducibility maintained

**Files to Review**:
- [R/tar_plans/documentation_plan.R](https://github.com/JohnGavin/statues_named_john/blob/main/R/tar_plans/documentation_plan.R)
- [.github/workflows/targets-pkgdown.yml](https://github.com/JohnGavin/statues_named_john/blob/main/.github/workflows/targets-pkgdown.yml)
- [_targets.R](https://github.com/JohnGavin/statues_named_john/blob/main/_targets.R)

### Example 2: Multiple Vignettes

**Scenario**: Package with 3 vignettes

```r
documentation_plan <- list(
  # Vignette 1
  tar_target(
    vignette_getting_started_html,
    render_vignette("getting-started.qmd", "getting-started.html"),
    format = "file"
  ),

  # Vignette 2
  tar_target(
    vignette_advanced_html,
    render_vignette("advanced-usage.qmd", "advanced-usage.html"),
    format = "file"
  ),

  # Vignette 3
  tar_target(
    vignette_case_study_html,
    render_vignette("case-study.qmd", "case-study.html"),
    format = "file"
  ),

  # pkgdown (depends on all vignettes)
  tar_target(
    pkgdown_site,
    {
      stopifnot(file.exists(vignette_getting_started_html))
      stopifnot(file.exists(vignette_advanced_html))
      stopifnot(file.exists(vignette_case_study_html))

      pkgdown::build_site(".", preview = FALSE)
      "docs"
    },
    format = "file"
  )
)
```

### Example 3: Parallel Vignette Rendering

**Scenario**: Speed up rendering of multiple vignettes

```r
# Helper function
render_vignette <- function(input, output) {
  quarto::quarto_render(
    input = file.path("vignettes", input),
    output_file = output,
    output_dir = "inst/doc"
  )
  file.path("inst/doc", output)
}

documentation_plan <- list(
  # Parallel pattern (targets handles parallelization)
  tar_target(
    vignette_html,
    render_vignette(vignette_name, vignette_output),
    pattern = map(vignette_name, vignette_output),
    format = "file"
  ),

  tar_target(
    vignette_name,
    c("intro.qmd", "advanced.qmd", "examples.qmd")
  ),

  tar_target(
    vignette_output,
    c("intro.html", "advanced.html", "examples.html")
  )
)
```

---

## Summary

### Key Takeaways

1. ✅ **Separation of concerns**: Vignette rendering outside pkgdown
2. ✅ **Automation**: targets handles dependencies automatically
3. ✅ **Fast CI**: Pre-built vignettes enable 5-10 minute builds
4. ✅ **Reproducibility**: Complete audit trail via targets
5. ✅ **Nix compatible**: Works in Nix locally

### When to Use

- ✅ Quarto vignettes + pkgdown + Nix
- ✅ Complex/expensive vignettes
- ✅ Need reproducibility + speed

### Benefits

- ✅ Fully automated workflow
- ✅ Fast CI builds
- ✅ Reproducible outputs
- ✅ Works with Nix locally

### Trade-offs

- ⚠️ Commits HTML to git (~100-500 KB per vignette)
- ⚠️ CI makes auto-commits (use `[skip ci]`)
- ⚠️ Slightly more complex setup

---

## Related Documentation

- **[Pkgdown + Quarto + Nix Issue](Pkgdown-Quarto-Nix-Issue)** - Why the incompatibility exists
- **[Troubleshooting Guide](Troubleshooting-Complete-Guide)** - Common issues and fixes
- **[Workflow Templates](Workflow-Templates-Library)** - Copy-paste ready examples
- **[Main Repo: TARGETS_PKGDOWN_OVERVIEW.md](https://github.com/JohnGavin/claude_rix/blob/main/TARGETS_PKGDOWN_OVERVIEW.md)** - High-level overview

---

**Last Updated**: December 2, 2025
**Status**: Production-ready, recommended approach
**Questions?** Open an issue at https://github.com/JohnGavin/claude_rix/issues
