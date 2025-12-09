# R/setup/raise_issue_infographic.R
# Raise issue to edit AGENTS.md for Infographic instruction

library(gh)

title <- "Add instruction for Infographic generation on major version"
body <- "Update `AGENTS.md` to include instructions for generating an Infographic explaining how the project-specific R package works.

- This should happen when the package reaches a major version.
- Embed the infographic into the `README.md` on the GH repo via a targets target.
- The target should only run when the version number reaches a milestone or substantially changes (major release)."

# Create the issue
new_issue <- gh::gh(
  "POST /repos/JohnGavin/claude_rix/issues",
  title = title,
  body = body
)

# Output the issue number
cat(sprintf("Created issue #%d\n", new_issue$number))
