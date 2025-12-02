# Nix Environment: Quick Reference

> **Quick Fixes**: Top 5 issues and immediate solutions
> **For Details**: See [Wiki: Complete Troubleshooting Guide](https://github.com/JohnGavin/claude_rix/wiki/Troubleshooting-Complete-Guide)

---

## Quick Diagnosis

Run this to identify your issue:

```bash
# Check if in nix shell
echo $IN_NIX_SHELL  # Should output: 1 or impure

# Check for broken paths
which git gh R  # Should output: /nix/store/.../bin/...

# Test R packages
Rscript -e "library(devtools); library(usethis); library(gert)"
```

---

## Top 5 Issues & Quick Fixes

### 1. "command not found" Errors

**Symptoms**:
```bash
$ gh run list
bash: gh: command not found

$ R
bash: R: command not found
```

**Quick Fix**:
```bash
# Exit and re-enter shell (takes seconds)
exit
nix-shell default.nix
```

**Why this happens**: Environment degradation during long sessions

**→ Details**: [Wiki: Environment Degradation](https://github.com/JohnGavin/claude_rix/wiki/Troubleshooting-Environment-Degradation)

---

### 2. R Package Won't Load

**Symptoms**:
```r
library(dplyr)
# Error in library(dplyr): there is no package called 'dplyr'
```

**Quick Fix**:
```r
# 1. Check if package is in default.nix
# Edit default.R to add package:
rix::rix(
  r_ver = "4.4.1",
  r_pkgs = c("dplyr", "tidyr", "ggplot2"),  # Add here
  project_path = "."
)

# 2. Restart nix shell
exit
nix-shell default.nix
```

**Why this happens**: Package not included in Nix environment

**→ Details**: [Wiki: Package Installation](https://github.com/JohnGavin/claude_rix/wiki/Troubleshooting-Package-Installation)

---

### 3. `/nix/store/xxx: No such file or directory`

**Symptoms**:
```bash
$ git status
/nix/store/abc123-git-2.42.0/bin/git: No such file or directory
```

**Quick Fix**:
```bash
# Restart shell immediately
exit
nix-shell default.nix
```

**Why this happens**: Garbage collection deleted paths during active session

**→ Details**: [Wiki: Garbage Collection Issues](https://github.com/JohnGavin/claude_rix/wiki/Troubleshooting-Complete-Guide#garbage-collection-issues)

---

### 4. pkgdown Fails with Quarto Vignettes

**Symptoms**:
```r
pkgdown::build_site()
# Error: [EACCES] Failed to copy
#   '/nix/store/.../bslib/lib/bs5/dist/js/bootstrap.bundle.min.js'
#   Permission denied
```

**Quick Fix**: Use targets-based solution (cannot fix in Nix)

```r
# This is a fundamental incompatibility - see solution below
```

**Why this happens**: Nix + pkgdown + Quarto + bslib = fundamentally incompatible

**→ Solution**: [TARGETS_PKGDOWN_OVERVIEW.md](./TARGETS_PKGDOWN_OVERVIEW.md)
**→ Details**: [Wiki: Pkgdown + Quarto + Nix Issue](https://github.com/JohnGavin/claude_rix/wiki/Pkgdown-Quarto-Nix-Issue)

---

### 5. nix-shell Takes Forever to Start

**Symptoms**:
```bash
$ nix-shell default.nix
these 47 derivations will be built:
...
(waits 20+ minutes)
```

**Quick Fix**:
```bash
# Use cachix to speed up future runs
nix-shell --option binary-caches "https://cache.nixos.org https://johngavin.cachix.org"

# OR: Set up cachix permanently (one-time setup)
cachix use johngavin
```

**Why this happens**: Building packages from source (first time or cache miss)

**→ Details**: [Wiki: Performance Issues](https://github.com/JohnGavin/claude_rix/wiki/Troubleshooting-Performance)

---

## Prevention Best Practices

### ✅ DO

1. **Restart shell every 2-3 hours** during long sessions
2. **Use cachix** for fast CI builds
3. **Use `nix-collect-garbage --delete-older-than 30d`** (not `-d`)
4. **Push to cachix BEFORE git push**
5. **Keep default.nix up to date**

### ❌ DON'T

1. **Never use `nix-collect-garbage -d`** during active sessions
2. **Don't use `install.packages()`** in Nix (read-only store)
3. **Don't skip cachix** if you care about CI speed
4. **Don't commit directly to main** (use PR workflow)

---

## Essential Commands

### Check Environment

```bash
# Verify you're in nix shell
echo $IN_NIX_SHELL  # Should output: 1 or impure

# Check R version
R --version

# Check which R
which R  # Should output: /nix/store/.../bin/R

# List available R packages
Rscript -e ".libPaths()"
```

### Enter/Exit Environment

```bash
# Enter
cd /Users/johngavin/docs_gh/claude_rix/project_name
nix-shell default.nix

# Exit
exit

# OR use persistent shell (recommended)
caffeinate -i ~/docs_gh/rix.setup/default.sh
```

### Update Environment

```r
# 1. Regenerate default.nix
source("default.R")

# 2. Restart shell
exit; nix-shell default.nix
```

---

## When Things Go Wrong

### Immediate Recovery Steps

```bash
# 1. Save any unsaved work
# 2. Exit shell
exit

# 3. Re-enter shell
nix-shell default.nix

# 4. Verify it works
which R git gh
R --version
```

### If That Doesn't Work

```bash
# Clean nix store (use with caution)
nix-collect-garbage --delete-older-than 7d

# Rebuild environment
nix-shell default.nix

# If still broken, regenerate default.nix
Rscript -e 'source("default.R")'
nix-shell default.nix
```

### Still Broken?

**→ See**: [Wiki: Complete Troubleshooting Guide](https://github.com/JohnGavin/claude_rix/wiki/Troubleshooting-Complete-Guide)
**→ Or**: [Open an issue](https://github.com/JohnGavin/claude_rix/issues)

---

## Long Session Management

### Session Hygiene

```bash
# Every 2-3 hours:
# 1. Commit or stash work
gert::git_add(".")
gert::git_commit("WIP: checkpoint")

# 2. Exit and re-enter shell
exit
nix-shell default.nix

# 3. Resume work
# (Your files are unchanged, environment is fresh)
```

### Warning Signs

Restart immediately if you see:
- ⚠️ "command not found" for tools that worked earlier
- ⚠️ Unusual slowness
- ⚠️ `/nix/store/xxx: No such file` errors
- ⚠️ R packages that won't load

---

## GitHub Actions Quick Fixes

### Builds Taking Too Long

**Problem**: Packages building from source (20+ minutes)

**Fix**: Use cachix

```yaml
# Add to workflow:
- uses: cachix/cachix-action@v12
  with:
    name: johngavin
    authToken: ${{ secrets.CACHIX_AUTH_TOKEN }}

# And push to cachix BEFORE git push:
nix-build package.nix
nix-store -qR --include-outputs result | cachix push johngavin
```

**→ See**: [NIX_WORKFLOW.md](./NIX_WORKFLOW.md)

### Workflow Failing with "Package not found"

**Problem**: Package in DESCRIPTION but not available in CI

**Fix**: Regenerate nix files

```r
# Ensure package is in default.nix
source("R/setup/generate_nix_files.R")
generate_all_nix_files()

# Commit updated files
gert::git_add(c("package.nix", "default-ci.nix"))
gert::git_commit("Update Nix files after DESCRIPTION change")
```

---

## Related Documentation

### Main Repository
- [NIX_WORKFLOW.md](./NIX_WORKFLOW.md) - Complete development workflow
- [TARGETS_PKGDOWN_OVERVIEW.md](./TARGETS_PKGDOWN_OVERVIEW.md) - pkgdown + Quarto solution
- [NIX_VS_NATIVE_R_QUICKREF.md](./NIX_VS_NATIVE_R_QUICKREF.md) - When to use Nix vs native R
- [AGENTS.md](./AGENTS.md) - Core principles and rules

### Wiki (Detailed Guides)
- **[Complete Troubleshooting Guide](https://github.com/JohnGavin/claude_rix/wiki/Troubleshooting-Complete-Guide)** - All issues covered in depth
- **[Environment Degradation](https://github.com/JohnGavin/claude_rix/wiki/Troubleshooting-Environment-Degradation)** - Detailed diagnosis and prevention
- **[Complete Nix Setup Guide](https://github.com/JohnGavin/claude_rix/wiki/Complete-Nix-Setup-Guide)** - First-time setup
- **[FAQs](https://github.com/JohnGavin/claude_rix/wiki/FAQs)** - Common questions answered

---

## Emergency Contact

If you're completely stuck:

1. **Check the wiki**: [Complete Troubleshooting Guide](https://github.com/JohnGavin/claude_rix/wiki/Troubleshooting-Complete-Guide)
2. **Search issues**: https://github.com/JohnGavin/claude_rix/issues
3. **Open new issue**: https://github.com/JohnGavin/claude_rix/issues/new

Include:
- What you were trying to do
- Error messages (full text)
- Output of: `echo $IN_NIX_SHELL; which R; R --version`

---

**Created**: December 2, 2025
**Purpose**: Quick reference for common Nix environment issues
**Questions?** See [Wiki: FAQs](https://github.com/JohnGavin/claude_rix/wiki/FAQs)
