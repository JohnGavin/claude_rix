# Session Continuity Strategies

This guide details how to maintain context and continuity across agent sessions, ensuring work persists and can be resumed seamlessly.

## What Persists Across Session Restarts

✅ **Files & Git:**
- All code changes, commits, branches
- Configuration files, documentation
- Everything in filesystem

✅ **Nix Environment:**
- Package versions (via `default.nix`)
- System configuration
- Consistent between local and CI/CD

❌ **What Does NOT Persist:**
- Conversation history (Claude/Agent has no memory of previous sessions)
- R session variables
- Shell environment variables (except those set by nix)

## Strategy: Document Everything

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

# 2. First message to Agent should include:
"Please read:
- .claude/CURRENT_WORK.md (if exists)
- Recent commits via git log --oneline -5
- Git status and any uncommitted changes

Continue working on [specific task]."
```

## Strategy: Maintain `.claude/CURRENT_WORK.md`

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

## Strategy: Use Git for State Preservation

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
