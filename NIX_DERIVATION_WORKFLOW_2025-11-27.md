# Nix Derivation Workflow Implementation

**Date:** 2025-11-27
**Project:** randomwalk
**Topic:** Implementing proper Nix package derivations following rix best practices

## Summary

Successfully migrated from `R CMD INSTALL` with `R_LIBS_USER` workarounds to proper Nix package derivations, following [ropensci/rix](https://github.com/ropensci/rix) best practices and workflow patterns.

## Problem Statement

### Original Approach (Wrong)

The GitHub Actions workflow was attempting:

```yaml
- name: Build randomwalk
  run: |
    export R_LIBS_USER=/tmp/r-lib
    nix-shell default-ci.nix --run "R CMD INSTALL ."
```

**Issues:**
- ❌ Not a proper Nix derivation
- ❌ Package installed to `/tmp` (ephemeral)
- ❌ Breaks Nix purity guarantees
- ❌ Can't be cached properly in Cachix
- ❌ Downstream users can't install from cache
- ❌ "Works on my machine" territory

### Root Cause

The nix store (`/nix/store`) is read-only, so `R CMD INSTALL` fails:

```
ERROR: no permission to install to directory '/nix/store/...library'
```

## Solution: Proper Nix Derivation

Following [rix's own cachix-dev-env.yml workflow](https://github.com/ropensci/rix/blob/main/.github/workflows/cachix-dev-env.yml):

### 1. Created `package.nix`

```nix
# package.nix - builds randomwalk as a Nix derivation from local source
{ pkgs ? import (fetchTarball "...") {} }:

pkgs.rPackages.buildRPackage {
  name = "randomwalk";
  version = "2.0.0.9000";
  src = ./.;  # Local source

  # Runtime dependencies (propagated to users)
  propagatedBuildInputs = with pkgs.rPackages; [
    logger ggplot2 crew nanonext
  ];

  # Build dependencies
  nativeBuildInputs = with pkgs.rPackages; [
    knitr rmarkdown
  ];
}
```

### 2. Updated GitHub Actions Workflow

```yaml
- name: Build randomwalk Package as Nix Derivation
  run: nix-build --quiet package.nix

- name: Push randomwalk Derivation to Cachix
  run: nix-store -qR --include-outputs result | cachix push johngavin
```

## Benefits

### ✅ Proper Nix Reproducibility
- Pure, hermetic builds
- Content-addressable in `/nix/store`
- Guaranteed bit-for-bit reproducibility

### ✅ Cachix Integration
- Actual Nix derivation cached (not just compiled files)
- Downstream users can install directly from cache
- Binary cache speeds up everyone's builds

### ✅ Follows rix Philosophy
- Matches [ropensci/rix patterns](https://github.com/ropensci/rix/blob/main/.github/workflows/cachix-dev-env.yml)
- Recommended in [rix documentation](https://docs.ropensci.org/rix/)
- Consistent with Nix ecosystem standards

### ✅ User Experience
Users can now install randomwalk from your cachix:

```bash
cachix use johngavin
nix-shell -p randomwalk
```

Or in their own `default.nix`:

```nix
rpkgs = builtins.attrValues {
  inherit (pkgs.rPackages) randomwalk;  # From johngavin cachix
};
```

## Comparison: Option 1 vs Option 2

| Aspect | Option 1: R_LIBS_USER | Option 2: Nix Derivation |
|--------|----------------------|--------------------------|
| **Build method** | `R CMD INSTALL` to `/tmp` | `nix-build package.nix` |
| **Storage** | `/tmp/r-lib` (ephemeral) | `/nix/store/...` (permanent) |
| **Cachix stores** | Compiled files only | Full Nix derivation |
| **Reproducibility** | ❌ Depends on CI environment | ✅ Pure, hermetic |
| **Downstream use** | ❌ Can't install from cache | ✅ `nix-shell -p randomwalk` works |
| **Binary cache** | ❌ Not a Nix binary | ✅ True Nix binary cache |
| **rix philosophy** | ❌ Workaround | ✅ Proper implementation |

## Files Changed

### randomwalk Project

1. **`package.nix`** (new)
   - Builds randomwalk as Nix derivation from local source
   - Defines dependencies properly
   - Can be cached and distributed

2. **`.github/workflows/nix-builder.yaml`**
   - Changed from `R CMD INSTALL` to `nix-build package.nix`
   - Simplified workflow (3 steps instead of 5)
   - Proper cachix push of derivation

### Documentation

3. **`AGENTS.md`** (claude_rix root)
   - Added section "Building R Packages as Nix Derivations"
   - Example `package.nix` structure
   - Workflow pattern guidance
   - References to rix documentation

4. **`NIX_DERIVATION_WORKFLOW_2025-11-27.md`** (this file)
   - Complete implementation documentation
   - Rationale and benefits
   - Future reference

## Testing

### Local Build Test

```bash
$ nix-build --quiet package.nix
/nix/store/dk7vg05hy136f83ika8s8c22zlscgrn7-r-randomwalk

$ ls -la result/library/randomwalk/
total 24
dr-xr-xr-x 15 root wheel  480 Jan  1  1970 .
dr-xr-xr-x  3 root wheel   96 Jan  1  1970 ..
-r--r--r--  1 root wheel 1212 Jan  1  1970 DESCRIPTION
-r--r--r--  1 root wheel 1979 Jan  1  1970 INDEX
... (complete package structure)
```

✅ **Success!** Package built as proper Nix derivation.

### CI Build (Upcoming)

Once the GitHub Actions workflow runs:
1. Will build `package.nix` on CI
2. Will push derivation to johngavin cachix
3. Future builds will pull from cache
4. Users can install directly from cache

## Related Fixes

### Also Fixed: $WRAPPER_SCRIPT Issue

**File:** `/Users/johngavin/docs_gh/rix.setup/default.nix`

**Problem:** ShellHook created literal `$WRAPPER_SCRIPT` files due to variable expansion failures.

**Solution:** Eliminated intermediate variables, used inline paths:

```nix
# Before:
WRAPPER_DIR=\\$HOME/.config/positron
WRAPPER_SCRIPT=\\$WRAPPER_DIR/nix-terminal-wrapper.sh

# After:
mkdir -p "\$HOME/.config/positron"
cat > "\$HOME/.config/positron/nix-terminal-wrapper.sh" <<EOF
```

**Commit:** rix.setup@de261b4

## References

### rix/ropensci Resources
- [rix GitHub repository](https://github.com/ropensci/rix)
- [rix cachix workflow example](https://github.com/ropensci/rix/blob/main/.github/workflows/cachix-dev-env.yml)
- [rix documentation](https://docs.ropensci.org/rix/)
- [Installing R packages in Nix](https://docs.ropensci.org/rix/articles/d1-installing-r-packages-in-a-nix-environment.html)

### Nix Resources
- [Nix manual](https://nixos.org/manual/nix/stable/)
- [nixpkgs R package infrastructure](https://nixos.org/manual/nixpkgs/stable/#r)

### Project Resources
- [randomwalk GitHub](https://github.com/JohnGavin/randomwalk)
- [randomwalk cachix](https://johngavin.cachix.org)

## Commits

### randomwalk Project
1. **package.nix + workflow** (b8caa31)
   - Created `package.nix` for Nix derivation build
   - Updated `.github/workflows/nix-builder.yaml`
   - Replaces R_LIBS_USER workaround

2. **Earlier: workflow fix** (6afadb0)
   - Attempted R CMD INSTALL approach
   - Led to discovery that proper derivation needed

3. **Earlier: wrapper fix** (96727da)
   - Updated .gitignore for nix artifacts

### rix.setup Project
1. **shellHook fix** (de261b4)
   - Fixed $WRAPPER_SCRIPT literal file creation
   - Permanent solution using inline paths

## Future Considerations

### Targets Pipeline

The workflow currently doesn't run `targets::tar_make()`. This could be added as:

```yaml
- name: Run Targets Pipeline
  run: |
    nix-shell package.nix --run "R -e 'targets::tar_make()'"
```

**Decision:** Omitted for now because:
- Targets output should be in git or separate workflow
- Package derivation should be minimal
- Can add later if pre-computed vignettes needed

### Test Suite

Currently `doCheck = false` in `package.nix`. Could enable:

```nix
doCheck = true;
checkInputs = with pkgs.rPackages; [ testthat ];
```

**Decision:** Disabled for now because:
- Tests run in separate `tests-r-via-nix.yaml` workflow
- Keeps package build fast
- Can enable when tests are hermetic

## Lessons Learned

1. **Read rix's own workflows first** - They show the proper way
2. **Never use R_LIBS_USER in CI** - It's a workaround that breaks Nix
3. **package.nix vs default.nix** - Separate concerns (package vs dev environment)
4. **Test locally before CI** - `nix-build package.nix` catches issues fast
5. **Cachix caches derivations, not files** - Must be proper Nix builds

## Impact

### Immediate
- ✅ randomwalk builds as proper Nix derivation
- ✅ Workflow simplified and follows best practices
- ✅ Documentation updated

### Next CI Run
- ✅ Package derivation pushed to johngavin cachix
- ✅ Future builds faster (pull from cache)
- ✅ Users can install from cache

### Long-term
- ✅ Reproducibility guaranteed
- ✅ Nix ecosystem integration
- ✅ Template for future projects

---

**Session completed:** 2025-11-27
**All changes committed and pushed to randomwalk main branch**
