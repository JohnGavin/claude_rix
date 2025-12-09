# R/setup/fix_issue_12.R
# Fix issue #12: Add instruction for Infographic generation on major version

# 1. Initialize PR (Create branch)
# usethis::pr_init("fix-issue-12-infographic-instruction")

# 2. Commit changes
gert::git_add(c("context_claude.md", "R/setup/fix_issue_12.R", "R/setup/raise_issue_infographic.R"))
gert::git_commit("Fix #12: Add Infographics instruction to AGENTS.md\n\nIncludes session logs.")