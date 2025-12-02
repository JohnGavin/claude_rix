# Nix vs Native R: Workflow Decision Guide

> **Purpose**: Clear guidelines for choosing between Nix and native R (r-lib/actions) in GitHub Actions workflows
> **Audience**: Developers creating R packages with Nix + CI/CD
> **Last Updated**: December 2, 2025

---

## Table of Contents

1. [Quick Decision Matrix](#quick-decision-matrix)
2. [Understanding the Options](#understanding-the-options)
3. [Detailed Decision Criteria](#detailed-decision-criteria)
4. [Common Scenarios](#common-scenarios)
5. [Workflow Examples](#workflow-examples)
6. [Best Practices](#best-practices)

---

## Quick Decision Matrix

| Task | Environment | CI Workflow | Why |
|------|-------------|-------------|-----|
| **R CMD check** | Nix | `rix` + cachix | Exact same env as local dev |
| **Unit tests** | Nix | `rix` + cachix | Reproducibility |
| **Data pipelines** | Nix | `rix` + cachix | Reproducibility |
| **pkgdown (no Quarto)** | Nix | `rix` + cachix | Works fine |
| **pkgdown + Quarto** | Native R | r-lib/actions | Nix incompatible with bslib |
| **Vignette rendering** | targets | Both (see below) | Depends on approach |
| **Documentation** | Native R | r-lib/actions | Flexibility |

---

## Understanding the Options

### Option 1: Nix Environment

**What it is**:
- Reproducible, declarative package management
- All packages from `/nix/store` (read-only)
- Exact same environment local + CI

**Advantages**:
- ✅ **Perfect reproducibility**: Identical env everywhere
- ✅ **Version pinning**: Exact package versions guaranteed
- ✅ **System deps**: All dependencies declared
- ✅ **Cacheable**: Use cachix for fast CI

**Limitations**:
- ❌ **Read-only**: Can't modify installed packages
- ❌ **bslib incompatibility**: Can't copy files at runtime
- ❌ **Setup time**: Initial cache miss is slow
- ❌ **Complexity**: Steeper learning curve

**When to Use**:
- Package development
- R CMD check
- Unit testing
- Data processing pipelines
- Any task needing exact reproducibility

### Option 2: Native R (r-lib/actions)

**What it is**:
- Standard R installation on GitHub runners
- Packages from CRAN/RSPM (binaries when available)
- Installed to writable `R_LIBS_USER`

**Advantages**:
- ✅ **Fast setup**: RSPM binaries install quickly
- ✅ **Writable**: Packages can modify themselves
- ✅ **Simple**: Standard R workflow
- ✅ **Compatible**: Works with all R packages

**Limitations**:
- ⚠️ **Less reproducible**: Package versions may drift
- ⚠️ **Platform differences**: Local (Nix) ≠ CI (native R)
- ⚠️ **System deps**: Manual apt-get required

**When to Use**:
- pkgdown with Quarto vignettes
- Tasks requiring runtime file modifications
- Quick prototypes
- Non-critical documentation builds

---

## Detailed Decision Criteria

### Criterion 1: Reproducibility Requirements

**High reproducibility needed** → **Use Nix**
- R CMD check
- Unit tests
- Data processing
- Scientific computing
- Publication-quality results

**Medium reproducibility acceptable** → **Use Native R**
- Documentation websites
- Preview builds
- Development iterations

### Criterion 2: Runtime File Modifications

**Package needs to modify itself at runtime** → **Use Native R**
- bslib (copies JS/CSS files)
- pkgdown with Quarto + bslib
- Packages with post-install scripts

**No runtime modifications** → **Use Nix**
- Standard R packages
- Pure computation
- Read-only operations

### Criterion 3: Local Development Environment

**Local uses Nix** → **Prefer Nix in CI**
- Maintains consistency
- Same bugs/features locally and CI
- Easier debugging

**Local uses standard R** → **Use Native R in CI**
- No advantage to Nix
- Simpler workflow

### Criterion 4: CI Performance

**Speed critical** → **Depends**:
- Nix with cachix: Very fast (seconds) after first run
- Native R with RSPM: Fast (1-2 minutes)
- Nix without cache: Slow (15-30 minutes)
- Native R building from source: Slow (15-30 minutes)

**Best approach**:
- Nix + cachix for reproducibility-critical tasks
- Native R + RSPM for documentation tasks

---

## Common Scenarios

### Scenario 1: R Package with Quarto Vignettes

**Challenge**: pkgdown + Quarto + bslib incompatible with Nix

**Solution**: Hybrid approach

```yaml
# R-CMD-check.yml - Use Nix
name: R-CMD-check
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: cachix/install-nix-action@v20
      - run: nix-shell default.nix --run "Rscript -e 'devtools::check()'"

# targets-pkgdown.yml - Use Native R
name: targets + pkgdown
jobs:
  pkgdown:
    runs-on: ubuntu-latest
    steps:
      - uses: r-lib/actions/setup-r@v2
      - uses: r-lib/actions/setup-r-dependencies@v2
      - run: Rscript -e 'targets::tar_make()'  # Renders vignettes + builds site
```

**Why this works**:
- R CMD check uses Nix (same as local dev)
- pkgdown uses native R (avoids bslib issue)
- targets renders vignettes (works in either env)

**See**: [`TARGETS_PKGDOWN_SOLUTION.md`](./TARGETS_PKGDOWN_SOLUTION.md)

### Scenario 2: Data Processing Pipeline

**Challenge**: Need reproducible data processing

**Solution**: Pure Nix

```yaml
name: Data Pipeline
jobs:
  pipeline:
    runs-on: ubuntu-latest
    steps:
      - uses: cachix/install-nix-action@v20
      - uses: cachix/cachix-action@v12
        with:
          name: johngavin
          authToken: ${{ secrets.CACHIX_AUTH_TOKEN }}
      - run: |
          nix-shell default.nix --run "
            Rscript -e 'targets::tar_make()'
          "
      - run: nix-store -qR --include-outputs result | cachix push johngavin
```

**Why this works**:
- Complete reproducibility via Nix
- Fast CI via cachix
- Same environment locally and in CI

### Scenario 3: Simple Package (No Quarto, No Nix)

**Challenge**: Simple package, no special requirements

**Solution**: Pure r-lib/actions

```yaml
name: R-CMD-check
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: r-lib/actions/setup-r@v2
      - uses: r-lib/actions/setup-r-dependencies@v2
      - run: Rscript -e 'devtools::check()'

name: pkgdown
jobs:
  pkgdown:
    runs-on: ubuntu-latest
    steps:
      - uses: r-lib/actions/setup-r@v2
      - uses: r-lib/actions/setup-r-dependencies@v2
        with:
          extra-packages: any::pkgdown
          needs: website
      - run: Rscript -e 'pkgdown::build_site_github_pages()'
```

**Why this works**:
- Simple, fast, standard workflow
- No Nix overhead
- Works for 90% of R packages

### Scenario 4: Local Nix, CI Documentation

**Challenge**: Develop in Nix but need fast documentation updates

**Solution**: Hybrid - Nix for checks, native R for docs

```yaml
# R-CMD-check.yml - Nix (reproducibility)
- uses: cachix/install-nix-action@v20
- run: nix-shell --run "Rscript -e 'devtools::check()'"

# pkgdown.yml - Native R (speed)
- uses: r-lib/actions/setup-r@v2
- run: Rscript -e 'pkgdown::build_site()'
```

**Trade-off**:
- R CMD check exactly matches local (Nix)
- pkgdown may differ slightly (native R)
- Acceptable for documentation

---

## Workflow Examples

### Template 1: Pure Nix Project

**When**: Maximum reproducibility, no Quarto vignettes

**Files**:

`.github/workflows/R-CMD-check-nix.yml`:
```yaml
name: R-CMD-check (Nix)
on: [push, pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: cachix/install-nix-action@v20
      - uses: cachix/cachix-action@v12
        with:
          name: johngavin
          authToken: ${{ secrets.CACHIX_AUTH_TOKEN }}
      - name: Build and cache
        run: |
          nix-build package.nix
          nix-store -qR --include-outputs result | cachix push johngavin
      - name: R CMD check
        run: nix-shell default-ci.nix --run "Rscript -e 'rcmdcheck::rcmdcheck()'"
```

`.github/workflows/pkgdown-nix.yml`:
```yaml
name: pkgdown (Nix)
on:
  push:
    branches: [main, master]
jobs:
  pkgdown:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: cachix/install-nix-action@v20
      - uses: cachix/cachix-action@v12
        with:
          name: johngavin
      - name: Build site
        run: nix-shell default-ci.nix --run "Rscript -e 'pkgdown::build_site()'"
      - name: Deploy
        uses: JamesIves/github-pages-deploy-action@v4
        with:
          folder: docs
```

### Template 2: Hybrid Nix + Native R

**When**: Nix locally, Quarto vignettes, need fast CI

**Files**:

`.github/workflows/R-CMD-check-nix.yml`:
```yaml
name: R-CMD-check (Nix)
# Same as Template 1
```

`.github/workflows/targets-pkgdown.yml`:
```yaml
name: targets + pkgdown (Native R)
on:
  push:
    branches: [main, master]
jobs:
  targets-pkgdown:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: quarto-dev/quarto-actions/setup@v2
      - uses: r-lib/actions/setup-r@v2
        with:
          use-public-rspm: true
      - uses: r-lib/actions/setup-r-dependencies@v2
        with:
          extra-packages: any::targets, any::pkgdown, local::.
          needs: website
      - name: Run pipeline
        run: Rscript -e 'targets::tar_make()'
      - name: Commit outputs
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add inst/doc/*.html docs/
          git commit -m "AUTO: Update docs [skip ci]" || true
          git push || true
      - name: Deploy
        uses: JamesIves/github-pages-deploy-action@v4
        with:
          folder: docs
```

### Template 3: Pure r-lib/actions

**When**: No Nix, standard R package

**Files**:

`.github/workflows/R-CMD-check.yml`:
```yaml
name: R-CMD-check
on: [push, pull_request]
jobs:
  R-CMD-check:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
    steps:
      - uses: actions/checkout@v4
      - uses: r-lib/actions/setup-r@v2
      - uses: r-lib/actions/setup-r-dependencies@v2
      - uses: r-lib/actions/check-r-package@v2
```

`.github/workflows/pkgdown.yml`:
```yaml
name: pkgdown
on:
  push:
    branches: [main, master]
jobs:
  pkgdown:
    runs-on: ubuntu-latest
    env:
      GITHUB_PAT: ${{ secrets.GITHUB_TOKEN }}
    steps:
      - uses: actions/checkout@v4
      - uses: r-lib/actions/setup-r@v2
      - uses: r-lib/actions/setup-r-dependencies@v2
        with:
          extra-packages: any::pkgdown, local::.
          needs: website
      - run: Rscript -e 'pkgdown::build_site_github_pages()'
      - uses: JamesIves/github-pages-deploy-action@v4
        with:
          folder: docs
```

---

## Best Practices

### 1. Match Local and CI for Critical Tasks

**Rule**: R CMD check MUST use same environment as local development

✅ **Good**:
```
Local: Nix shell with default.nix
CI: Nix shell with same default.nix
```

❌ **Bad**:
```
Local: Nix shell
CI: r-lib/actions (different environment!)
```

### 2. Use Native R for Non-Critical Tasks

**Rule**: Documentation doesn't need perfect reproducibility

✅ **Acceptable**:
```
R CMD check: Nix (reproducible)
pkgdown: Native R (fast, flexible)
```

### 3. Leverage Caching Aggressively

**Rule**: Cache everything possible

✅ **Nix projects**:
```yaml
- uses: cachix/cachix-action@v12
  with:
    name: johngavin
    authToken: ${{ secrets.CACHIX_AUTH_TOKEN }}
```

✅ **Native R projects**:
```yaml
- uses: r-lib/actions/setup-r-dependencies@v2
  # Automatically caches R packages
```

### 4. Document Your Choice

**Rule**: Explain why you chose Nix vs native R

✅ **Good**:
```yaml
# Use Nix for R CMD check to match local development environment
# Use native R for pkgdown due to bslib incompatibility with Nix
```

### 5. Test Locally Before CI

**Rule**: Run same commands locally that CI will run

✅ **Nix workflow**:
```bash
# Local test
nix-shell default-ci.nix --run "Rscript -e 'devtools::check()'"

# CI will run same command
```

✅ **Native R workflow**:
```bash
# Local test (in non-Nix environment)
Rscript -e 'devtools::check()'

# CI will run same command
```

### 6. Minimize Environment Differences

**Rule**: Keep local and CI as similar as possible

✅ **Strategies**:
- Use Nix locally AND in CI when possible
- Document any differences clearly
- Test both environments regularly

### 7. Use Hybrid Thoughtfully

**Rule**: Hybrid workflows are acceptable but document reasons

✅ **Good hybrid**:
```
R CMD check: Nix (reproducibility critical)
pkgdown: Native R (documented incompatibility)
Reason: bslib + Nix incompatibility
```

❌ **Bad hybrid**:
```
R CMD check: Native R
pkgdown: Nix
Reason: No reason documented
```

---

## Decision Flowchart

```
Start: Need to choose workflow
    ↓
[Q1] Using Nix for local development?
    ├─ No → Use r-lib/actions (Template 3)
    └─ Yes → Continue
        ↓
[Q2] Does task require runtime file modifications?
    ├─ Yes (e.g., pkgdown + Quarto + bslib)
    │   └─ Use Native R (Template 2, hybrid)
    └─ No → Continue
        ↓
[Q3] Is reproducibility critical?
    ├─ Yes (R CMD check, tests, data)
    │   └─ Use Nix (Template 1 or 2)
    └─ No (documentation, previews)
        └─ Use Native R or Nix (either works)
            ↓
[Q4] Need fast CI?
    ├─ Yes
    │   ├─ Have cachix? → Use Nix + cachix
    │   └─ No cachix? → Use Native R + RSPM
    └─ No → Use Nix (best reproducibility)
```

---

## Summary

**Golden Rules**:

1. **R CMD check = Local environment** (Nix if local uses Nix)
2. **Documentation = Flexible** (Native R acceptable)
3. **Data pipelines = Nix** (reproducibility critical)
4. **bslib + Nix = Incompatible** (use native R)
5. **Hybrid = Okay if documented**

**Default Recommendations**:

- **New project, no Nix**: Use r-lib/actions for everything
- **Existing Nix project**: Use Nix for checks, consider hybrid for docs
- **Quarto vignettes**: Use targets + native R workflow

---

## Related Documentation

- [`TARGETS_PKGDOWN_SOLUTION.md`](./TARGETS_PKGDOWN_SOLUTION.md) - Detailed solution for Quarto vignettes
- [`NIX_TROUBLESHOOTING.md`](./NIX_TROUBLESHOOTING.md) - Nix-specific issues
- [`NIX_WORKFLOW.md`](./NIX_WORKFLOW.md) - General Nix workflow guide
- [`AGENTS.md`](./AGENTS.md) - Agent instructions and guidelines

---

**Created**: December 2, 2025
**Purpose**: Decision guide for R package CI/CD workflows
**Maintained by**: R + Nix development workflow team
