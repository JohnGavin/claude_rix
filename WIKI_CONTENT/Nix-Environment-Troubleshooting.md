# Nix Environment Troubleshooting Guide

## Overview

This guide provides comprehensive troubleshooting strategies for Nix environments used in R package development. It consolidates lessons learned from real-world environment degradation issues, garbage collection problems, and long-session management.

## Table of Contents

1. [Quick Diagnosis](#quick-diagnosis)
2. [Environment Degradation](#environment-degradation)
3. [Garbage Collection Issues](#garbage-collection-issues)
4. [Prevention Strategies](#prevention-strategies)
5. [Recovery Procedures](#recovery-procedures)
6. [Long Session Management](#long-session-management)
7. [Advanced Solutions](#advanced-solutions)
8. [Package-Specific Issues](#package-specific-issues)
   - [pkgdown with Quarto Vignettes](#pkgdown-with-quarto-vignettes)

---

## Quick Diagnosis

### Symptoms Checklist

Run through this checklist to diagnose your issue:

```bash
# 1. Check if in nix shell
echo $IN_NIX_SHELL
# Should return: 1 or impure

# 2. Check PATH for broken nix store paths
for path in $(echo $PATH | tr ':' '\n' | grep /nix/store); do
  if [ ! -d "$path" ]; then
    echo "BROKEN: $path"
  fi
done

# 3. Test key commands
which git gh R
# Should return: /nix/store/.../bin/...

# 4. Try loading R packages
Rscript -e "library(devtools); library(usethis); library(gert)"
```

### Quick Fixes by Symptom

| Symptom | Quick Fix | Details Section |
|---------|-----------|-----------------|
| `command not found` | Exit & re-enter shell | [Environment Degradation](#environment-degradation) |
| `/nix/store/xxx: No such file` | Restart shell | [GC Issues](#garbage-collection-issues) |
| R packages won't load | Check `default.nix` | [Package Issues](#package-not-available) |
| Slow shell startup | Check nix cache | [Performance](#shell-too-slow) |
| Version conflicts | Check `r_ver` date | [Version Management](#version-conflicts) |

---

## Environment Degradation

### Problem Description

During long sessions (several hours), the nix environment degrades:
- Tools that were available become unavailable (`gh`, `git`, `curl`, `R`)
- Symlinks in PATH point to non-existent nix store paths
- Error messages like: `/nix/store/xxx-package/bin/command: No such file or directory`

### Root Causes

#### 1. Nix Garbage Collection During Active Session

**What Happens:**
```bash
# At session start:
$PATH includes: /nix/store/abc123-gh-2.82.1/bin

# Hours later, nix garbage collection runs (automatically or manually):
nix-collect-garbage -d  # ❌ Too aggressive

# Old path deleted from /nix/store/
# But $PATH still references it!
# Result: "No such file or directory"
```

**Why It Happens:**
- The nix store paths that were in `$PATH` at session start got garbage collected
- Nix's garbage collector removes "unused" store paths
- The session's `$PATH` still references the old, now-deleted paths

#### 2. Long-Running Shell Session

**Contributing Factors:**
- Session lasted several hours without restart
- Multiple nix operations during session
- No shell restart to pick up new environment
- PATH became stale as nix store changed

### Warning Signs

Early indicators of degradation:

1. ⚠️ Commands taking longer than usual
2. ⚠️ "command not found" for tools that worked earlier
3. ⚠️ R packages that loaded before won't load
4. ⚠️ Git operations failing unexpectedly
5. ⚠️ Unusual errors about missing libraries

**When you see these: Restart the shell immediately**

### Immediate Recovery

**Option 1: Exit and Re-enter (Fastest)**

```bash
# Exit broken shell
exit

# Re-enter nix shell
cd /Users/johngavin/docs_gh/claude_rix/project_name
nix-shell default.nix

# Takes seconds, fixes PATH
```

**Option 2: If You Have Unsaved R Session State**

```bash
# Save your R workspace first (in broken shell)
R
> save.image("~/recovery.RData")
> q()

# Then restart shell
exit
nix-shell default.nix

# Restore R session
R
> load("~/recovery.RData")
```

**Option 3: Find Working Binaries**

```bash
# Find what's actually available (temporary workaround)
find /nix/store -name "gh" -type f 2>/dev/null | head -1

# Use full path temporarily
/nix/store/XXXXX-gh-2.82.1/bin/gh run list ...
```

---

## Garbage Collection Issues

### The Problem

Running `nix-collect-garbage -d` removes **everything** not currently in use, including your active development environment.

### Garbage Collection Severity Levels

```bash
# ❌ NEVER USE (Most aggressive - breaks active environments)
nix-collect-garbage -d
# Removes EVERYTHING not actively referenced
# Will break your current shell!

# ✅ SAFE (Removes old generations, keeps current)
nix-collect-garbage --delete-older-than 30d
# Keeps anything from last 30 days

# ✅ SAFER (Removes orphaned packages only)
nix-collect-garbage
# Only removes packages with no references
```

### Creating GC Roots (Advanced)

**Prevent garbage collection of active environment:**

```bash
# Create GC root for current environment
nix-build /Users/johngavin/docs_gh/claude_rix/default.nix \
  -o ~/.nix-gc-roots/claude-env

# This tells GC: "Don't delete this environment"

# Later, when done:
rm ~/.nix-gc-roots/claude-env
```

**For multiple projects:**

```bash
# Create GC roots for all projects
cd /Users/johngavin/docs_gh/claude_rix
for project in */default.nix; do
  project_name=$(dirname "$project")
  nix-build "$project" -o ~/.nix-gc-roots/"$project_name"
done
```

---

## Prevention Strategies

### Strategy 1: Periodic Shell Restart (Simplest)

**Recommendation: Every 2-3 hours during long sessions**

```bash
# Check time since shell started
echo "Shell started: $(date -r /proc/$$/stat +%Y-%m-%d\ %H:%M)"

# Restart procedure (takes seconds)
exit
nix-shell default.nix
```

**Benefits:**
- Simple, no configuration needed
- Refreshes PATH automatically
- Picks up any nix store changes
- Takes only seconds

**When to restart:**
- Every 2-3 hours
- After any `nix-collect-garbage`
- When you see "command not found"
- Between major tasks

### Strategy 2: Use Safer Garbage Collection

```bash
# Add to cron or run manually when needed:
nix-collect-garbage --delete-older-than 30d

# Or create alias in ~/.zshrc or ~/.bashrc:
alias nix-gc-safe='nix-collect-garbage --delete-older-than 30d'
alias nix-gc-orphans='nix-collect-garbage'
```

**Benefits:**
- Keeps recent environments
- Won't break active sessions
- Still cleans up disk space

### Strategy 3: Monitoring Script

**Create health check:**

```bash
# ~/bin/check-nix-health.sh
#!/bin/bash
echo "=== Nix Environment Health Check ==="
echo ""

# Check for broken PATH entries
echo "Checking PATH..."
broken=0
for path in $(echo $PATH | tr ':' '\n' | grep /nix/store); do
  if [[ ! -d $path ]]; then
    echo "  ✗ BROKEN: $path"
    ((broken++))
  fi
done

if [ $broken -eq 0 ]; then
  echo "  ✓ All nix paths valid"
else
  echo "  ⚠️  Found $broken broken path(s)"
  echo "  → ACTION: Exit and restart shell"
fi

# Check R packages
echo ""
echo "Checking R packages..."
Rscript -e "
pkgs <- c('usethis', 'devtools', 'gh', 'gert', 'dplyr', 'targets')
ok <- sapply(pkgs, requireNamespace, quietly=TRUE)
cat(sprintf('  %s %s\n', ifelse(ok, '✓', '✗'), pkgs))
if (!all(ok)) {
  cat('\n  → ACTION: Restart shell or rebuild environment\n')
}
"

echo ""
echo "Environment: $(if [ -n \"$IN_NIX_SHELL\" ]; then echo \"✓ Nix shell\"; else echo \"✗ Not in nix\"; fi)"
```

**Usage:**

```bash
chmod +x ~/bin/check-nix-health.sh

# Run every hour or when suspicious
~/bin/check-nix-health.sh
```

### Strategy 4: Automated Shell Restart Reminder

**Add to shell config:**

```bash
# ~/.zshrc or ~/.bashrc
# Remind to restart after N hours

NIX_SHELL_START_TIME=$(date +%s)

check_nix_shell_age() {
  if [ -n "$IN_NIX_SHELL" ]; then
    current_time=$(date +%s)
    elapsed=$((current_time - NIX_SHELL_START_TIME))
    hours=$((elapsed / 3600))

    if [ $hours -ge 3 ]; then
      echo "⚠️  Nix shell running for ${hours} hours"
      echo "   Consider restarting: exit && nix-shell default.nix"
    fi
  fi
}

# Run check before each prompt
precmd() { check_nix_shell_age; }  # zsh
# PROMPT_COMMAND='check_nix_shell_age'  # bash
```

---

## Recovery Procedures

### Clean Rebuild

**When environment is completely broken:**

```bash
# 1. Exit all nix shells
exit

# 2. Optional: Clean up cached environments
nix-collect-garbage -d  # OK to use when NOT in shell

# 3. Navigate to project
cd /Users/johngavin/docs_gh/claude_rix/project_name

# 4. Rebuild environment from scratch
nix-shell default.nix

# 5. Verify tools available
which git gh R crew
Rscript -e "library(devtools); library(targets)"
```

### Rebuilding After Degradation

**Full recovery procedure:**

```bash
# 1. Save current work
cd /Users/johngavin/docs_gh/claude_rix/project_name
git status
# If uncommitted changes:
git add .
git commit -m "WIP: Before environment rebuild"

# 2. Document state
cat > RECOVERY_LOG.md << EOF
# Recovery Log - $(date)

## Symptoms
- Command not found errors
- Broken PATH entries

## Actions Taken
1. Exited degraded shell
2. Ran clean rebuild
3. Verified environment

## Commands
$(git log --oneline -5)
EOF

# 3. Exit and rebuild
exit
caffeinate -i ~/docs_gh/rix.setup/default.sh

# 4. Verify success
~/bin/check-nix-health.sh
```

---

## Long Session Management

### Best Practices for Multi-Hour Sessions

#### 1. Use tmux/screen

**Ultimate solution for persistence:**

```bash
# Start tmux session
tmux new -s nix-work

# Inside tmux: start nix shell
nix-shell default.nix

# Work normally...

# Detach (keeps shell running)
Ctrl+B, D

# Later: re-attach
tmux attach -t nix-work

# Shell is EXACTLY as you left it
```

**Advantages:**
- Shell persists across terminal close
- Survives system sleep
- Can reconnect from anywhere
- No environment degradation (until GC runs)

**Disadvantages:**
- Still vulnerable to GC
- Must be on same machine
- Uses resources when detached

#### 2. Checkpoint Strategy

**Create session checkpoints:**

```bash
# Every 2-3 hours
cat > .nix-session-checkpoint << EOF
Date: $(date)
Shell PID: $$
Nix Shell Start: $(date -r /proc/$$/stat)
Working Directory: $(pwd)
Git Branch: $(git branch --show-current)
Git Status: $(git status --short | wc -l) modified files
Last Commit: $(git log -1 --oneline)
EOF

# Commit checkpoint
git add .nix-session-checkpoint
git commit -m "Session checkpoint: $(date +%Y-%m-%d-%H%M)"
```

#### 3. Logging

**Track session activity:**

```r
# In R/setup/session_log.R
library(logger)

log_appender(appender_file("inst/logs/nix_session.log"))

log_info("=== Session started: {Sys.time()} ===")
log_info("Nix shell: {Sys.getenv('IN_NIX_SHELL')}")
log_info("R version: {R.version.string}")

# Log major operations
log_info("Running devtools::check()")
# ...
log_info("devtools::check() completed successfully")
```

---

## Advanced Solutions

### Direnv Integration

**Automatic environment management:**

**Note:** direnv alone is not sufficient if you need custom startup commands. The standard setup requires `~/docs_gh/rix.setup/default.sh` which includes extra commands beyond just launching `default.nix`.

**If your setup is simple (just nix-shell default.nix):**

1. **Install direnv:**
   ```bash
   brew install direnv

   # Add to ~/.zshrc or ~/.bashrc
   eval "$(direnv hook zsh)"  # or bash

   source ~/.zshrc
   ```

2. **Create .envrc in project:**
   ```bash
   cd /Users/johngavin/docs_gh/claude_rix/project_name

   echo "use nix" > .envrc
   direnv allow
   ```

3. **Automatic activation:**
   ```bash
   cd project_name  # Environment loads automatically
   # ... work ...
   cd ..            # Environment unloads
   cd project_name  # Fresh environment loads
   ```

**Benefits:**
- Environment loads automatically when entering directory
- Environment unloads when leaving
- No stale PATH issues
- Handles multiple projects cleanly

**Limitations:**
- Only runs `nix-shell default.nix`
- Cannot run custom setup scripts like `default.sh`
- For complex setups, stick with manual shell management

### Nix Flakes

**Modern approach with locked dependencies:**

**Note:** Check if rix R package supports flakes before implementing. As of writing, standard rix workflow uses `default.nix`.

**If switching to flakes:**

1. **Enable flakes:**
   ```bash
   # Add to ~/.config/nix/nix.conf
   experimental-features = nix-command flakes
   ```

2. **Convert to flake (if rix supports it):**
   ```nix
   # flake.nix
   {
     description = "R package development environment";

     inputs = {
       nixpkgs.url = "github:rstats-on-nix/nixpkgs/2024-11-03";
     };

     outputs = { self, nixpkgs }: {
       devShells.aarch64-darwin.default =
         let pkgs = nixpkgs.legacyPackages.aarch64-darwin;
         in pkgs.mkShell {
           buildInputs = with pkgs; [
             R
             # ... your packages
           ];
         };
     };
   }
   ```

3. **Enter environment:**
   ```bash
   nix develop  # Instead of nix-shell
   ```

**Benefits:**
- Locked dependencies (flake.lock file)
- Active environments protected from GC
- Reproducible across machines
- Standard modern nix approach

**Trade-offs:**
- More complex setup
- Must convert from rix workflow
- Team must adopt flakes

---

## Package-Specific Issues

### Package Not Available

**Problem:** Package won't load in nix shell

**Solution:**

```r
# 1. Check if package in default.R
# Edit default.R
r_pkgs = c(
  "devtools",
  "mypackage"  # Add here
)

# 2. Check if package exists for that r_ver date
# Try different r_ver date if needed
r_ver = "2024-12-01"  # Try newer date

# 3. For packages not on CRAN, add as git_pkg
git_pkgs = list(
  list(
    package_name = "mypackage",
    repo_url = "https://github.com/user/mypackage",
    branch_name = "main",
    commit = "HEAD"  # Or specific commit
  )
)

# 4. Regenerate and rebuild
source("default.R")
exit  # Exit current shell
nix-shell default.nix
```

### Version Conflicts

**Problem:** Different package versions locally vs CI

**Solution:**

```r
# Ensure r_ver matches in all locations:
# 1. Local: /path/to/project/default.R
# 2. CI: Uses same default.nix from repo
# 3. Team: All use same default.nix

# Verify:
git diff default.R  # Should show no changes
git log default.R   # Check last modification

# Sync:
source("default.R")  # Regenerate default.nix
exit
nix-shell default.nix
```

### Shell Too Slow

**Problem:** `nix-shell` takes minutes to start

**Solution:**

```bash
# First time is slow (downloads everything) - this is normal

# If subsequent starts still slow:

# 1. Enable nix caching
# Add to ~/.config/nix/nix.conf:
experimental-features = nix-command flakes
max-jobs = auto

# 2. Use binary cache
substituters = https://cache.nixos.org https://nixpkgs-python.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=

# 3. Check disk space
df -h /nix

# 4. Clean old garbage (safely)
nix-collect-garbage --delete-older-than 30d
```

### pkgdown with Quarto Vignettes

**Problem:** `pkgdown::build_site()` fails when building Quarto vignettes with bslib styling

**Symptoms:**

```r
pkgdown::build_site()
# Error: [EACCES] Failed to copy
#   '/nix/store/.../bslib/lib/bs5/dist/js/bootstrap.bundle.min.js'
#   to '/private/tmp/.../bootstrap.bundle.min.js': Permission denied
```

**Root Cause:**

This is a **fundamental incompatibility** between three components:

1. **Quarto vignettes** require Bootstrap 5 for rendering
2. **Bootstrap 5** requires the `bslib` R package
3. **bslib** attempts to copy JS/CSS files from `/nix/store` (read-only) to temp directories

The Nix store is immutable by design - packages cannot copy files from it during runtime. This conflicts with how bslib works.

**Why This Cannot Be Fixed in Nix:**

- ❌ Setting `bslib: enabled: false` in `_pkgdown.yml` doesn't help - Quarto still loads bslib
- ❌ Using Bootstrap 3 template breaks Quarto vignettes (they require Bootstrap 5)
- ❌ Installing bslib to writable location fails - Nix blocks `install.packages()`
- ❌ Pre-rendering vignettes requires package installation - same Nix restriction

**Solution: Use Native R in CI, Not Nix**

For pkgdown with Quarto vignettes, use **r-lib/actions** in GitHub Actions instead of Nix:

```yaml
# .github/workflows/pkgdown.yml
jobs:
  pkgdown:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Quarto
        uses: quarto-dev/quarto-actions/setup@v2

      - name: Setup R  # ← Native R, not Nix
        uses: r-lib/actions/setup-r@v2
        with:
          use-public-rspm: true

      - name: Setup R dependencies
        uses: r-lib/actions/setup-r-dependencies@v2
        with:
          extra-packages: any::pkgdown, local::.
          needs: website

      - name: Clean docs directory  # ← Important!
        run: rm -rf docs/

      - name: Build pkgdown site
        run: pkgdown::build_site_github_pages(new_process = FALSE, install = FALSE)
        shell: Rscript {0}
```

**Why This Works:**

- ✅ Native R installs packages to writable locations (`R_LIBS_USER`)
- ✅ bslib can copy files without permission issues
- ✅ pak with GitHub Actions cache is fast (1-2 min, not 20+ min)
- ✅ Quarto vignettes render successfully

**Local Development Workaround:**

Since pkgdown cannot work locally in Nix with Quarto vignettes:

1. **Test data pipeline locally**: `targets::tar_make()` ✅
2. **Test package check locally**: `devtools::check()` ✅
3. **Test pkgdown in CI only**: Push and monitor GitHub Actions ✅
4. **Build reference docs only** (without vignettes):
   ```r
   pkg <- pkgdown::as_pkgdown(".")
   pkgdown::init_site(pkg)
   pkgdown::build_home(pkg)
   pkgdown::build_reference(pkg)  # Works in Nix
   ```

**References:**

- Example implementation: [statues_named_john#49](https://github.com/JohnGavin/statues_named_john/issues/49)
- Technical analysis: `R/setup/pkgdown_nix_solution.R`
- Session log: `R/setup/session_log_20251202_pkgdown_fix.R`

**Key Takeaway:**

Don't fight the Nix immutability model. For tools that need write access to package files (like bslib), use native R in CI and accept that full pkgdown builds won't work in local Nix environment.

---

## Troubleshooting Workflow

### Step-by-Step Diagnostic

```bash
# 1. Identify the problem
~/bin/check-nix-health.sh

# 2. Try quick fix first
exit
nix-shell default.nix

# 3. If that doesn't work, check GC roots
ls -la ~/.nix-gc-roots/

# 4. Rebuild if necessary
nix-collect-garbage --delete-older-than 30d
exit
nix-shell default.nix

# 5. Verify success
which git gh R
Rscript -e "library(devtools)"

# 6. Document issue
echo "$(date): Environment degraded, rebuilt successfully" >> ~/nix-issues.log
```

---

## Related Documentation

- **Main Context:** `context_claude.md` - Full project guidelines
- **Nix Skill:** `.claude/skills/nix-rix-r-environment/SKILL.md` - Nix/rix fundamentals
- **Agent Guide:** `AGENTS.md` - Session management and workflow
- **rix Documentation:** https://docs.ropensci.org/rix/
- **Nix Manual:** https://nixos.org/manual/nix/stable/

---

## Summary

### Critical Points

1. **Environment degradation is expected behavior** during long sessions with GC
2. **Quick fix: Exit and re-enter shell** - takes seconds, fixes most issues
3. **Prevention: Restart shell every 2-3 hours** during long sessions
4. **Never use `nix-collect-garbage -d`** while in active shell
5. **Monitor for warning signs** and restart proactively

### Recommended Setup

**For most users:**
1. Use persistent nix shell (not direnv, since we need `default.sh`)
2. Restart shell every 2-3 hours
3. Use safe garbage collection: `nix-collect-garbage --delete-older-than 30d`
4. Run health check script periodically

**For power users:**
1. Use tmux/screen for true persistence
2. Create GC roots for active projects
3. Consider migrating to flakes (if rix supports)
4. Automate health monitoring

### When to Use Each Strategy

| Scenario | Recommended Strategy |
|----------|---------------------|
| Short sessions (<2 hours) | Standard nix-shell, no special action |
| Long sessions (2-6 hours) | Restart shell every 2-3 hours |
| Very long sessions (>6 hours) | Use tmux + periodic restarts |
| Multiple projects | GC roots or direnv (if simple setup) |
| Team collaboration | Document r_ver, commit default.nix |
| CI/CD | Ensure default.nix in repo, use nix caching |

---

**Last Updated:** 2025-11-27
**Consolidated From:** CHECK_NIX_ENVIRONMENT_DEGRADATION.md, REBUILD_NIX_ENV.md, CLAUDE_SESSION_PERSISTENCE.md
