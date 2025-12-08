# R/setup/fix_issues_1_7_8.R
# Log for fixing issues #1, #7, #8

library(gert)

# -----------------------------------------------------------------------------
# Issue #1: Move nix-related documentation to repository wiki
# -----------------------------------------------------------------------------
# Objective: Clean up root directory by moving documentation to WIKI_CONTENT/

# Commands executed via shell (for efficiency):
# git mv NIX_DERIVATION_WORKFLOW_2025-11-27.md WIKI_CONTENT/
# git mv NIX_QUICKREF.md WIKI_CONTENT/
# git mv NIX_QUICKSTART.md WIKI_CONTENT/
# git mv NIX_VS_NATIVE_R_QUICKREF.md WIKI_CONTENT/
# git mv NIX_WORKFLOW.md WIKI_CONTENT/
# git mv archive/detailed-docs/NIX_TROUBLESHOOTING.md WIKI_CONTENT/
# git mv archive/detailed-docs/NIX_VS_NATIVE_R_WORKFLOWS.md WIKI_CONTENT/

# Commit for Issue #1
# gert::git_add("WIKI_CONTENT")
# gert::git_add("context_claude.md")
# gert::git_add("ISSUES_GROUPED_BY_DIFFICULTY.md")
# gert::git_commit("Fix #1: Move nix-related documentation to repository wiki and update workflow context")

# -----------------------------------------------------------------------------
# Issue #7: Embed Quarto presentations in pkgdown documentation
# -----------------------------------------------------------------------------
# Target Project: statues_named_john
# Plan: Modify _pkgdown.yml to include tutorials/presentations

# -----------------------------------------------------------------------------
# Issue #8: Display target source code in vignettes
# -----------------------------------------------------------------------------
# Target Project: statues_named_john
# Plan: Update vignettes to show tar_source()
