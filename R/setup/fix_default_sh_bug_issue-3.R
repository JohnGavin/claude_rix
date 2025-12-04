# R/setup/fix_default_sh_bug_issue-3.R
# Log of R commands used to fix default.sh bugs (Issue #3)

# Date: December 4, 2025

# Step 3: Implement Fixes - Uncomment conditional logic for default.nix generation
# This replace call is intended to be executed externally, as default.sh is a symbolic link
# pointing outside the current working directory, and thus cannot be directly modified by replace.
replace(
    file_path = "default.sh", # This path refers to the symbolic link in the current directory
    old_string = """echo -e "\n=== STEP 1: Generate default.nix from default.R (if needed) ==="
                                                                                                                     
#if [ ! -f "$NIX_FILE" ] || [ "$NIX_FILE" -ot "$PROJECT_PATH/default.R" ]; then                                      
    echo "Regenerating default.nix from default.R..."                                                                
    nix-shell \
        --pure \
        --keep PATH \
        --keep TMPDIR \
        --keep GITHUB_PAT \
        --keep NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM \
        --expr \"$(curl -sl https://raw.githubusercontent.com/b-rodrigues/rix/master/inst/extdata/default.nix)\" \
        --command \" \
            Rscript \
            --vanilla \
            $PROJECT_PATH/default.R \
            --args GITHUB_PAT=$GITHUB_PAT\" \
        --cores 4 \
        --quiet                                                                                                      
#else                                                                                                                
#    echo "default.nix is up to date."                                                                               
#fi""",
    new_string = """echo -e "\n=== STEP 1: Generate default.nix from default.R (if needed) ==="
                                                                                                                     
if [ ! -f "$NIX_FILE" ] || [ "$NIX_FILE" -ot "$PROJECT_PATH/default.R" ]; then                                      
    echo "Regenerating default.nix from default.R..."                                                                
    nix-shell \
        --pure \
        --keep PATH \
        --keep TMPDIR \
        --keep GITHUB_PAT \
        --keep NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM \
        --expr \"$(curl -sl https://raw.githubusercontent.com/b-rodrigues/rix/master/inst/extdata/default.nix)\" \
        --command \" \
            Rscript \
            --vanilla \
            $PROJECT_PATH/default.R \
            --args GITHUB_PAT=$GITHUB_PAT\" \
        --cores 4 \
        --quiet                                                                                                      
else                                                                                                                
    echo "default.nix is up to date."                                                                               
fi""",
    instruction = "Uncomment and fix the conditional logic for default.nix generation to ensure it's regenerated only when default.nix doesn't exist or is older than default.R."
)