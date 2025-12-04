#!/usr/bin/env bash
#
# push_to_cachix.sh - Push R package to johngavin cachix with robust error handling
#
# This script pushes your R package to cachix following rix best practices:
# - Validates environment before starting
# - Builds package from package.nix (not default-ci.nix)
# - Pushes with retry logic for network resilience
# - Pins package to prevent garbage collection
# - Provides clear error messages and recovery suggestions
#
# Usage:
#   ./push_to_cachix.sh
#
# Exit codes:
#   0 - Success
#   1 - General error
#   2 - Validation failed (missing files, not authenticated)
#   3 - Build failed (nix-build error)
#   4 - Push failed (cachix push error)
#   5 - Pin failed (cachix pin error)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Error handling
trap 'handle_error $? $LINENO' ERR

handle_error() {
  local exit_code=$1
  local line_number=$2
  echo -e "${RED}❌ ERROR: Script failed at line ${line_number} with exit code ${exit_code}${NC}"
  echo -e "${YELLOW}💡 Check the error message above for details${NC}"
  exit $exit_code
}

# Logging
log_step() {
  echo -e "${BLUE}$1${NC}"
}

log_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
  echo -e "${RED}❌ ERROR: $1${NC}"
}

log_warning() {
  echo -e "${YELLOW}⚠️  WARNING: $1${NC}"
}

log_info() {
  echo -e "${NC}ℹ️  $1${NC}"
}

# Retry function with exponential backoff
retry_command() {
  local max_attempts="${1:-3}"
  local timeout="${2:-5}"
  local command="${@:3}"
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    if eval "$command"; then
      return 0
    else
      if [ $attempt -lt $max_attempts ]; then
        local wait_time=$((timeout * attempt))
        log_warning "Attempt $attempt/$max_attempts failed. Retrying in ${wait_time}s..."
        sleep $wait_time
        ((attempt++))
      else
        log_error "All $max_attempts attempts failed"
        return 1
      fi
    fi
  done
}

# Validation functions
validate_file() {
  local file=$1
  local description=$2

  if [ ! -f "$file" ]; then
    log_error "$description not found: $file"
    return 1
  fi
  log_success "Found $description"
  return 0
}

validate_command() {
  local cmd=$1
  local description=$2

  if ! command -v "$cmd" &> /dev/null; then
    log_error "$description not found in PATH: $cmd"
    return 1
  fi
  log_success "Found $description"
  return 0
}

# Main script
main() {
  echo "═══════════════════════════════════════════════════════════"
  echo "   Push R Package to johngavin cachix"
  echo "═══════════════════════════════════════════════════════════"
  echo ""

  #
  # STEP 1: Validate environment
  #
  log_step "📋 Step 1/5: Validating environment..."

  # Check required files
  if ! validate_file "DESCRIPTION" "DESCRIPTION file"; then
    log_info "Make sure you're in the R package root directory"
    exit 2
  fi

  if ! validate_file "package.nix" "package.nix"; then
    log_info "Run: Rscript R/setup/generate_nix_files.R"
    exit 2
  fi

  # Check required commands
  if ! validate_command "nix-build" "nix-build"; then
    log_info "Install Nix: https://nixos.org/download.html"
    exit 2
  fi

  if ! validate_command "cachix" "cachix"; then
    log_info "Install cachix: nix-env -iA cachix -f https://cachix.org/api/v1/install"
    exit 2
  fi

  # Check cachix authentication
  if ! cachix authtoken --help &> /dev/null; then
    log_error "cachix not authenticated"
    log_info "Run: cachix authtoken <your-token>"
    log_info "Get token: https://app.cachix.org/personal-auth-tokens"
    exit 2
  fi

  log_success "Environment validated"
  echo ""

  #
  # STEP 2: Get package info
  #
  log_step "📦 Step 2/5: Reading package information..."

  PKG_NAME=$(grep "^Package:" DESCRIPTION | awk '{print $2}' | tr -d '\r' || echo "")
  PKG_VERSION=$(grep "^Version:" DESCRIPTION | awk '{print $2}' | tr -d '\r' || echo "")

  if [ -z "$PKG_NAME" ] || [ -z "$PKG_VERSION" ]; then
    log_error "Could not read package name/version from DESCRIPTION"
    exit 2
  fi

  log_success "Package: $PKG_NAME v$PKG_VERSION"
  echo ""

  #
  # STEP 3: Build package
  #
  log_step "🔨 Step 3/5: Building package with nix-build..."
  log_info "This may take a few minutes on first build..."

  # Build with better error handling
  BUILD_LOG="/tmp/nix-build-${PKG_NAME}.log"
  if ! nix-build package.nix --no-out-link > "$BUILD_LOG" 2>&1; then
    log_error "nix-build failed"
    log_info "Build log: $BUILD_LOG"
    log_info "Check syntax: nix-instantiate --parse package.nix"
    cat "$BUILD_LOG" | tail -20
    exit 3
  fi

  RESULT=$(nix-build package.nix --no-out-link 2>&1)
  log_success "Built: $RESULT"
  echo ""

  #
  # STEP 4: Push to cachix
  #
  log_step "📤 Step 4/5: Pushing to johngavin cachix..."
  log_info "Dependencies will be included (normal rix behavior)"
  log_info "Using retry logic for network resilience..."

  if ! retry_command 3 5 "cachix push johngavin '$RESULT'"; then
    log_error "Failed to push to cachix after 3 attempts"
    log_info "Check network connection"
    log_info "Check cachix status: https://status.cachix.org/"
    exit 4
  fi

  log_success "Pushed to johngavin cachix"
  echo ""

  #
  # STEP 5: Pin package
  #
  log_step "📌 Step 5/5: Pinning $PKG_NAME v$PKG_VERSION..."

  PIN_NAME="${PKG_NAME}-v${PKG_VERSION}"
  log_info "Pin name: $PIN_NAME"

  if ! retry_command 3 5 "cachix pin johngavin '$PIN_NAME' '$RESULT' --keep-forever"; then
    log_error "Failed to pin package after 3 attempts"
    log_warning "Package pushed but not pinned - may be garbage collected"
    log_info "Manually pin: cachix pin johngavin $PIN_NAME $RESULT --keep-forever"
    exit 5
  fi

  log_success "Pinned as $PIN_NAME (protected from GC forever)"
  echo ""

  #
  # SUCCESS
  #
  echo "═══════════════════════════════════════════════════════════"
  log_success "SUCCESS! Package pushed and pinned to cachix"
  echo "═══════════════════════════════════════════════════════════"
  echo ""
  echo "📊 Your cache now contains:"
  echo "   ✓ $PKG_NAME v$PKG_VERSION (pinned forever)"
  echo "   ✓ Dependencies (unpinned, will be GC'd when storage limit reached)"
  echo ""
  echo "🔗 Links:"
  echo "   • Monitor cache: https://app.cachix.org/cache/johngavin"
  echo "   • GC queue: https://app.cachix.org/garbage-collection"
  echo "   • Package: $RESULT"
  echo ""
  echo "💡 Next steps:"
  echo "   1. Commit nix files if changed: git add package.nix default-ci.nix"
  echo "   2. Push to GitHub: git push"
  echo "   3. GitHub Actions will use johngavin cache for fast builds"
  echo ""
  echo "ℹ️  Note: Users pulling $PKG_NAME will get dependencies from"
  echo "   rstats-on-nix cache, and only $PKG_NAME from johngavin cache"
  echo "   (layered cache approach for efficiency)"
  echo ""
}

# Run main function
main "$@"
