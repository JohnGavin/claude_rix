# Agent Guide for R Package Development

This document provides comprehensive guidelines for agents working on R package development projects using Nix, rix, and reproducible workflows.

## Quick Start for New Sessions

### 1. Session Initialization Checklist

✅ **Environment:** Verify you're in the nix shell (`caffeinate -i ~/docs_gh/rix.setup/default.sh`)
✅ **Context:** Read `.claude/CURRENT_WORK.md` if it exists
✅ **State:** Check `git status` and review recent commits
✅ **Checkpoint:** Review any `CLAUDE_CHECKPOINT.md` or session summary files
✅ **Packages:** Review installed vs. potential external R packages (CRAN/GitHub/R-universe)

**Package Review Protocol:**
At the start of each session, review the list of installed R packages. Identify potentially useful R packages available (CRAN, r-universe, GitHub) that are NOT already installed but might be relevant to project objectives (see `PLAN*.md` or GH issues). Highlight their pros and cons compared to the installed packages.

### 2. Key Documentation References

- **Main Context:** `context_claude.md` (detailed workflow, all project guidelines)
- **Nix Environment:** `.claude/skills/nix-rix-r-environment/SKILL.md` (environment setup)
- **Nix Troubleshooting:** `NIX_TROUBLESHOOTING.md` (degradation, recovery, prevention)
- **Workflow Skill:** `.claude/skills/r-package-workflow/SKILL.md` (8-step workflow)
- **Session Mgmt:** This document (session continuity strategies)

### 3. Critical Workflow Principles

**NEVER use bash git/gh commands** - Always use R packages:
- ✅ `gert::git_add()`, `gert::git_commit()`, `gert::git_push()`
- ✅ `usethis::pr_init()`, `usethis::pr_push()`, `usethis::pr_merge_main()`
- ✅ `gh::gh("POST /repos/...")` for GitHub API

**ALWAYS log commands** - For reproducibility:
- Create `R/setup/fix_issue_123.R` files documenting all R commands
- Include log files IN the PR, not after merge (prevents duplicate CI/CD runs)

**ALWAYS work in Nix environment:**
- Use ONE persistent shell per session
- Don't launch new shells for individual commands
- See `NIX_TROUBLESHOOTING.md` for environment degradation issues

**ALWAYS View Results via GitHub Pages:**
- All viewing of results must ultimately be through the deployed GitHub Pages website.
- Supply URLs pointing to the various output webpages (vignettes, dashboards, etc.).

### 4. Building R Packages as Nix Derivations

**CRITICAL**: R packages should be built as proper Nix derivations, not with `R CMD INSTALL` workarounds.

**The Proper Way (following rix/ropensci patterns):**

```nix
# package.nix - builds your R package as a Nix derivation
{ pkgs ? import <nixpkgs> {} }:

pkgs.rPackages.buildRPackage {
  name = "yourpackage";
  src = ./.;

  # Runtime dependencies
  propagatedBuildInputs = with pkgs.rPackages; [
    dplyr
    ggplot2
    # ... your Imports
  ];

  # Build dependencies
  nativeBuildInputs = with pkgs.rPackages; [
    knitr
    rmarkdown
  ];
}
```

**GitHub Actions workflow:**

```yaml
- name: Build package as Nix derivation
  run: nix-build package.nix

- name: Push to cachix
  run: nix-store -qR --include-outputs result | cachix push yourcache
```

**Why this matters:**
- ✅ Proper Nix reproducibility (pure, hermetic builds)
- ✅ Derivation lives in `/nix/store` with content-addressable hash
- ✅ Can be installed by downstream users from your cachix
- ✅ Follows rix/Nix philosophy completely
- ❌ NEVER use `R_LIBS_USER=/tmp` workarounds in CI

