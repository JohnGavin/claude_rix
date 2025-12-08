# R/setup/raise_issue_default_sh_bug.R
# Log of R commands used to raise GitHub issue for default.sh bugs

# Date: December 4, 2025

# Raise a GitHub issue in the claude_rix project to correct bugs in default.sh

# Install and load the 'gh' package if not already installed
if (!requireNamespace("gh", quietly = TRUE)) {
  install.packages("gh")
}
library(gh)

issue_title <- "Bug: `default.sh` does not correctly handle `default.nix` generation and updates"

issue_body <- "Several issues have been identified with the `default.sh` script, particularly concerning its interaction with `default.nix` generation and updates. These bugs are impacting the reproducibility and reliability of the Nix environment setup.

**Problem 1: Script fails if `default.nix` does not exist on `rm` attempt and incorrect 'up to date' check.**

When attempting to remove and then regenerate `default.nix`, the script fails if the file is not initially present:
`rm ~/docs_gh/rix.setup/default.nix && caffeinate -i ~/docs_gh/rix.setup/default.sh`

Output:
```
error: path '/Users/johngavin/docs_gh/rix.setup/default.nix' does not exist
real  0m0.052s
user  0m0.031s
sys 0m0.015s
ERROR: nix-build failed.
```

Additionally, if `default.nix` exists but is empty (e.g., created by `touch`), the script incorrectly reports it as 'up to date' without regenerating it:
```
statues_named_john git:(main) ✗ touch ~/docs_gh/rix.setup/default.nix
➜  statues_named_john git:(main) ✗ cat ~/docs_gh/rix.setup/default.nix
➜  statues_named_john git:(main) ✗ caffeinate -i ~/docs_gh/rix.setup/default.sh

=== STEP 1: Generate default.nix from default.R (if needed) ===
default.nix is up to date.

=== STEP 2: Build shell and create persistent GC root ===
cachix use rstats-on-nix # BEFORE nix-build
Configured https://rstats-on-nix.cachix.org binary cache in /Users/johngavin/.config/nix/nix.conf
Starting nix-build '/Users/johngavin/docs_gh/rix.setup/default.nix' ...
error: syntax error, unexpected end of file
       at /Users/johngavin/docs_gh/rix.setup/default.nix:1:1:

real  0m0.050s
user  0m0.031s
sys 0m0.015s
ERROR: nix-build failed.
```

**Problem 2: `default.sh` does not recognize `default.R` updates.**

If `default.R` is edited (e.g., to include a bogus R package name), `default.sh` does not recognize that `default.R` has been updated (even if its last modified date is later than `default.nix`). This prevents `default.nix` from being regenerated to reflect the changes in `default.R`, leading to an invalid or outdated Nix environment.

**Expected Behavior:**

1.  `default.sh` should robustly handle the absence of `default.nix` by proceeding with regeneration from `default.R` without error.
2.  `default.sh` should always check if `default.R` has been modified more recently than `default.nix` and regenerate `default.nix` if `default.R` is newer, or if `default.nix` is empty or invalid.
3.  The script should generate `default.nix` in the specified project path (e.g., `$PROJECT_PATH`) and ensure it's used by the current working directory setup.

This is a priority issue as it directly impacts the reliability and reproducibility of the development environment."

# For the 'claude_rix' project, assuming repository is 'JohnGavin/claude_rix'
gh::gh(
  "POST /repos/JohnGavin/claude_rix/issues",
  title = issue_title,
  body = issue_body
)

