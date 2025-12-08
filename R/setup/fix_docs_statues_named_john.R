# R/setup/fix_docs_statues_named_john.R
# Log of R commands used to fix documentation issues for statues_named_john (Issue #3 related)

# Date: December 4, 2025

# Fixes for DEVELOPER_WORKFLOW.md
# 1. Replaced git_push() with usethis::pr_push() in "Step 5: Push to Trigger Fast CI"
#    - Tool Used: replace
#    - file_path: statues_named_john/DEVELOPER_WORKFLOW.md
#    - old_string: git_push()
#    - new_string: usethis::pr_push()
#    - instruction: Replace git_push() with usethis::pr_push() for consistency with the prescribed workflow.

# Fixes for QUICK_START_GUIDE.md
# 1. Replace bash git commands with gert/usethis R commands in "Step 10: Run Checks and Commit Changes"
#    - Tool Used: replace
#    - file_path: statues_named_john/R/setup/docs/QUICK_START_GUIDE.md
#    - old_string: (multiline string from original content)
#    - new_string: (multiline string with gert/usethis commands)
#    - instruction: Replace git add, git commit, and git push with their gert/usethis R equivalents.

# Log and commit the documentation changes
gert::git_add(c(
    "statues_named_john/DEVELOPER_WORKFLOW.md",
    "statues_named_john/R/setup/docs/QUICK_START_GUIDE.md",
    "R/setup/fix_docs_statues_named_john.R" # Log file itself
))

gert::git_commit("DOCS: Fix documentation issues in statues_named_john (Group 1)")
