# R/setup/create_pr_12.R
library(gh)

# Create PR
pr <- gh::gh(
  "POST /repos/JohnGavin/claude_rix/pulls",
  title = "Fix #12: Add Infographics instruction to AGENTS.md",
  body = "Closes #12. Adds instructions for generating infographics on major version updates.",
  head = "fix-issue-12-infographic-instruction",
  base = "main"
)

cat(sprintf("Created PR #%d: %s\n", pr$number, pr$html_url))

