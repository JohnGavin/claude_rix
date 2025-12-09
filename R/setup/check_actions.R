# R/setup/check_actions.R
library(gh)
runs <- gh::gh("GET /repos/JohnGavin/claude_rix/actions/runs", per_page = 5)
for (run in runs$workflow_runs) {
  cat(sprintf("Run %d (%s): %s - %s\n", run$id, run$name, run$status, run$conclusion))
}

