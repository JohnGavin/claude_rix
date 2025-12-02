# Targets-Based Pkgdown Solution: Overview

> **Quick Reference**: When and how to use targets for pkgdown automation
> **For Details**: See [Wiki: Complete Implementation Guide](https://github.com/JohnGavin/claude_rix/wiki/Targets-Pkgdown-Complete-Guide)

---

## The Problem in One Sentence

Quarto vignettes + bslib + pkgdown cannot work in Nix due to read-only `/nix/store`.

**→ For full explanation**: [Wiki: Pkgdown + Quarto + Nix Issue](https://github.com/JohnGavin/claude_rix/wiki/Pkgdown-Quarto-Nix-Issue)

---

## The Solution

Use targets to render vignettes OUTSIDE of pkgdown, commit HTML to git:

```
Data targets → Vignette targets → pkgdown target
              (pre-build HTML)    (uses pre-built)
```

---

## Quick Decision: Should I Use This?

### ✅ Use targets + pre-build when:

| Criteria | You Have |
|----------|----------|
| Vignettes | ✅ Quarto (`.qmd`) files |
| Documentation | ✅ Using pkgdown |
| Environment | ✅ Nix for development |
| Need | ✅ Reproducibility + fast CI |

### ❌ Don't use when:

| Criteria | You Have |
|----------|----------|
| Vignettes | ❌ Simple Rmarkdown (`.Rmd`) with no issues |
| Environment | ❌ Not using Nix |
| Package | ❌ Minimal vignettes, no complexity |
| Pipeline | ❌ No data processing (targets overhead not justified) |

---

## Benefits vs Trade-offs

### Benefits

✅ **Fully automated** - no manual vignette rendering
✅ **Fast CI builds** - 5-10 minutes (vs 20+ minutes)
✅ **Reproducible** - complete targets audit trail
✅ **Cacheable** - only rebuilds what changed
✅ **Works with Nix locally** - vignettes render outside pkgdown

### Trade-offs

⚠️ **Commits HTML to git** - ~100-500 KB per vignette
⚠️ **CI makes auto-commits** - uses `[skip ci]` to avoid loops
⚠️ **Two-step process** - vignettes rendered separately from pkgdown

---

## Architecture (Simplified)

```
┌────────────────────────────────────────────────────────┐
│ TARGETS PIPELINE                                       │
├────────────────────────────────────────────────────────┤
│                                                        │
│ 1. Data Targets                                        │
│    fetch_data() → process_data() → analyze_data()     │
│         ↓                                              │
│ 2. Vignette Target                                     │
│    Renders .qmd → inst/doc/*.html                      │
│    (using quarto::quarto_render())                     │
│         ↓                                              │
│ 3. Pkgdown Target                                      │
│    Builds docs/ using pre-built HTML                   │
│    (using pkgdown::build_site())                       │
│                                                        │
└────────────────────────────────────────────────────────┘
```

**Key Insight**: Vignette rendering happens OUTSIDE of pkgdown, so Quarto works without Nix/bslib conflicts.

---

## Quick Start

### For First-Time Setup

**→ See**: [Wiki: Complete Implementation Guide](https://github.com/JohnGavin/claude_rix/wiki/Targets-Pkgdown-Complete-Guide)

**Essential steps**:
1. Create `R/tar_plans/documentation_plan.R`
2. Update `_targets.R` to include documentation plan
3. Update `.gitignore` (commit `inst/doc/*.html`, ignore `_targets/`)
4. Create `.github/workflows/targets-pkgdown.yml`
5. Run `targets::tar_make()`

### For Daily Development

```r
# 1. Edit vignette or data code
edit("vignettes/my-analysis.qmd")

# 2. Run targets (rebuilds only what changed)
targets::tar_make()

# 3. Commit including pre-built HTML
gert::git_add(c(
  "vignettes/my-analysis.qmd",
  "inst/doc/my-analysis.html"
))
gert::git_commit("Update analysis")
```

---

## Real-World Example

**Project**: [statues_named_john](https://github.com/JohnGavin/statues_named_john)

**Setup**:
- Data from 3 APIs
- Quarto vignette with interactive maps
- Nix environment for reproducibility

**Results**:
- ✅ CI time: 19+ minutes → 8 minutes
- ✅ Fully automated vignette updates
- ✅ Works perfectly in Nix locally

**→ See implementation**: [R/tar_plans/documentation_plan.R](https://github.com/JohnGavin/statues_named_john/blob/main/R/tar_plans/documentation_plan.R)

---

## When Things Go Wrong

### Common Issues

| Symptom | Quick Fix | Details |
|---------|-----------|---------|
| Vignette not updating | `targets::tar_invalidate(vignette_..._html)` | [Wiki: Troubleshooting](https://github.com/JohnGavin/claude_rix/wiki/Targets-Pkgdown-Complete-Guide#troubleshooting) |
| pkgdown shows old version | `unlink("docs", recursive = TRUE); targets::tar_make()` | [Wiki: Troubleshooting](https://github.com/JohnGavin/claude_rix/wiki/Targets-Pkgdown-Complete-Guide#troubleshooting) |
| CI "nothing to commit" | Normal - targets cache preventing unnecessary rebuilds | [Wiki: Troubleshooting](https://github.com/JohnGavin/claude_rix/wiki/Targets-Pkgdown-Complete-Guide#troubleshooting) |

---

## Comparison with Alternatives

| Approach | CI Time | Complexity | Nix Compatible | Status |
|----------|---------|------------|----------------|---------|
| **Pure Nix** | N/A | Low | Yes | ❌ Impossible |
| **r-lib/actions (live render)** | 20+ min | Medium | No | ⚠️ Works but slow |
| **targets + pre-build** | 5-10 min | Medium | Yes (local) | ✅ **Recommended** |

---

## Related Documentation

### Main Repository
- [NIX_WORKFLOW.md](./NIX_WORKFLOW.md) - Development workflow overview
- [NIX_VS_NATIVE_R_QUICKREF.md](./NIX_VS_NATIVE_R_QUICKREF.md) - When to use Nix vs native R
- [AGENTS.md](./AGENTS.md) - Core principles and rules

### Wiki (Detailed Guides)
- **[Complete Implementation Guide](https://github.com/JohnGavin/claude_rix/wiki/Targets-Pkgdown-Complete-Guide)** - Step-by-step setup
- **[Pkgdown + Quarto + Nix Issue](https://github.com/JohnGavin/claude_rix/wiki/Pkgdown-Quarto-Nix-Issue)** - Why the incompatibility exists
- **[Troubleshooting Guide](https://github.com/JohnGavin/claude_rix/wiki/Troubleshooting-Complete-Guide)** - Common issues and fixes
- **[Real-World Examples](https://github.com/JohnGavin/claude_rix/wiki/Targets-Pkgdown-Complete-Guide#real-world-examples)** - Complete implementations

---

## Key Takeaways

1. ✅ **Separation of concerns**: Vignette rendering outside pkgdown
2. ✅ **Automation**: targets handles dependencies automatically
3. ✅ **Fast CI**: Pre-built vignettes enable 5-10 minute builds
4. ✅ **Reproducibility**: Complete audit trail via targets
5. ✅ **Nix compatible**: Works in Nix locally

---

**Created**: December 2, 2025
**Status**: Production-ready, recommended approach
**Questions?** See [Wiki: FAQs](https://github.com/JohnGavin/claude_rix/wiki/FAQs) or open an [issue](https://github.com/JohnGavin/claude_rix/issues)
