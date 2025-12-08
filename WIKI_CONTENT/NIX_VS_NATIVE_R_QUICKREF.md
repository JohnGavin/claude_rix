# Nix vs Native R: Quick Reference

> **Quick Decision Guide**: Choose the right environment for each CI/CD task
> **For Details**: See [Wiki: Complete Decision Guide](https://github.com/JohnGavin/claude_rix/wiki/Nix-vs-Native-R-Complete-Guide)

---

## Quick Decision Matrix

| Task | Environment | CI Workflow | Why |
|------|-------------|-------------|-----|
| **R CMD check** | Nix | `rix` + cachix | Exact same env as local dev |
| **Unit tests** | Nix | `rix` + cachix | Reproducibility |
| **Data pipelines** | Nix | `rix` + cachix | Reproducibility |
| **pkgdown (no Quarto)** | Nix | `rix` + cachix | Works fine |
| **pkgdown + Quarto** | Native R | r-lib/actions | Nix incompatible with bslib |
| **Vignette rendering** | targets | Both | Depends on approach |
| **Documentation** | Native R | r-lib/actions | Flexibility |

---

## The Fundamental Incompatibility

### ❌ Nix + pkgdown + Quarto + bslib = IMPOSSIBLE

```
Quarto vignettes → require Bootstrap 5 → require bslib →
requires file copying from /nix/store → BLOCKED (read-only) → FAILS
```

**This is not a bug** - it's a fundamental design conflict.

**→ For full explanation**: [Wiki: Pkgdown + Quarto + Nix Issue](https://github.com/JohnGavin/claude_rix/wiki/Pkgdown-Quarto-Nix-Issue)

---

## Common Scenarios

### Scenario 1: R Package with Quarto Vignettes

**Challenge**: pkgdown + Quarto + bslib incompatible with Nix

**Solution**: Hybrid approach

```yaml
# R-CMD-check.yml - Use Nix (reproducibility)
- uses: cachix/install-nix-action@v20
- run: nix-shell --run "Rscript -e 'devtools::check()'"

# targets-pkgdown.yml - Use Native R (compatibility)
- uses: r-lib/actions/setup-r@v2
- run: Rscript -e 'targets::tar_make()'  # Renders vignettes + builds site
```

**Why this works**:
- R CMD check uses Nix (same as local dev)
- pkgdown uses native R (avoids bslib issue)
- targets renders vignettes (works in either env)

**→ See**: [TARGETS_PKGDOWN_SOLUTION.md](./TARGETS_PKGDOWN_SOLUTION.md)

### Scenario 2: Data Processing Pipeline

**Challenge**: Need reproducible data processing

**Solution**: Pure Nix

```yaml
name: Data Pipeline
jobs:
  pipeline:
    steps:
      - uses: cachix/install-nix-action@v20
      - uses: cachix/cachix-action@v12
        with:
          name: johngavin
      - run: nix-shell --run "Rscript -e 'targets::tar_make()'"
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
    steps:
      - uses: r-lib/actions/setup-r@v2
      - uses: r-lib/actions/setup-r-dependencies@v2
      - run: Rscript -e 'devtools::check()'
```

**Why this works**:
- Simple, fast, standard workflow
- No Nix overhead
- Works for 90% of R packages

---

## Decision Criteria

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

---

## Understanding the Options

### Option 1: Nix Environment

**Advantages**:
- ✅ **Perfect reproducibility**: Identical env everywhere
- ✅ **Version pinning**: Exact package versions guaranteed
- ✅ **Cacheable**: Use cachix for fast CI

**Limitations**:
- ❌ **Read-only**: Can't modify installed packages
- ❌ **bslib incompatibility**: Can't copy files at runtime
- ❌ **Setup time**: Initial cache miss is slow

**When to Use**:
- Package development
- R CMD check
- Unit testing
- Data processing pipelines

### Option 2: Native R (r-lib/actions)

**Advantages**:
- ✅ **Fast setup**: RSPM binaries install quickly
- ✅ **Writable**: Packages can modify themselves
- ✅ **Compatible**: Works with all R packages

**Limitations**:
- ⚠️ **Less reproducible**: Package versions may drift
- ⚠️ **Platform differences**: Local (Nix) ≠ CI (native R)

**When to Use**:
- pkgdown with Quarto vignettes
- Tasks requiring runtime file modifications
- Quick prototypes

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

### 3. Document Your Choice

**Rule**: Explain why you chose Nix vs native R

✅ **Good**:
```yaml
# Use Nix for R CMD check to match local development environment
# Use native R for pkgdown due to bslib incompatibility with Nix
```

---

## Workflow Templates

### Template 1: Pure Nix Project

**When**: Maximum reproducibility, no Quarto vignettes

```yaml
# R-CMD-check-nix.yml
- uses: cachix/install-nix-action@v20
- uses: cachix/cachix-action@v12
  with:
    name: johngavin
- run: nix-build package.nix
- run: nix-store -qR --include-outputs result | cachix push johngavin
- run: nix-shell --run "Rscript -e 'rcmdcheck::rcmdcheck()'"
```

**→ See**: [Wiki: Workflow Templates Library](https://github.com/JohnGavin/claude_rix/wiki/Workflow-Templates-Library)

### Template 2: Hybrid Nix + Native R

**When**: Nix locally, Quarto vignettes, need fast CI

```yaml
# R-CMD-check-nix.yml
- uses: cachix/install-nix-action@v20
- run: nix-shell --run "Rscript -e 'devtools::check()'"

# targets-pkgdown.yml
- uses: r-lib/actions/setup-r@v2
- run: Rscript -e 'targets::tar_make()'
```

**→ See**: [TARGETS_PKGDOWN_SOLUTION.md](./TARGETS_PKGDOWN_SOLUTION.md)

### Template 3: Pure r-lib/actions

**When**: No Nix, standard R package

```yaml
# R-CMD-check.yml
- uses: r-lib/actions/setup-r@v2
- uses: r-lib/actions/setup-r-dependencies@v2
- uses: r-lib/actions/check-r-package@v2
```

**→ See**: [Wiki: Workflow Templates Library](https://github.com/JohnGavin/claude_rix/wiki/Workflow-Templates-Library)

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

### Main Repository
- [NIX_WORKFLOW.md](./NIX_WORKFLOW.md) - General Nix workflow guide
- [TARGETS_PKGDOWN_OVERVIEW.md](./TARGETS_PKGDOWN_OVERVIEW.md) - Detailed solution for Quarto vignettes
- [AGENTS.md](./AGENTS.md) - Core principles and rules

### Wiki (Complete Guides)
- **[Nix vs Native R: Complete Guide](https://github.com/JohnGavin/claude_rix/wiki/Nix-vs-Native-R-Complete-Guide)** - Detailed decision criteria
- **[Workflow Templates Library](https://github.com/JohnGavin/claude_rix/wiki/Workflow-Templates-Library)** - Copy-paste ready templates
- **[When to Use Hybrid Workflows](https://github.com/JohnGavin/claude_rix/wiki/When-to-Use-Hybrid-Workflows)** - Best of both worlds
- **[FAQs](https://github.com/JohnGavin/claude_rix/wiki/FAQs)** - Common questions answered

---

**Created**: December 2, 2025
**Purpose**: Quick decision guide for R package CI/CD workflows
**Questions?** See [Wiki: FAQs](https://github.com/JohnGavin/claude_rix/wiki/FAQs) or open an [issue](https://github.com/JohnGavin/claude_rix/issues)
