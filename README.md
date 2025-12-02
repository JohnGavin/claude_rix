# Claude Agent Workspace for R Package Development

This workspace provides comprehensive documentation and tooling for Claude agents working on R package development projects using Nix, rix, and reproducible workflows.

## Quick Start

### For Claude Agents (New Session)

1. **Start Here:** Read [`AGENTS.md`](./AGENTS.md) - Session initialization checklist and quick reference
2. **Environment:** Verify you're in the nix shell (`caffeinate -i ~/docs_gh/rix.setup/default.sh`)
3. **Context:** Check [`.claude/CURRENT_WORK.md`](./.claude/CURRENT_WORK.md) if it exists
4. **Status:** Review `git status` and recent commits

### For Troubleshooting

- **Nix Issues:** See [`NIX_TROUBLESHOOTING.md`](./NIX_TROUBLESHOOTING.md) for comprehensive guidance
- **Quick Diagnosis:** Environment degradation, GC issues, recovery procedures
- **Long Sessions:** Management strategies and prevention

## Documentation Structure

```
claude_rix/
├── AGENTS.md ⭐ (Primary guide for agents - enhanced)
│   ├── Quick start for new sessions
│   ├── Session continuity strategies
│   ├── Workflow violations & lessons learned
│   └── Best practices for long sessions
│
├── NIX_TROUBLESHOOTING.md ⭐ (New comprehensive guide)
│   ├── Quick diagnosis checklist
│   ├── Environment degradation analysis
│   ├── GC issues and prevention
│   ├── Recovery procedures
│   └── Advanced solutions (direnv, flakes, GC roots)
│
├── CONSOLIDATION_SUMMARY.md (Tracking document)
│   ├── What was consolidated where
│   ├── Files removed (all content preserved)
│   └── Future maintenance guidelines
│
├── context_claude.md (Full project guidelines)
│   ├── 8-step mandatory workflow
│   ├── R code standards
│   ├── File structure requirements
│   ├── Targets package usage
│   ├── Development workflow
│   ├── Git best practices
│   ├── Testing & documentation
│   ├── Telemetry statistics
│   ├── Shinylive dashboards
│   └── pkgdown websites
│
├── .claude/skills/ (Claude Code skills)
│   ├── nix-rix-r-environment/SKILL.md (Enhanced troubleshooting)
│   ├── r-package-workflow/SKILL.md (8-step workflow)
│   ├── targets-vignettes/SKILL.md (Targets usage)
│   ├── shinylive-quarto/SKILL.md (Dashboard creation)
│   ├── project-telemetry/SKILL.md (Telemetry tracking)
│   └── gemini-cli-codebase-analysis/SKILL.md (Large codebase analysis)
│
└── [project_folders]/ (e.g., random_walk)
    ├── R/ (Package code)
    ├── tests/ (Test suite)
    ├── inst/ (Installed files)
    ├── vignettes/ (Documentation)
    ├── docs/ (Project-specific docs)
    │   └── session_summaries/ (Session archives)
    └── default.nix (Nix environment)
```

## Key Concepts

### The 8-Step Mandatory Workflow

**NO EXCEPTIONS. NO SHORTCUTS. NO "SIMPLE FIXES".**

1. **📝 CREATE GITHUB ISSUE FIRST** - Describe what needs to be fixed/added
2. **🌿 CREATE DEVELOPMENT BRANCH** - Use `usethis::pr_init("fix-issue-123")`
3. **✏️ MAKE CHANGES** - Edit code, commit via `gert::git_add()` & `gert::git_commit()`
4. **📋 LOG ALL COMMANDS** - Create `R/setup/fix_issue_123.R` documenting all R commands
5. **✅ RUN ALL CHECKS LOCALLY** - `devtools::document()`, `test()`, `check()`, `pkgdown::build_site()`
6. **🚀 PUSH VIA PR** - Use `usethis::pr_push()` (NOT bash `git push`)
7. **⏳ WAIT FOR GITHUB ACTIONS** - All workflows must pass ✅
8. **🔀 MERGE VIA PR** - `usethis::pr_merge_main()` & `usethis::pr_finish()`

### Critical Principles

