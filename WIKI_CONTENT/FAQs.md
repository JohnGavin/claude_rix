# Frequently Asked Questions (FAQs)

> **Purpose**: Quick answers to common questions about Nix + R package development
> **Last Updated**: December 2, 2025

**→ Back to**: [Wiki Home](Home)

---

## Quick Links by Topic

- [Getting Started](#getting-started)
- [Nix Environment](#nix-environment)
- [GitHub Actions & CI/CD](#github-actions--cicd)
- [Pkgdown & Documentation](#pkgdown--documentation)
- [Targets Pipelines](#targets-pipelines)
- [Troubleshooting](#troubleshooting)
- [Workflow & Best Practices](#workflow--best-practices)

---

## Getting Started

### Q: Should I use Nix for my R package?

**A**: Use Nix when you need:
- ✅ Reproducible development environment across machines
- ✅ Exact same package versions locally and in CI
- ✅ Complex system dependencies
- ✅ Multiple projects with different R versions

**Don't use Nix if:**
- ❌ Simple package with minimal dependencies
- ❌ Only developing locally (no CI/CD)
- ❌ Don't want to learn Nix

**→ See**: [Nix vs Native R: Complete Guide](Nix-vs-Native-R-Complete-Guide)

### Q: How do I start a new R package with Nix?

**A**: Follow these steps:

```r
# 1. Create package structure
usethis::create_package("mypackage")

# 2. Generate Nix files
rix::rix(
  r_ver = "4.4.1",
  r_pkgs = c("devtools", "usethis", "gert", "gh"),
  system_pkgs = NULL,
  ide = "other",
  project_path = ".",
  overwrite = TRUE
)

# 3. Enter Nix shell
nix-shell default.nix

# 4. Start developing
devtools::load_all()
```

**→ See**: [First-Time Project Setup](First-Time-Project-Setup)

### Q: What's the difference between default.nix and package.nix?

**A**:
- **`default.nix`**: Development environment (all tools: R, git, gh, devtools)
- **`package.nix`**: Package derivation (runtime dependencies only)

**Use cases**:
- Local development: `nix-shell default.nix`
- Building package: `nix-build package.nix`
- CI/CD: Both (default.nix for development, package.nix for cachix)

**→ See**: [Complete Nix Setup Guide](Complete-Nix-Setup-Guide)

---

## Nix Environment

### Q: Why do I get "command not found" errors?

**A**: Most common reasons:

1. **Not in nix shell**
   ```bash
   # Check:
   echo $IN_NIX_SHELL
   # Should output: 1 or impure

   # Fix:
   nix-shell default.nix
   ```

2. **Environment degradation** (long session)
   ```bash
   # Fix:
   exit
   nix-shell default.nix
   ```

3. **Garbage collection deleted paths**
   ```bash
   # Fix: Restart shell
   exit; nix-shell default.nix
   ```

**→ See**: [Troubleshooting: Environment Degradation](Troubleshooting-Environment-Degradation)

### Q: How often should I restart my nix shell?

**A**:
- ⏱️ **Every 2-3 hours** during long sessions (prevents degradation)
- 🔄 **After package updates** (new default.nix)
- ⚠️ **Immediately if commands fail**

**→ See**: [Long Session Management](Complete-Nix-Setup-Guide#long-session-management)

### Q: Can I use install.packages() in Nix?

**A**: ❌ **No** - Nix store is read-only.

**Instead**:
1. Add package to `default.nix` via `rix::rix()`
2. Restart nix shell
3. Package is available

**Example**:
```r
# ❌ Don't do this:
install.packages("dplyr")

# ✅ Do this:
rix::rix(
  r_ver = "4.4.1",
  r_pkgs = c("dplyr", "tidyr", "ggplot2"),
  project_path = "."
)

# Then restart shell
exit; nix-shell default.nix
```

**→ See**: [Package Management](Complete-Nix-Setup-Guide#package-management)

### Q: What's the difference between nix-shell and nix-build?

**A**:
- **`nix-shell`**: Enter development environment (interactive)
- **`nix-build`**: Build package as derivation (produces result/ symlink)

**When to use**:
- `nix-shell default.nix` - Daily development
- `nix-build package.nix` - Before pushing to cachix
- `nix-build` in CI - Build and cache package

---

## GitHub Actions & CI/CD

### Q: Should I use Nix or r-lib/actions in GitHub Actions?

**A**: Depends on the task:

| Task | Environment | Why |
|------|-------------|-----|
| R CMD check | **Nix** | Must match local environment |
| Unit tests | **Nix** | Reproducibility |
| Data pipelines | **Nix** | Reproducibility |
| pkgdown (no Quarto) | **Nix** | Works fine |
| pkgdown + Quarto | **r-lib/actions** | Nix incompatible with bslib |

**→ See**: [NIX_VS_NATIVE_R_QUICKREF.md](https://github.com/JohnGavin/claude_rix/blob/main/NIX_VS_NATIVE_R_QUICKREF.md)

### Q: Why are my GitHub Actions builds slow?

**A**: Common causes:

1. **Not using cachix** (rebuilding everything)
   ```yaml
   # Add to workflow:
   - uses: cachix/cachix-action@v12
     with:
       name: johngavin
       authToken: ${{ secrets.CACHIX_AUTH_TOKEN }}
   ```

2. **Building from source instead of binaries**
   - Use r-lib/actions with `use-public-rspm: true`
   - Or use Nix with cachix

3. **Not pushing to cachix before git push**
   ```bash
   # ALWAYS do this before git push:
   nix-build package.nix
   nix-store -qR --include-outputs result | cachix push johngavin
   ```

**→ See**: [GitHub Actions Configuration](GitHub-Actions-Configuration)

### Q: What is cachix and why do I need it?

**A**: **cachix** is a binary cache for Nix packages.

**Without cachix** (slow):
```
GitHub Actions → Builds ALL packages from source → 15-30 minutes
```

**With cachix** (fast):
```
Local → Build once → Push to cachix
                    ↓
GitHub Actions → Pull from cachix → 1-2 minutes
```

**Setup**:
1. Create account at https://app.cachix.org/
2. Create cache (e.g., "johngavin")
3. Add `CACHIX_AUTH_TOKEN` secret to GitHub
4. Use in workflows

**→ See**: [Complete Nix Setup Guide](Complete-Nix-Setup-Guide#cachix-setup)

### Q: Why do I need to push to cachix BEFORE git push?

**A**: To ensure GitHub Actions can use your pre-built packages:

```
Correct order:
1. Build locally: nix-build package.nix
2. Push to cachix: nix-store ... | cachix push johngavin
3. Git push: git push

Why this matters:
- GitHub Actions runs AFTER git push
- Pulls from cachix
- If package not in cachix, rebuilds from source (slow!)
```

**→ See**: [NIX_WORKFLOW.md](https://github.com/JohnGavin/claude_rix/blob/main/NIX_WORKFLOW.md)

---

## Pkgdown & Documentation

### Q: Why can't I build pkgdown locally with Quarto vignettes?

**A**: **Fundamental incompatibility** between Nix + pkgdown + Quarto + bslib:

**The Chain**:
```
Quarto vignettes → require Bootstrap 5 → require bslib →
requires file copying from /nix/store → BLOCKED (read-only) → FAILS
```

**This is not a bug** - it's architectural.

**Solutions**:
1. ✅ Use targets to pre-build vignettes (recommended)
2. ✅ Use r-lib/actions in CI for pkgdown
3. ✅ Build reference docs only locally (no vignettes)

**→ See**: [Pkgdown + Quarto + Nix Issue](Pkgdown-Quarto-Nix-Issue)

### Q: What is the targets-based pkgdown solution?

**A**: Render vignettes OUTSIDE of pkgdown, commit HTML to git:

```
targets pipeline:
Data → Vignette (render to HTML) → pkgdown (uses pre-built HTML)
```

**Benefits**:
- ✅ Works with Nix locally
- ✅ Fast CI builds (5-10 min vs 20+ min)
- ✅ Fully automated
- ✅ Reproducible

**→ See**: [Targets-Based Pkgdown Solution](Targets-Pkgdown-Complete-Guide)

### Q: Should I commit HTML vignettes to git?

**A**: **Yes**, when using the targets-based approach.

**Why**:
- Pre-built HTML enables fast CI builds
- pkgdown uses pre-built files (no rendering needed)
- Standard practice for complex vignettes

**How**:
```bash
# Add to .gitignore:
/_targets/           # Ignore cache
# inst/doc/*.html    # DON'T ignore! (explicitly commented out)
```

**Size**: ~100-500 KB per vignette (compressed in git)

---

## Targets Pipelines

### Q: When should I use targets?

**A**: Use targets when you have:
- ✅ Data processing pipelines
- ✅ Multiple analysis steps with dependencies
- ✅ Expensive computations (don't want to re-run everything)
- ✅ Vignettes that depend on data outputs
- ✅ Need reproducibility and caching

**Don't use targets if**:
- ❌ Simple analysis script (one file, linear flow)
- ❌ Interactive exploration only
- ❌ No reusable components

**→ See**: [Targets Pipeline Workflows](Targets-Pipeline-Workflows)

### Q: How do I add targets to an existing package?

**A**:

```r
# 1. Install targets
install.packages("targets")

# 2. Create _targets.R in package root
targets::use_targets()

# 3. Create plan files
dir.create("R/tar_plans", recursive = TRUE)

# 4. Define targets
# Edit R/tar_plans/analysis_plan.R

# 5. Run pipeline
targets::tar_make()
```

**→ See**: [Targets-Based Pkgdown Solution](Targets-Pkgdown-Complete-Guide)

### Q: What gets cached by targets?

**A**: Everything in `_targets/objects/`:
- Data frames, tibbles
- Model objects
- Plots (as serialized objects)
- Any R object returned by a target

**What's NOT cached**:
- Files (unless `format = "file"`)
- Console output
- Plots rendered to screen

**→ See**: [Targets Pipeline Workflows](Targets-Pipeline-Workflows)

---

## Troubleshooting

### Q: My R package won't load - "package not available"

**A**: Check if package is in `default.nix`:

```r
# 1. Check what's available
Rscript -e ".libPaths()"

# 2. Try to load
Rscript -e "library(dplyr)"

# If fails:
# - Add to default.nix via rix::rix()
# - Restart nix shell
```

**→ See**: [Troubleshooting: Package Installation](Troubleshooting-Package-Installation)

### Q: nix-shell takes forever to start

**A**: Common causes:

1. **First time setup** (downloads everything)
   - Expected: 10-30 minutes
   - Solution: Wait, then use cachix for future

2. **Cache miss**
   - Fix: Use cachix

3. **Too many packages**
   - Fix: Only include what you need in default.nix

**→ See**: [Troubleshooting: Performance](Troubleshooting-Performance)

### Q: How do I force targets to rebuild everything?

**A**:

```r
# Nuclear option - delete entire cache
targets::tar_destroy()

# Then rebuild
targets::tar_make()
```

**Less aggressive options**:
```r
# Invalidate specific target
targets::tar_invalidate(target_name)

# Rebuild specific targets
targets::tar_make(names = c("target1", "target2"))
```

**→ See**: [Targets-Pkgdown Troubleshooting](Targets-Pkgdown-Complete-Guide#troubleshooting)

---

## Workflow & Best Practices

### Q: What's the 9-step workflow?

**A**:

```
1. Create GitHub issue
2. Create dev branch (usethis::pr_init())
3. Make changes locally
4. Run all checks (devtools::check())
5. ⚠️ Push to cachix (nix-store ... | cachix push)
6. Push to GitHub (usethis::pr_push())
7. Wait for GitHub Actions
8. Merge PR (usethis::pr_merge_main())
9. Log everything (R/setup/*.R)
```

**→ See**: [Complete Development Workflow](Complete-Development-Workflow)

### Q: Should I use bash git commands or R packages?

**A**: **ALWAYS use R packages** (gert, gh, usethis):

```r
# ✅ CORRECT (R packages)
usethis::pr_init("fix-bug")
gert::git_add(".")
gert::git_commit("Fix bug")
usethis::pr_push()

# ❌ WRONG (bash commands)
git checkout -b fix-bug
git add .
git commit -m "Fix bug"
git push
gh pr create
```

**Why**:
- Reproducible (can log commands in .R files)
- Integrated with devtools workflow
- Works in Nix environment

**→ See**: [AGENTS.md](https://github.com/JohnGavin/claude_rix/blob/main/AGENTS.md)

### Q: Where should I log my development commands?

**A**: Use `R/setup/` directory:

```r
# R/setup/fix_issue_123.R

# Date: 2025-12-02
# Issue: #123 - Fix data loading bug

# 1. Create branch
usethis::pr_init("fix-issue-123")

# 2. Edit code
# ... (description of changes)

# 3. Test
devtools::test()

# 4. Push
usethis::pr_push()
```

**Why**:
- Reproducibility
- Future reference
- Audit trail

**→ See**: [Complete Development Workflow](Complete-Development-Workflow)

### Q: When should I create a hybrid workflow (Nix + native R)?

**A**: Use hybrid when:
- ✅ pkgdown with Quarto vignettes (Nix incompatible)
- ✅ Some tasks need runtime file modifications
- ✅ Balance reproducibility (R CMD check) with compatibility (docs)

**Example**:
```yaml
# R-CMD-check.yml - Use Nix
- uses: cachix/install-nix-action@v20
- run: nix-shell --run "devtools::check()"

# targets-pkgdown.yml - Use r-lib/actions
- uses: r-lib/actions/setup-r@v2
- run: Rscript -e 'targets::tar_make()'
```

**→ See**: [When to Use Hybrid Workflows](When-to-Use-Hybrid-Workflows)

---

## Still Have Questions?

1. **Search this wiki**: Use wiki search
2. **Check main repo docs**: [claude_rix repository](https://github.com/JohnGavin/claude_rix)
3. **Read related guides**:
   - [Complete Nix Setup Guide](Complete-Nix-Setup-Guide)
   - [Complete Development Workflow](Complete-Development-Workflow)
   - [Troubleshooting Guide](Troubleshooting-Complete-Guide)
4. **Open an issue**: https://github.com/JohnGavin/claude_rix/issues

---

**Last Updated**: December 2, 2025
**Questions Added**: 35
**Status**: Actively maintained
