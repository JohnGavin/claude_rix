#!/bin/bash
# Quick Nix environment health check
# Usage: bash check_nix_health.sh

echo "=== Nix Environment Health Check ==="
echo ""

echo "Checking for broken PATH entries..."
broken=0
for path in $(echo $PATH | tr ':' '\n' | grep /nix/store); do
  if [[ ! -d $path ]]; then
    echo "  ✗ BROKEN: $path"
    ((broken++))
  fi
done

if [ $broken -eq 0 ]; then
  echo "  ✓ All Nix paths in PATH are valid"
else
  echo "  ✗ Found $broken broken path(s) - rebuild needed"
  echo ""
  echo "To rebuild:"
  echo "  1. Exit current shell: exit"
  echo "  2. cd /Users/johngavin/docs_gh/rix.setup"
  echo "  3. ./default.sh"
fi

echo ""
echo "Checking critical R packages..."
Rscript --vanilla -e "
pkgs <- c('usethis', 'devtools', 'gh', 'gert', 'dplyr', 'targets', 'tidyverse', 'shiny');
ok <- sapply(pkgs, requireNamespace, quietly=TRUE);
cat(sprintf('  %s %s\n', ifelse(ok, '✓', '✗'), pkgs));
all_ok <- all(ok);
if (!all_ok) {
  cat('\n  Some packages missing - rebuild recommended\n');
}
quit(status = if(all_ok && $broken == 0) 0 else 1)
"

echo ""
echo "Environment: $(if [ -n "$IN_NIX_SHELL" ]; then echo "Nix shell ($(if [ "$IN_NIX_SHELL" = "pure" ]; then echo "pure"; else echo "impure"; fi))"; else echo "Not in Nix"; fi)"
echo "R version: $(R --version | head -1)"
echo ""

if [ $broken -eq 0 ]; then
  echo "Status: ✓ Environment appears healthy"
  exit 0
else
  echo "Status: ✗ Environment needs rebuild"
  exit 1
fi