**NEVER use bash git/gh commands:**
- ✅ Use `gert::git_add()`, `gert::git_commit()`, `gert::git_push()`
- ✅ Use `usethis::pr_init()`, `usethis::pr_push()`, `usethis::pr_merge_main()`
- ✅ Use `gh::gh("POST /repos/...")` for GitHub operations
- ❌ Never `git add`, `git commit`, `git push` bash commands

**ALWAYS log commands:**
- Create `R/setup/fix_issue_123.R` files documenting all R commands
- Include log files IN the PR, not after merge (prevents duplicate CI/CD runs)

**ALWAYS work in Nix environment:**
- Use ONE persistent shell per session
- Don't launch new shells for individual commands
- See `NIX_TROUBLESHOOTING.md` for environment degradation issues

## Projects in This Workspace

### random_walk
R package demonstrating random walk simulations with:
- Shinylive interactive dashboard
- Pre-computed targets pipeline
- Comprehensive test suite
- pkgdown documentation site

(Add other projects here as they are created)

## Common Tasks

### Starting a New Project

```bash
# 1. Enter nix environment
caffeinate -i ~/docs_gh/rix.setup/default.sh

# 2. Create project directory
mkdir -p project_name
cd project_name

# 3. Create default.R for nix environment
# (See .claude/skills/nix-rix-r-environment/SKILL.md)

# 4. Generate default.nix
Rscript -e "source('default.R')"

# 5. Initialize R package
Rscript -e "usethis::create_package('.')"

# 6. Initialize git
Rscript -e "usethis::use_git()"
```

### Session Management

**End of Session:**
```r
# 1. Commit work
gert::git_add(".")
gert::git_commit("Progress: description")
gert::git_push()

# 2. Update .claude/CURRENT_WORK.md
# 3. Exit: Ctrl+D
```

**Start of Session:**
```bash
# 1. Enter nix environment
caffeinate -i ~/docs_gh/rix.setup/default.sh

# 2. Review context
cat .claude/CURRENT_WORK.md
git log --oneline -5
git status

# 3. Continue work
```

### Troubleshooting Nix Environment

**Quick health check:**
```bash
# Check if in nix shell
echo $IN_NIX_SHELL

# Test key commands
which git gh R

# Try loading R packages
Rscript -e "library(devtools); library(usethis); library(gert)"
```

**If degraded (commands not found):**
```bash
# Exit and re-enter (fastest fix)
exit
nix-shell default.nix
```

See [`NIX_TROUBLESHOOTING.md`](./NIX_TROUBLESHOOTING.md) for comprehensive guidance.

## Resources

### Internal Documentation
- [`AGENTS.md`](./AGENTS.md) - Primary agent guide
- [`NIX_TROUBLESHOOTING.md`](./NIX_TROUBLESHOOTING.md) - Nix troubleshooting
- [`context_claude.md`](./context_claude.md) - Complete project guidelines
- [`.claude/skills/`](./.claude/skills/) - Claude Code skills

### External Resources
- **rix package:** https://github.com/ropensci/rix
- **rix documentation:** https://docs.ropensci.org/rix/
- **Nix manual:** https://nixos.org/manual/nix/stable/
- **R packages:** https://r-pkgs.org/
- **targets:** https://books.ropensci.org/targets/
- **pkgdown:** https://pkgdown.r-lib.org/

## Recent Updates

### 2025-11-27: Documentation Consolidation
- Created comprehensive `AGENTS.md` guide with session management
- Created `NIX_TROUBLESHOOTING.md` with environment degradation solutions
- Consolidated 7 scattered documents into organized structure
- Enhanced `.claude/skills/nix-rix-r-environment/SKILL.md`
- Archived project-specific content to respective projects
- See [`CONSOLIDATION_SUMMARY.md`](./CONSOLIDATION_SUMMARY.md) for details

## Contributing

This workspace follows strict reproducibility principles:
- All operations via R packages (gert, gh, usethis)
- All commands logged in `R/setup/` files
- All environments defined via nix
- All changes via GitHub issues → branches → PRs

See [`context_claude.md`](./context_claude.md) for complete guidelines.

---

**Last Updated:** 2025-11-27
**Maintained for:** Claude agents working on R package development projects