**References:**
- [rix cachix workflow](https://github.com/ropensci/rix/blob/main/.github/workflows/cachix-dev-env.yml)
- [rix documentation](https://docs.ropensci.org/rix/)

### 5. GitHub Actions Workflow Decision Guide

**CRITICAL**: Choose the right environment (Nix vs native R) for each CI/CD task.

#### Quick Decision Matrix

| Task | Use | Why |
|------|-----|-----|
| **R CMD check** | Nix | Must match local dev environment exactly |
| **Unit tests** | Nix | Reproducibility critical |
| **Data pipelines** | Nix | Reproducibility critical |
| **pkgdown (no Quarto)** | Nix | Works fine, maintainreproducibility |
| **pkgdown + Quarto vignettes** | Native R (r-lib/actions) | **Nix incompatible** with bslib |
| **Vignette rendering** | targets (both) | Pre-build with targets, commit HTML |

#### The Fundamental Incompatibility

**❌ Nix + pkgdown + Quarto + bslib = IMPOSSIBLE**

```
Quarto vignettes → require Bootstrap 5 → require bslib →
requires file copying from /nix/store → BLOCKED (read-only) → FAILS
```

**Why this cannot be fixed**:
- Nix: `/nix/store` is read-only by design (ensures reproducibility)
- bslib: Must copy JS/CSS files at runtime (design requirement)
- Quarto: Requires Bootstrap 5/bslib (design requirement)

These are three immutable constraints that create a fundamental incompatibility.

#### Solution: Hybrid Workflow

**For projects with Quarto vignettes**:

```yaml
# R-CMD-check.yml - Use Nix (reproducibility)
- uses: cachix/install-nix-action@v20
- run: nix-shell default-ci.nix --run "Rscript -e 'devtools::check()'"

# targets-pkgdown.yml - Use Native R (compatibility)
- uses: r-lib/actions/setup-r@v2
- run: Rscript -e 'targets::tar_make()'  # Pre-builds vignettes + pkgdown
```

**Key principle**: Use targets to pre-build vignettes (works in Nix), then pkgdown just copies pre-built HTML (fast, no Quarto needed in CI).

#### When to Use What

**Use Nix workflows when**:
- ✅ Task requires exact reproducibility
- ✅ Local development uses Nix
- ✅ R CMD check, unit tests, data pipelines
- ✅ pkgdown WITHOUT Quarto vignettes

**Use native R (r-lib/actions) when**:
- ✅ pkgdown with Quarto vignettes (Nix incompatible)
- ✅ Tasks requiring runtime file modifications
- ✅ Documentation builds (medium reproducibility acceptable)
- ✅ Quick prototypes or previews

**Use targets + pre-built vignettes when**:
- ✅ Quarto vignettes + pkgdown + Nix development
- ✅ Computationally expensive vignettes
- ✅ Vignettes with large datasets
- ✅ Need automation + fast CI

#### References

For complete details, see:
- **[`TARGETS_PKGDOWN_SOLUTION.md`](./TARGETS_PKGDOWN_SOLUTION.md)** - Complete implementation guide
- **[`NIX_VS_NATIVE_R_WORKFLOWS.md`](./NIX_VS_NATIVE_R_WORKFLOWS.md)** - Detailed decision criteria
- **[`NIX_TROUBLESHOOTING.md`](./NIX_TROUBLESHOOTING.md#pkgdown-with-quarto-vignettes)** - Troubleshooting

## Session Continuity Strategies

### What Persists Across Session Restarts

✅ **Files & Git:**
- All code changes, commits, branches
- Configuration files, documentation
- Everything in filesystem

✅ **Nix Environment:**
- Package versions (via `default.nix`)
- System configuration
- Consistent between local and CI/CD

❌ **What Does NOT Persist:**
- Conversation history (Claude has no memory of previous sessions)
- R session variables
- Shell environment variables (except those set by nix)

### Strategy: Document Everything

**End-of-Session Checklist:**

```bash
# 1. Commit or stash work
gert::git_add(".")
gert::git_commit("Progress: description")
# OR
git stash push -m "WIP: description"

# 2. Update current work file
# Edit .claude/CURRENT_WORK.md

# 3. Push to remote (backup)
gert::git_push()

# 4. Safe to exit
exit
```

**Start-of-Session Protocol:**

```bash
# 1. Enter nix shell
cd /Users/johngavin/docs_gh/claude_rix/project_name
nix-shell default.nix

# 2. First message to Claude should include:
"Please read:
- .claude/CURRENT_WORK.md (if exists)
- Recent commits via git log --oneline -5
- Git status and any uncommitted changes

Continue working on [specific task]."
```

### Strategy: Maintain `.claude/CURRENT_WORK.md`

**Template:**

```markdown
# Current Focus: [Brief description]

## Active Branch
[branch-name]

## What I'm Doing
[Current task description]

## Progress
- [x] Completed item 1
- [x] Completed item 2
- [ ] Next item
- [ ] Future item

## Blockers
- [Any issues preventing progress]

## Key Files Modified
- path/to/file1.R
- path/to/file2.R

## Important Notes
- [Context-specific notes]
- [Decisions made]

## Next Session Should
1. [First task]
2. [Second task]
```

**Update frequently** (every 1-2 hours or before breaks):

```r
# In R/setup/dev_log.R
# After significant progress, update .claude/CURRENT_WORK.md
```

### Strategy: Use Git for State Preservation

**WIP Commits:**

```r
# Save incomplete work safely
gert::git_add(".")
gert::git_commit("WIP: working on feature X - checkpoint before break")
gert::git_push()

# After restart, continue:
# Work is preserved, can reset or amend later
```

**Git Stash:**

```bash
# Before restart
git stash push -m "Work in progress on dashboard fix - $(date)"

# After restart
git stash list
git stash pop
```

## Common Workflow Violations & Lessons

### Violation 1: Using Bash Git Commands

**Example:** `WORKFLOW_VIOLATION_RETROSPECTIVE_2025-11-24.md`

**What Happened:**
```bash
# ❌ WRONG
git checkout -b fix-issue-37
git add file.R
git commit -m "message"
git push
gh pr create
```

**Why It Matters:**
- R commands can be re-executed from log files
- Bash commands harder to track and reproduce
- Breaks integration with devtools/targets/pkgdown

**Correct Approach:**
```r
# ✅ CORRECT
usethis::pr_init("fix-issue-37")
gert::git_add("file.R")
gert::git_commit("message")
usethis::pr_push()  # Creates PR automatically
```

### Violation 2: Logging After PR Merge

**Example:** `WORKFLOW_UPDATE_2025-11-26.md`

**What Happened:**
1. Created PR and merged to main
2. Created session log afterward
3. Committed log to main
4. Triggered duplicate CI/CD run

**Why It Matters:**
- Wastes GitHub Actions minutes
- Creates unnecessary workflow runs
- Log not reviewed as part of PR

**Correct Approach:**
```r
# ✅ Create log EARLY (Step 3: Make Changes)
# R/setup/fix_issue_123.R - document commands as you go

# Include in PR commits (Step 6: Push via PR)
gert::git_add(c(
  "R/new_feature.R",
  "tests/testthat/test-new-feature.R",
  "R/setup/fix_issue_123.R"  # ← Include log!
))

gert::git_commit("Fix #123: Description\n\nIncludes session log")
usethis::pr_push()
# ✅ Single CI/CD run with log included
```

## Nix Environment Management

### Quick Nix Environment Setup

**Starting Environment:**

```bash
# Launch persistent shell (do this ONCE per session)
caffeinate -i ~/docs_gh/rix.setup/default.sh
```

**CRITICAL: Verify Nix Environment is Active**

ALWAYS verify you're running inside the nix shell before starting work:

```bash
# 1. Check R is available and correct version
R --version
# Expected output: R version 4.4.1 (2024-06-14) or similar
# If you get "command not found", you're NOT in the nix shell!

# 2. Check Rscript is available
Rscript --version
# Expected output: R scripting front-end version 4.4.1

# 3. Check quarto is available (if needed for project)
quarto --version
# Expected output: version number (e.g., 1.4.550)

# 4. Verify git and gh are available
which git
which gh
# Expected output: /nix/store/... paths
# NOT /usr/bin/git or /usr/local/bin/git

# 5. Check you're in the correct directory
pwd
# Expected: /Users/johngavin/docs_gh/claude_rix/[project_name]
```

**If ANY command fails:**
- You are NOT in the nix shell
- Exit and re-run: `caffeinate -i ~/docs_gh/rix.setup/default.sh`
- Verify again before proceeding

**Common Signs You're NOT in Nix Shell:**
- ❌ `R: command not found`
- ❌ `which R` returns `/usr/bin/R` or `/usr/local/bin/R`
- ❌ R packages fail to load with "package not found"
- ❌ Different R version than expected

**Inside Shell - All Operations:**

```r
# R development
devtools::load_all()
devtools::test()
devtools::check()

# Git operations
gert::git_status()
gert::git_add(".")
gert::git_commit("message")

# GitHub operations
gh::gh("GET /repos/owner/repo/issues")
usethis::pr_push()
```

### Handling Environment Degradation

**Symptoms:**
- Commands that worked earlier now fail with "command not found"
- `/nix/store/xxx/bin/command: No such file or directory`
- R packages won't load

**Quick Fix:**

```bash
# Exit and re-enter (takes seconds)
exit
nix-shell default.nix
```

**Prevention:**
- Restart shell every 2-3 hours during long sessions
- Use `nix-collect-garbage` not `nix-collect-garbage -d`
- See `NIX_TROUBLESHOOTING.md` for detailed strategies

## Best Practices for Long Sessions

### 1. Checkpoint Frequently

```bash
# Every 2-3 hours:
- Update .claude/CURRENT_WORK.md
- Commit progress
- Push to remote
- Restart nix shell (optional but recommended)
```

### 2. Document Decisions

```r
# In R/setup/dev_log.R
library(logger)
log_appender(appender_file("inst/logs/dev_session.log"))

log_info("Decision: Using approach X because Y")
log_info("Issue #42: Implemented feature Z")
```

### 3. Keep Context Visible

```r
# In .claude/CURRENT_WORK.md
## Decisions Made
- 2025-11-27 10:30: Chose webr::mount() over R-Universe for dashboard
- 2025-11-27 14:15: Decided to pre-build vignettes with targets
```

### 4. Test Incrementally

```r
# After each meaningful change:
devtools::load_all()  # Reload package
devtools::test()       # Run tests
# Don't wait until end of session!
```

## Multi-Day Project Continuity

### Day 1 End:

```r
# 1. Complete current task or reach logical checkpoint
# 2. Update .claude/CURRENT_WORK.md
# 3. Commit everything
gert::git_add(".")
gert::git_commit("End of day 1: Summary of progress")
gert::git_push()

# 4. Document for tomorrow
# Add to .claude/CURRENT_WORK.md:
## Next Session Should
1. Continue with task X
2. Review PR feedback (if any)
3. Start task Y
```

### Day 2 Start:

```bash
# 1. Enter environment
cd project
nix-shell default.nix

# 2. First Claude prompt:
"Read .claude/CURRENT_WORK.md and git log --oneline -5.
Continue working on [task from yesterday]."

# 3. Pick up exactly where you left off
```

## Troubleshooting Quick Reference

### "Command not found" errors
→ See `NIX_TROUBLESHOOTING.md` § Environment Degradation
→ Quick fix: `exit` then `nix-shell default.nix`

### Package version conflicts
→ Check `r_ver` date in `default.R`
→ Regenerate: `source("default.R")` then restart shell

### Forgot what I was doing
→ Read `.claude/CURRENT_WORK.md`
→ Run `git log --oneline -10` and `git status`
→ Check recent `R/setup/` log files

### CI/CD failing but local works
→ Ensure `default.nix` committed and up-to-date
→ Check GitHub Actions uses same nix environment
→ Review `.github/workflows/*.yml` for nix-shell commands

---

# ⚠️ CRITICAL: MANDATORY WORKFLOW - READ THIS FIRST ⚠️

## 🚨 THIS IS NOT OPTIONAL - ALL CHANGES MUST FOLLOW THIS WORKFLOW 🚨

**BEFORE making ANY code or documentation changes**, you MUST follow this workflow:

### The 8-Step Mandatory Workflow

**NO EXCEPTIONS. NO SHORTCUTS. NO "SIMPLE FIXES".**

1. **📝 CREATE GITHUB ISSUE FIRST**
   - Use `gh` package or GitHub website
   - Describe what needs to be fixed/added
   - Get issue number (e.g., #123)

2. **🌿 CREATE DEVELOPMENT BRANCH**
   - NEVER commit directly to main
   - Use: `usethis::pr_init("fix-issue-123-description")`

3. **✏️ MAKE CHANGES**
   - Edit code/docs on the dev branch
   - Commit using `gert::git_add()` and `gert::git_commit()`
   - NOT bash `git` commands

4. **📋 LOG ALL COMMANDS**
   - Create/update file in `R/setup/`
   - Log every R command used (for reproducibility)
   - Example: `R/setup/fix_issue_123.R`

5. **✅ RUN ALL CHECKS LOCALLY**
   ```r
   devtools::document()  # Update docs
   devtools::test()      # Run tests
   devtools::check()     # R CMD check
   pkgdown::build_site() # Build site
   ```
   - Fix ALL errors, warnings, notes before proceeding

6. **🚀 PUSH VIA PR**
   - Use: `usethis::pr_push()` (NOT bash `git push`)
   - This creates the PR and triggers GitHub Actions

7. **⏳ WAIT FOR GITHUB ACTIONS**
   - All workflows must pass ✅
   - R-CMD-check via Nix
   - Check Package via Nix
   - Build and Deploy pkgdown Site

8. **🔀 MERGE VIA PR**
   ```r
   usethis::pr_merge_main()  # Merge PR
   usethis::pr_finish()      # Clean up branch
   ```

### Why This Matters

- **Reproducibility**: Logged R commands can be re-run later
- **Traceability**: Every change linked to an issue and PR
- **Quality**: Checks catch problems before deployment
- **CI/CD**: GitHub Actions ensure consistency
- **Collaboration**: Clear history for future work

### Consequences of Skipping Workflow

**If you commit directly to main or skip steps:**
1. Create retrospective GitHub issue documenting the violation
2. Create log file in `R/setup/` explaining what was done
3. Document lessons learned
4. **Commit to never doing it again**

See example: `R/setup/doc_fix_retrospective.R` and issue #25

### Key Commands Reference

**⚠️ THESE COMMANDS MUST BE RUN INSIDE THE NIX ENVIRONMENT ⚠️**

Start Nix environment first:
```bash
caffeinate -i ~/docs_gh/rix.setup/default.sh
```

Then run R commands from within that environment:

```r
# ============================================================
# CRITICAL: RUN ALL OF THESE INSIDE NIX ENVIRONMENT ONLY
# ============================================================

# GitHub operations (gh package) - NEVER use gh CLI
gh::gh('POST /repos/OWNER/REPO/issues', title = "...", body = "...")
gh::gh('POST /repos/OWNER/REPO/pulls', title = "...", body = "...", head = "branch", base = "main")
gh::gh('GET /repos/OWNER/REPO/actions/runs')

# Branch operations (usethis package) - NEVER use git CLI
usethis::pr_init("branch-name")        # Creates branch
usethis::pr_push()                     # Pushes and creates PR
usethis::pr_merge_main()               # Merges PR
usethis::pr_finish()                   # Cleans up

# Git operations (gert package) - NEVER use git CLI
gert::git_add("file.R")                # Stage files
gert::git_add(c("file1.R", "file2.R")) # Stage multiple
gert::git_commit("Commit message")     # Commit locally
gert::git_push()                       # Push to remote
gert::git_branch_create("branch-name") # Create branch
gert::git_branch_checkout("branch")    # Switch branch

# Quality checks (devtools package) - MUST run in Nix
devtools::document()                   # Update docs
devtools::test()                       # Run tests
devtools::check()                      # R CMD check
pkgdown::build_site()                  # Build website

# ============================================================
# LOG ALL THESE COMMANDS IN R/setup/ OR R/log/ FILES
# ============================================================
```

**FORBIDDEN COMMANDS (never use these):**
```bash
❌ git add .
❌ git commit -m "message"
❌ git push
❌ gh pr create
❌ gh issue create
```

---

## 1. Environment Setup

### 📚 COMPREHENSIVE GUIDE: NIX PACKAGE DEVELOPMENT

**CRITICAL REFERENCE**: For detailed instructions on R package development in the nix shell, see:

👉 **[NIX_PACKAGE_DEVELOPMENT.md](/Users/johngavin/docs_gh/rix.setup/NIX_PACKAGE_DEVELOPMENT.md)** 👈

This guide covers:
- How to reload package code after changes (`devtools::load_all()`)
- Complete development workflow
- Troubleshooting common issues
- Integration with git workflow
- All scenarios (editing functions, adding features, testing dashboards, etc.)

**TL;DR**: Use `devtools::load_all(".")` after every code change!

### 🚨 CRITICAL: ALWAYS USE NIX ENVIRONMENT FOR ALL OPERATIONS 🚨

**MANDATORY: ALL git/GitHub operations MUST use R packages (gert, gh, usethis) inside the Nix environment**

- ✅ **ALWAYS USE**: `gert::git_add()`, `gert::git_commit()`, `gert::git_push()`
- ✅ **ALWAYS USE**: `usethis::pr_init()`, `usethis::pr_push()`, `usethis::pr_merge_main()`
- ✅ **ALWAYS USE**: `gh::gh("POST /repos/...")` for GitHub operations
- ❌ **NEVER USE**: `git add`, `git commit`, `git push` bash commands
- ❌ **NEVER USE**: `gh pr create`, `gh issue create` CLI commands

**WHY THIS IS CRITICAL:**
1. **Reproducibility**: R commands in log files can be re-executed exactly
2. **Traceability**: All operations logged in `R/setup/` and `R/log/` for audit trail
3. **Consistency**: Same environment locally and in GitHub Actions CI/CD
4. **Integration**: Seamless with devtools, targets, pkgdown workflows

### 1.1 Nix Environment Verification
- Crucial - All the nix related packages needed are already installed
- Execute all code only within this nix shell for the rest of this session for reproducibility
- Reference: `~/docs_gh/rix.setup/default.sh` -> `~/docs_gh/rix.setup/default.R` 
  - rix::rix() generates `/Users/johngavin/docs_gh/rix.setup/default.nix` 
    - This is the default.nix file used to generate this current single persistent nix shell 
  - inside which you are currently running.
  - This single persistent nix env comes from a default.R file 
    - in the top level folder that
    - uses rix::rix function to 
    - generate the default.nix file then 
    - run to create the single persistent nix env for each project.
    - do not start a new nix shell to run each new task single command 
  
- switch to the top level folder that contains the subfolders for each project
  - cd /Users/johngavin/docs_gh/claude_rix/
  - e.g. project example /Users/johngavin/docs_gh/claude_rix/random_walk for the `random_walk` project
- critical points
  - all shells that claude uses must run inside this single persistent nix shell
  - all R code must run inside this single persistent nix shell 
    - for reproducibility 
    - always do this for all projects. 
  - CRITICAL: use a single persistent nix env to run all R commands
    - do not launch new nix shells to run single R or bash commands

 


### 1.2 R Installation Check
- switch the nix shell working directory to /Users/johngavin/docs_gh/claude
- digest and summarise the ./context.md file
- CRITICAL 
  - you are running inside the same single persistent nix shell in which all the packages you need are already installed so do not try to install R packages locally.

### 1.3 Required Libraries
- digest ./default.R and ./default.nix
  - summarise which R packages listed in ./default.R are NOT available in R inside the current shell by trying to load them.
- e.g. to Verify that tidyverse development libraries can be loaded:
  - `c('usethis', 'devtools', 'gh', 'gert', 'logger', 'dplyr', 'duckdb', 'targets', 'testthat') |> sapply(library, char = TRUE) |> invisible()`

### 1.4 LLM-Powered Tools
- Use LLM-powered R package tools where needed
- Reference: https://posit.co/blog/posit-glimpse-newsletter-august-2025/
  - e.g. btw R package
- Purpose: Generate tidyverse code

### Claude projects context
+ This file ./context.md or ./context_claude.md explains the context for ALL projects
+ projects are in subfolders below this folder 
+ each project has its own prompt markdown file (e.g. prompt.md or similar) with instructions and context for that specific project, if that file exists. e.g. ./statues_named_john/prompt.md

## 2. R Code Standards

### 2.1 Package Organization
- Always organize R code into an R package
- Prepare for possible submission to R repositories (e.g., https://ropensci.org/r-universe/)

### 2.2 Documentation and Testing
- Add R documentation: `usethis::document()`
- Add tests: `usethis::test()`
- Pass R package checks with zero errors, warnings or notes

### 2.3 Code Style and Formatting
- Convert brief comments in code into log entries using the logger package
  - put the log files into a single subfolder inst/logs
  - 
- Prefer tidyverse code over base R code
- Use the air package to format R code
  - Code style
    + Only write comments if they explain a non-obvious aspect of the code, or the rationale behind it. 
    + If you have come to a certain conclusion, only write the salient points and the conclusion itself. 
    + If a comment doesn't make sense or appears to be out of date, err on the side of removing it.
    
    + Format the code
      + When you modify R code, you should use air to format it:
          air format tests/testthat # format all testthat tests
          air format tests/test-all.R # format test-all.R file (the test runner).
- Use typst rather than LaTeX for formula and text formatting

## 3. File Structure

### 3.1 Source Files
- Generate markdown, HTML, or PDF files as output from source Quarto (.qmd) files

### 3.2 Top-Level Organization
- Minimize files in the package top level
- Keep essential files only (e.g., README.md)
  - README.md should be derived from ./inst/qmd/README.qmd
  - README.md should visualise the folder structure via `fs::dir_ls` or similar.
  - List all vignettes, each with a brief bullet summary


### 3.3 Non-Essential Files, in the top-level-folder
- Store in valid R package subdirectories
- Example: `inst/qmd/` for .qmd files (e.g., `inst/qmd/README.qmd`)
- Cross-reference .qmd and .md/.html file locations
- Mark HTML/MD files as auto-generated (do not edit)

### 3.4 R Script Organization
- Project-specific R package files: `./R/`
- Non-package R files in subfolders:
  - `./R/setup/` - housekeeping tasks e.g. bug fix, new feature
  - `./R/tar_plans/` - target plans 
    - e.g. each vignette usually needs its own plan 
      - such as ./inst/qmd/telemetry.qmd is built from .R/tar_plans/plan_telemetry.R

### 3.5 Package Top-Level Folder Compliance
To comply with standard R package structure, restrict top-level folders to:
- Dotfiles (e.g., .gitignore, .Rbuildignore)
- Package compilation files (e.g., DESCRIPTION, NAMESPACE, LICENSE, README.md)
- Exceptions (must be added to .Rbuildignore):
  - Config files (.yml, _targets.R)__

## 4. Targets Package

### 4.1 Pre-calculation Strategy
- Use targets R package to precalculate all objects used in package vignettes
- Vignettes should only need to call `targets::read()` or `targets::load()` in most cases.
  - e.g. Display all tables, graphs, and other objects via targets
  - i.e. vignettes typically contain text and `targets::read()` or `targets::load()` with relatively little other code.

## 5. Development Workflow

✅ Access Mac filesystem at /Users/johngavin/docs_gh/claude_rix
✅ Run R code using gert, gh, usethis packages
✅ Create Git branches (gert::git_branch_create())
✅ Stage and commit files (gert::git_add(), gert::git_commit())
✅ **MANDATORY: Push to cachix BEFORE pushing to GitHub**
✅ Push to GitHub (gert::git_push(), usethis::pr_push())
✅ Create GitHub issues (gh::gh("POST /repos/..."))
✅ Create Pull Requests (gh::gh("POST /repos/.../pulls"))
✅ Monitor GitHub Actions (gh::gh("GET /repos/.../actions/runs"))

### CRITICAL: Updated 9-Step Workflow (December 2025)

**The workflow is now 9 steps (was 8). Step 5 is MANDATORY: Push to cachix BEFORE git push.**

```
┌────────────────────────────────────────────────────────────────┐
│ 1. Create GitHub Issue (#123)                                 │
│ 2. Create dev branch (usethis::pr_init())                     │
│ 3. Make changes locally                                       │
│ 4. Run all checks (devtools::check(), etc.)                   │
│ 5. ⚠️ MANDATORY: Push to johngavin cachix ⚠️                   │
│    └─→ nix-store ... | cachix push johngavin                  │
│ 6. Push to GitHub (usethis::pr_push())                        │
│ 7. Wait for GitHub Actions (pulls from cachix - fast!)        │
│ 8. Merge PR (usethis::pr_merge_main())                        │
│ 9. Log everything (R/setup/fix_issue_123.R)                   │
└────────────────────────────────────────────────────────────────┘
```

**Why Step 5 is Mandatory:**
- GitHub Actions pulls packages from johngavin cachix instead of rebuilding
- Saves CI/CD time and resources
- Ensures identical builds locally and in CI
- Prevents "works locally but fails in CI" issues

### 4.5 Generating Nix Files with rix

**CRITICAL**: All nix files should be generated transparently from DESCRIPTION using R code for reproducibility.

#### The Three-File Strategy

Every project needs THREE nix files:

1. **`package.nix`**: Package derivation (runtime deps only)
   - Built from DESCRIPTION `Imports` → `propagatedBuildInputs`
   - Built from DESCRIPTION `Suggests` (vignette builders) → `nativeBuildInputs`
   - Used by: `nix-build package.nix`, cachix, GitHub Actions

2. **`default-ci.nix`**: CI/dev environment (all deps + dev tools)
   - Built from DESCRIPTION all deps + dev tools (devtools, usethis, gert, gh, etc.)
   - Generated by: `rix::rix()` function
   - Used by: Local development, GitHub Actions for testing/building

3. **`default.nix`**: Symlink to `default-ci.nix`
   - Ensures local development uses same environment as CI
   - Created by: `ln -s default-ci.nix default.nix`

#### Using R/setup/generate_nix_files.R

**Every project should have this script** to generate all nix files from DESCRIPTION:

```r
# Copy template from any existing project
cp ../random_walk/R/setup/generate_nix_files.R R/setup/

# Generate all nix files
source("R/setup/generate_nix_files.R")
generate_all_nix_files()

# Verify files are correct
generate_all_nix_files(verify = TRUE)

# Update after modifying DESCRIPTION
update_nix_files()
```

#### What Gets Generated

```r
# From DESCRIPTION:
Package: mypackage
Imports: dplyr, ggplot2
Suggests: testthat, knitr, rmarkdown, pkgdown

# Generates:
# package.nix:
#   propagatedBuildInputs = [ dplyr ggplot2 ]
#   nativeBuildInputs = [ knitr rmarkdown ]
#
# default-ci.nix (via rix::rix()):
#   rpkgs = [ dplyr ggplot2 testthat knitr rmarkdown pkgdown
#             devtools usethis gert gh rcmdcheck roxygen2 ]
```

#### When to Regenerate

Regenerate nix files whenever you:
- Add/remove R packages in DESCRIPTION
- Change R version requirements
- Update nixpkgs revision
- Start a new project

#### CI Verification

GitHub Actions includes a job that verifies nix files are up to date:

```yaml
- name: Verify nix files are up to date
  run: |
    Rscript -e 'source("R/setup/generate_nix_files.R"); generate_all_nix_files()'
    git diff --exit-code package.nix default-ci.nix
```

If files are out of date, CI fails with instructions to regenerate.

#### Complete Documentation

See **NIX_WORKFLOW.md** for complete details on:
- How content-addressable hashing ensures correctness
- Complete 9-step workflow
- GitHub Actions setup
- Cachix configuration
- Troubleshooting

### 5.0 Step 0: Project Initiation
- **Plan Proposal (`PLAN_what.md`)**: Create a high-level plan file focusing on *what* will be achieved.
  - **Objective**: Clear statement of goals.
  - **Data Sources**: List of data sources.
  - **Required R Packages**: A table grouped by highest-level purpose (e.g., Data Acquisition, Analysis), ordered alphanumerically within groups. Include a summary for each package.
  - **Package List**: A single line listing all packages, comma-separated, quoted, and sorted alphanumerically, and ending with a comma. e.g. "pkg1", "pkg2", "pkg3", 
  - **Requires User Approval** before proceeding.

- **Implementation Strategy (`PLAN_how.md`)**: Create a detailed strategy file focusing on *how* the plan will be implemented.
  - **Summary**: Start with a concise bullet-point summary of the implementation approach.
  - **Implementation Details**: Specific functions, logic, file structures, and algorithms.
  - **Requires User Approval** after `PLAN_what.md` is approved.

### 5.1 Step 1: Create GitHub Issue
- Raise issue on GitHub website describing the change/bug
- Obtain issue number (e.g., #123)

### 5.2 Step 2: Create Local Development Branch
```r
# In R/setup/dev_log.R
usethis::pr_init("fix-issue-123-description")
```

### 5.3 Step 3: Make Changes on Dev Branch
- Write code
- Commit locally only
- Log commands in `R/setup/dev_log.R`:
```r
gert::git_add(".")
gert::git_commit("Fix: description of change")
```

### 5.4 Step 4: Run All Checks Locally
```r
# In R/setup/dev_log.R
devtools::document()
devtools::test()
devtools::check()
pkgdown::build_site()
```
- Fix any errors/warnings/notes
- Ensure everything passes with no issues

### 5.5 Step 5: **MANDATORY** Push to Cachix BEFORE Git Push
```bash
# CRITICAL: Push to johngavin cachix BEFORE pushing to GitHub
# This ensures GitHub Actions can pull from cache instead of rebuilding
# Saves time and ensures consistent builds between local and CI/CD

# RECOMMENDED: Use the generic helper script (from any project directory)
../push_to_cachix.sh

# The script automatically:
# - Detects current package name from DESCRIPTION
# - Finds package in nix store
# - Pushes to johngavin cachix
# - Also pushes btw package if present

# OR manually:
nix-store -qR --include-outputs $(nix-instantiate default-ci.nix) | \
  grep -iE '<your-package-name>|btw' | \
  cachix push johngavin
```

**Generic Script Location:**
`/Users/johngavin/docs_gh/claude_rix/push_to_cachix.sh`

This script can be used from **any** project subdirectory. It auto-detects:
- Package name from DESCRIPTION file
- Nix file to use (default-ci.nix or default.nix)
- All packages to push (including btw)

**Why This is Mandatory:**
- ✅ GitHub Actions pulls from johngavin cachix (instant, no rebuild)
- ✅ Consistent derivations between local build and CI/CD
- ✅ Saves GitHub Actions minutes and resources
- ✅ Prevents "works locally but fails in CI" issues

**Workflow Order:**
```
Local Build → johngavin cachix → GitHub repo → GitHub Actions
              ↑ PUSH HERE FIRST                ↓ pulls from cachix (fast!)
```

### 5.6 Step 6: Push to Remote (Triggers GitHub Actions)
```r
# In R/setup/dev_log.R
# ONLY after cachix push succeeds
usethis::pr_push()
```

### 5.7 Step 7: Wait for GitHub Actions
Monitor all workflows:
- R-CMD-check via Nix
- Check Package via Nix
- Only run the workflows on Nix - ignore nix builder for MacOS and Windows.
- Build and Deploy pkgdown Site
- All must pass ✅

### 5.8 Step 8: Merge via Pull Request
```r
# In R/setup/dev_log.R
usethis::pr_merge_main()
usethis::pr_finish()
```
Actions performed:
- Creates PR on GitHub
- Merges to main
- Closes associated issue
- Deletes dev branch

### 5.9 Step 9: Log Everything
- For reproducibility
  - use ./R/setup/ to store .R files that document how R commands are used to setup and amend code, for reproducibility
- e.g. use usethis, gh, gert R packages to create issues, launch branches, fix issue/feature, document, test, R CHECK, commit, push, check .github/workflows, iterate to resolve issues, create PR, merge to main, delete branch, close issue
- All commands logged in `R/setup/*.R` e.g. dev_log.R etc
- Include:
  - Date/time
  - Issue number
  - Exact R commands used

**CRITICAL: Session Documentation Must Be Included in PR**

- ✅ **DO**: Create session log file (e.g., `R/setup/fix_issue_123.R`) and include it in the PR **before merging**
- ❌ **DON'T**: Commit session documentation to main branch **after** PR is merged
- **Why**: Committing to main after merge triggers duplicate CI/CD workflow runs, wasting resources
- **When**: Create log file during Step 3 (Make Changes), commit with Step 6 (Push via PR)

Example workflow:
```r
# Step 3: Create log file EARLY (before first commit)
# R/setup/fix_issue_123.R - documents all commands used

# Step 6: Include log in PR commits
gert::git_add(c("path/to/code.R", "R/setup/fix_issue_123.R"))
gert::git_commit("Fix #123: Description\n\nIncludes session log for reproducibility")

# Step 7: Merge PR (log is already included)
# ✅ Single workflow run with log included

# ❌ WRONG: Don't do this
# - Merge PR
# - Create session log
# - Commit to main  # <- Triggers duplicate workflows!
``` 

## 6. Git Best Practices
Use R packages gh and gert to interact with git and github.
Initialise a git repo in the top level folder, if necessary.
Log all git housekeeping R commands into the file ./R/log/git_gh.r for reproducability.
- Log github related commands in `<repo_name>/R/log/git_gh.r`
  - Log non-github exact commands in `<repo_name>/R/setup/dev_log.R`


### 6.1 Staging Strategy
- Stage changes early and often
- Stage everything to enable reverting if newer work needs to be abandoned

### 6.2 Git Worktrees
- Run Claude on two different problems in the same repository
- Like creating a branch but code will be in a different directory
- Example: `git worktree add ../tailwindcss.com-2 chore/upgrade-next`
- Creates another working directory for Claude Code

### 6.3 Development Approach
- Build prototypes that you only use once (e.g., dashboard visualizing current progress)
- Discuss changes before writing any code
- Only when certain Claude knows what you want:
  - Change one component, then 2, 4, 8, etc.

## 7. Bugs/Features/Issues Management

### 7.1 Issue Creation
- Enter all iterative code changes as GitHub issues on the GH website
- Create a GH branch for each change
- After passing all tests, merge to main branch via PR to close issue

### 7.2 Change Process
- Raise a GH issue on the GH website
- Create a local development branch
- When changes are complete, commit code to local branch only

### 7.3 Testing and Documentation
- Run all tests
  - Write tests
    - Use withr functionality to change the R environment for the duration of a test:
      + local_tempfile(...) # create temporary files: 
      + local_options(...) # set R options
- Run tests with testthat package
  - Run all tests:
```
options(FULL.TEST.SUITE=TRUE)
testthat::test_local(load_package='none')
```
Run a specific test file:
```
options(FULL.TEST.SUITE=TRUE)
testthat::test_file("tests/testthat/test.loadWorkbook.R")
```
+ When making multiple changes, run the tests after each change and fix any failures before moving on to the next change. 
  + In that case it's ok to run only the tests that you expect to be impacted.
- Build all docs
- Fix any issues

### 7.4 Remote Push and Merge
- When everything passes locally with no errors or notes:
  - Push to remote repo to trigger `.github/workflow` actions
  - Wait for all GitHub workflows to pass
  - Merge dev branch into main branch
  - Close the GH issue

### 7.5 Command Logging
- Use standard R functions from devtools/usethis packages
- Log exact commands in `<repo_name>/R/setup/dev_log.R`
  - `<repo_name>/R/log/git_gh.r` for github related R commands.
- Confirm reproducibility later

## 8. GitHub Project Page

### 8.1 Project Summary
Post summary of latest project state to GH projects webpage:
- Summary
- Features
- Summary results
- Possible future extensions

## 9. GitHub Actions and Rix/Nix Reproducibility

### 9.1 Environment Consistency
- Rix: All checks must run in the same rix/nix environment
- Reference: https://github.com/ropensci/rix
- find an example default.R file that generates default.nix environment
  - in the folder /Users/johngavin/docs_gh/rix.setup/
  - use this example to generate an appropriate default.R and default.nix and place them in the top level of the project folder for reproducability
- Must be consistent both locally and remotely in GH Actions workflows

### 9.2 Workflow Examples
- See: https://github.com/ropensci/rix/tree/main/.github/workflows

## 10. Telemetry Statistics

### 10.1 Vignette Creation
- Create vignette (`telemetry.qmd`)
- Exploit data stored by targets
  - you may have to load the objects directly from the targets cache to avoid circular loops, in a targets context.
- Visualize each pipeline created by targets tar_viznetwork
- Git history
  - Visualise git branches as a graph timeline if possible

### 10.2 Required Statistics
Graphs should include:
- Name of each target
- Time taken to compile
- Memory used
- Use existing functionality in targets package

### 10.3 Additional Statistics
Include as graphs/tables with appropriate sections:
- `sessionInfo()`
- use the fs R package to generate and store a tree of the pakcage file sturucture as a targer that can then be loaded into the `telemetry.qmd` vignette and the repo and website readme/home pages.
- GH summary
  - summarise the github repo status
- Coverage (covr R package)
  - summarise the test coverage of all R package code

### 10.4 Repository Update
- Commit and push to repo


# r-shinylive dashboard vignette
This section deals with instructions for dashboard vignettes that require r-Shinylive apps for Quarto.
Review https://github.com/posit-dev/r-shinylive such as 
  + https://github.com/posit-dev/r-shinylive?tab=readme-ov-file#github-pages
    + workflow to automatically deploy a Shiny app from the root directory in the GitHub repo to its GitHub Pages

## Dashboard pages

Some projects may request one or more r-shinylive dashboard apps.
+ Place each app inside its own dashboard page.
+ deploying a 
    + Shinylive for R app 
    + inside Quarto vigette
    + inside a specific project's R package
  + add horizontal titled pages as needed for each dashboard subtask 
    + to summarise the layout of the dashboard's structure
    + important pages on the left, least important on the right
      + or a sequence of steps starting on the left.


## `r-shinylive` references
Digest information via these references
  + https://posit-dev.github.io/r-shinylive/
  + https://quarto-ext.github.io/shinylive/
  + https://r-wasm.github.io/quarto-live/
    + https://parmsam.medium.com/package-tools-i-learned-about-at-posit-conf-2024-dbdd118ec14f§
    + https://github.com/coatless-quarto/r-shinylive-demo
  + https://nrennie.rbind.io/blog/webr-shiny-tidytuesday/

## Load this project's own R package inside r-shinylive
+ Load this project's R package(s) inside the r-shinylive dashboard app.
e.g. for the `random_walk` project there is a `randomwalk` R package
```{shinylive-r}
#| standalone: true
#| viewerHeight: 800

# Mount filesystem image from GitHub release containing randomwalk package
webr::mount(
  mountpoint = "/randomwalk-lib",
  source = "https://github.com/JohnGavin/randomwalk/releases/download/v0.1.0/library.data"
)

# Add mounted library to library paths
.libPaths(c("/randomwalk-lib", .libPaths()))

# Load only shiny at build time (randomwalk loaded at runtime)
library(shiny)

# Load randomwalk after mount (using requireNamespace to avoid build-time dependency check)
requireNamespace("randomwalk", quietly = TRUE)
```
+ To make the project's specific code available via github.
  + requires a .github/workflows workflow to generate the r-wasm on each push to main branch
+ Note: R-Universe is not needed just to host r-wasm files.
  + Github can generate and host r-wasm files that vignettes need e.g. to run shiny apps.

## r-shinylive and GUI code
+ keep the vignette GUI code in a separate module 
  + to be as independent as possible from the simulation code. 
+ add shiny tests as usual and keep all r-shinylive R code in a package as usual.

## Daily/weekly updates
+ Some vignettes may require periodic updates
  + e.g. Add a daily workflow to run targets::tar_make() in a nix shell to update this project's vignette(s) that contains dashboard pages 
+ Do this via nix .github/workflows workflow
  + send email if there is failure to john.b.gavin+dashboard.daily@gmail.com

## 11. Website (pkgdown)

### 11.1 Website Creation
- Create GitHub website for each new package via pkgdown
- Reference: https://pkgdown.r-lib.org/
- Include: documentation, examples, vignettes
- Display all .qmd vignettes as HTML files via dropdown
- Enable GitHub Pages if necessary

### 11.2 Vignette Pre-building
- Pre-build vignette HTML
- Include in the package
- Reference: `<repo_name>/_targets.R`

### 11.3 Code Visibility
- Keep all package website vignettes' code hidden by default
- Provide option to make each chunk visible if manually clicked
- Use clickable toggle: 'Display or Hide'

### 11.4 Content Display
- Display all vignette plots and tables via `targets::load()` or `targets::read()`
- Vignette code should be:
  - Stored in targets objects
  - Run via targets
  - Loaded from targets output

### 11.5 Documentation Standards
- Add brief text as captions to summarize each graph or table
- Add brief summary of purpose as section opening sentence for each vignette section

# Tidy up a project
+ at the end of a project's session
  + check carefully that all the relevant files in that project's folder (only) are checked into the remote github repo
  + for safety, zip the folder and all of its contents, into the top level folder claude_rix
  + delete any files and folders that are checked in github and can be downloaded from that github repo to start the next session from a clean directory.
    + first summarise any files that are not checked in
    + second explain why they are not needed for reproducibility
    + list the location and size, in human readable format, of the zip file
    + ask for confirmation to delete the remotely backed up GH files and folders.
  + leave any files that can be used to indentify how to download the remote GH code at the start of the next session e.g.  github related dotfiles, \*.git files


# Isolated shell / container
+ For reproducibility (and security)
+ LLM models should run inside this `--pure` nix shell or container 
  + to limit access to the folders that it can read 
    + and especially those it can write to.
+ ideally, there should be an explicit whitelist of allowed folders 
  + all subfolders of the whitelist list elements are readable and writeable by default.


# Linking to LLMs


## Using Gemini CLI for Large Codebase Analysis

When analyzing large codebases or multiple files that might exceed context limits, use the Gemini CLI with its massive context window, where possible.
Use `gemini -p` as a tool to leverage Google Gemini's large context capacity.

### When to Use Gemini CLI

Use gemini -p when:
- Analyzing entire codebases or large directories
  - e.g. for R package codebases see https://nrennie.rbind.io/r-pharma-2025-r-packages and the references it cites
  - e.g. leverage https://cran.r-project.org/web/packages/btw/index.html where appropriate 
  - e.g. to connect to gemini via ellmer R package so R commands can be stored in R/setup for reproducibility.
- Comparing multiple large files
- Need to understand project-wide patterns or architecture
- Current context window is insufficient for the task
- Working with files totaling more than 100KB
- Verifying if specific features, patterns, or security measures are implemented
- Checking for the presence of certain coding patterns across the entire codebase
+ when Gemini's context window handles larger codebases than Claude's context
+ No need for --yolo flag for read-only analysis
+ When checking implementations, be specific about what you're looking for to get accurate results

### File and Directory Inclusion Syntax

Use the `@` syntax to include files and directories in your Gemini prompts. The paths should be relative to WHERE you run the gemini command:

#### Examples:

**Single file analysis:**
gemini -p "@src/main.py Explain this file's purpose and structure"

Multiple files:
gemini -p "@package.json @src/index.js Analyze the dependencies used in the code"

Entire directory:
gemini -p "@src/ Summarize the architecture of this codebase"

Multiple directories:
gemini -p "@src/ @tests/ Analyze test coverage for the source code"

Current directory and subdirectories:
gemini -p "@./ Give me an overview of this entire project"

Or use --all_files flag:
gemini --all_files -p "Analyze the project structure and dependencies"

#### Implementation Verification Examples

Check if a feature is implemented:
gemini -p "@src/ @lib/ Has dark mode been implemented in this codebase? Show me the relevant files and functions"

Verify authentication implementation:
gemini -p "@src/ @middleware/ Is JWT authentication implemented? List all auth-related endpoints and middleware"

Check for specific patterns:
gemini -p "@src/ Are there any React hooks that handle WebSocket connections? List them with file paths"

Verify error handling:
gemini -p "@src/ @api/ Is proper error handling implemented for all API endpoints? Show examples of try-catch blocks"

Check for rate limiting:
gemini -p "@backend/ @middleware/ Is rate limiting implemented for the API? Show the implementation details"

Verify caching strategy:
gemini -p "@src/ @lib/ @services/ Is Redis caching implemented? List all cache-related functions and their usage"

Check for specific security measures:
gemini -p "@src/ @api/ Are SQL injection protections implemented? Show how user inputs are sanitized"

Verify test coverage for features:
gemini -p "@src/payment/ @tests/ Is the payment processing module fully tested? List all test cases"

## Important Notes

- Paths in @ syntax are relative to your current working directory when invoking gemini
- The CLI will include file contents directly in the context
- No need for --yolo flag for read-only analysis
- Gemini's context window can handle entire codebases that would overflow Claude's context
- When checking implementations, be specific about what you're looking for to get accurate results

## references
+ https://ellmer.tidyverse.org/reference/chat_google_gemini.html 
  + leveraging ellmer R package to use gemini 
+ https://github.com/jamubc/gemini-mcp-tool
+ https://www.reddit.com/r/ChatGPTCoding/comments/1lm3fxq/gemini_cli_is_awesome_but_only_when_you_make/

## Gemini Added Memories
- To successfully deploy the Quarto dashboard to GitHub Pages, you need to perform a manual configuration step on GitHub:

1.  Go to your GitHub repository (JohnGavin/daily_dashboard).
2.  Click on 'Settings'.
3.  In the left sidebar, click on 'Pages'.
4.  Under 'Build and deployment', select 'GitHub Actions' as the 'Source'.
5.  Save the changes.
 

## Shinylive and Quarto Troubleshooting

### Persistent Service Workers
**Problem:** Switching a page from Shinylive (WASM) to static HTML does not immediately fix "cannot open connection" errors in the browser.
**Cause:** Shinylive registers a Service Worker (`shinylive-sw.js`) that intercepts network requests. Even after the server code is updated, the user's browser may still use the old Service Worker, which tries to load the (now missing) app.
**Fix:**
1. Users must clear their browser's Service Workers/Application Cache.
2. Developers should ensure `shinylive-sw.js` is un-registered or removed from the deployment.

### Hidden Quarto Extensions
**Problem:** Removing `filters: - shinylive` from `_quarto.yml` is NOT sufficient to disable Shinylive.
**Cause:** If the `_extensions/quarto-ext/shinylive/` directory exists in the project, Quarto automatically applies the extension filters during rendering, injecting Shinylive assets and Service Workers even if not explicitly requested.
**Fix:** Delete the `_extensions/quarto-ext/shinylive/` directory entirely to permanently disable the functionality.
