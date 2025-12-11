# generate_nix_files.R
#
# Purpose: Generate all nix files for reproducible R package development
# - package.nix: Package derivation (runtime deps only)
# - default-ci.nix: CI environment (package + dev tools)
# - default.nix: Local dev environment (symlink to default-ci.nix)
#
# This script uses the rix package to generate files from DESCRIPTION
# ensuring reproducibility and consistency between local and CI environments.
#
# Usage:
#   source("R/setup/generate_nix_files.R")
#   generate_all_nix_files()

library(rix)
library(desc)
library(glue)
library(logger)

# Initialize logging
log_appender(appender_file("inst/logs/nix_generation.log"))
log_info("Starting nix file generation")

# Registry of known Git packages with hashes
# This is a temporary solution until we can automate hash retrieval
known_git_pkgs_registry <- list(
  "ahead" = list(
    rev = "290c76194890faa629de57a29e17a2dce95a9cbe",
    sha256 = "sha256-varLbi6rK6FJIVbnu2fba8IJX9TeQb2Dbc0l7uwhx/0="
  ),
  "esgtoolkit" = list(
    rev = "0a9ad8ed1d52de4a66a997dc48e930aa49560a2b",
    sha256 = "sha256-8gMAPQpvHZA0FT7HHJAO3iKkoBamTGHXbqW3JMA5EZI="
  )
)

#' Get git package info from DESCRIPTION Remotes
#'
#' @return List of git package info
get_git_packages_info <- function(desc_obj) {
  remotes <- desc_obj$get_remotes()
  if (length(remotes) == 0) return(list())
  
  git_pkgs <- list()
  for (remote in remotes) {
    # Remotes format: owner/repo or owner/repo@ref
    parts <- strsplit(remote, "/")[[1]]
    if (length(parts) != 2) {
      log_warn("Skipping malformed remote: {remote}")
      next
    }
    
    owner <- parts[1]
    repo_part <- parts[2]
    
    if (grepl("@", repo_part)) {
      repo_split <- strsplit(repo_part, "@")[[1]]
      repo <- repo_split[1]
      ref <- repo_split[2]
    } else {
      repo <- repo_part
      ref <- "HEAD" # Default to HEAD if no ref specified
    }
    
    # Check registry
    if (repo %in% names(known_git_pkgs_registry)) {
      info <- known_git_pkgs_registry[[repo]]
      rev_to_use <- info$rev
      sha256_to_use <- info$sha256
    } else {
      rev_to_use <- ref
      sha256_to_use <- "0000000000000000000000000000000000000000000000000000" # Placeholder
      log_warn("Unknown git package '{repo}'. Using placeholder SHA256. Build will fail until updated.")
    }
    
    git_pkgs[[repo]] <- list(
      package_name = repo,
      repo_url = paste0("https://github.com/", owner, "/", repo),
      commit = rev_to_use,
      sha256 = sha256_to_use
    )
  }
  return(git_pkgs)
}

#' Generate package.nix from DESCRIPTION
#'
#' Creates a nix derivation that builds the R package with only
#' runtime dependencies (Imports) and build dependencies (Suggests
#' needed for vignettes like knitr/rmarkdown)
#'
#' @param nixpkgs_rev Character. Nixpkgs git revision for reproducibility
#' @param output_file Character. Path to output file (default: "package.nix")
#' @return Invisible TRUE on success
generate_package_nix <- function(
  nixpkgs_rev = "1482d00f8f658fd443526febba6c9fd9754cb356",  # R 4.4.1
  output_file = "package.nix"
) {
  log_info("Generating {output_file}")

  # Read DESCRIPTION
  desc_obj <- desc::desc()
  pkg_name <- desc_obj$get("Package")
  pkg_version <- desc_obj$get("Version")
  pkg_title <- desc_obj$get("Title")
  pkg_description <- desc_obj$get("Description")
  pkg_homepage <- desc_obj$get_field("URL", default = "")

  # Get dependencies
  imports <- desc_obj$get_deps() |>
    dplyr::filter(type == "Imports") |>
    dplyr::pull(package)

  # Only include vignette builders from Suggests
  suggests <- desc_obj$get_deps() |>
    dplyr::filter(type == "Suggests") |>
    dplyr::pull(package)

  # Filter to only vignette-related packages
  vignette_pkgs <- suggests[suggests %in% c("knitr", "rmarkdown", "quarto")]

  # Handle Git packages
  git_pkgs_info <- get_git_packages_info(desc_obj)
  
  git_pkg_derivations <- ""
  git_pkg_names <- character(0)
  
  if (length(git_pkgs_info) > 0) {
    git_pkg_names <- names(git_pkgs_info)
    
    # Remove git packages from imports if they are present (to avoid duplication/confusion)
    imports <- setdiff(imports, git_pkg_names)
    
    derivations <- lapply(git_pkgs_info, function(pkg) {
      glue::glue('  
  {pkg$package_name} = (pkgs.rPackages.buildRPackage {{ 
    name = "{pkg$package_name}";
    src = pkgs.fetchgit {{ 
      url = "{pkg$repo_url}";
      rev = "{pkg$commit}";
      sha256 = "{pkg$sha256}";
    }};
    propagatedBuildInputs = [
      # Dependencies for {pkg$package_name} (simplified)
      # You might need to manually add deps here if they are not in standard set
    ];
  }});
')
    })
    git_pkg_derivations <- paste(unlist(derivations), collapse = "\n")
  }

  # Format for nix
  format_pkg_list <- function(pkgs) {
    if (length(pkgs) == 0) return("    # (none)")
    paste0("    ", pkgs, collapse = "\n")
  }
  
  format_git_pkg_list <- function(pkgs) {
    if (length(pkgs) == 0) return("    # (none)")
    paste0("    ", pkgs, collapse = "\n")
  }

  # Generate nix file
  nix_content <- glue::glue(' 
# package.nix - Builds {pkg_name} R package as a Nix derivation from local source
#
# Generated by: R/setup/generate_nix_files.R
# Generated on: {Sys.time()}
#
# Usage:
#   nix-build package.nix           # Build the package
#   nix-shell package.nix           # Enter environment with {pkg_name} installed
#
# This derivation can be cached in Cachix and installed by downstream users.
# It uses the same nixpkgs revision as default-ci.nix for consistency.

{{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/{nixpkgs_rev}.tar.gz") {{}} 
}}:

let
{git_pkg_derivations}
in
pkgs.rPackages.buildRPackage rec {{
  name = "{pkg_name}";
  version = "{pkg_version}";

  # Build from local source (current directory)
  src = ./.;

  # Runtime dependencies (Imports from DESCRIPTION)
  # These are propagated to users who install {pkg_name}
  propagatedBuildInputs = with pkgs.rPackages; [
{format_pkg_list(imports)}
  ] ++ [
{format_git_pkg_list(git_pkg_names)}
  ];

  # Build-time dependencies (vignette builders)
  nativeBuildInputs = with pkgs.rPackages; [
{format_pkg_list(vignette_pkgs)}
  ];

  # Disable tests in package build (run separately in CI)
  doCheck = false;

  # Meta information
  meta = with pkgs.lib; {{
    description = "{pkg_title}";
    longDescription = \'\'
{pkg_description}
    \'\';
    homepage = "{pkg_homepage}";
    license = licenses.mit;
    maintainers = [];
    platforms = platforms.unix;
  }};
}}')

  writeLines(nix_content, output_file)
  log_info("Generated {output_file}")
  invisible(TRUE)
}

#' Generate default-ci.nix from DESCRIPTION
#'
#' Creates a development environment with:
#' - All R packages (runtime + development tools)
#' - System packages (git, gh, quarto, etc.)
#'
#' This is used by both local development and GitHub Actions
#'
#' @param nixpkgs_rev Character. Nixpkgs git revision
#' @param output_file Character. Path to output file
#' @return Invisible TRUE on success
generate_default_ci_nix <- function(
  nixpkgs_rev = "1482d00f8f658fd443526febba6c9fd9754cb356",
  output_file = "default-ci.nix"
) {
  log_info("Generating {output_file}")

  # Read DESCRIPTION
  desc_obj <- desc::desc()

  # Get ALL dependencies
  all_deps <- desc_obj$get_deps()
  imports <- all_deps |>
    dplyr::filter(type == "Imports") |>
    dplyr::pull(package)
  suggests <- all_deps |>
    dplyr::filter(type == "Suggests") |>
    dplyr::pull(package)

  # Combine and remove duplicates
  r_pkgs <- unique(c(imports, suggests))

  # Add development tools not in DESCRIPTION
  dev_tools <- c(
    "devtools",
    "usethis",
    "gert",
    "gh",
    "rcmdcheck",
    "roxygen2"
  )

  r_pkgs_all <- unique(c(r_pkgs, dev_tools))

  # Prepare git_pkgs for rix
  git_pkgs_info <- get_git_packages_info(desc_obj)
  
  # Format for rix: list of lists with package_name, repo_url, commit
  rix_git_pkgs <- NULL
  if (length(git_pkgs_info) > 0) {
    rix_git_pkgs <- unname(git_pkgs_info)
    # Remove git pkgs from r_pkgs_all to avoid conflicts
    r_pkgs_all <- setdiff(r_pkgs_all, names(git_pkgs_info))
  }

  # System packages needed
  sys_pkgs <- c(
    "R",
    "git",
    "gh",
    "quarto",
    "pandoc",
    "curlMinimal",
    "glibcLocales",
    "nix",
    "which"
  )

  # Use rix to generate the file
  # Note: rix always writes to "default.nix", so we'll rename it
  rix::rix(
    r_ver = nixpkgs_rev,
    r_pkgs = r_pkgs_all,
    system_pkgs = sys_pkgs,
    git_pkgs = rix_git_pkgs,
    ide = "none",
    project_path = ".",
    overwrite = TRUE,
    print = FALSE
  )

  # Rename default.nix to output_file if different
  if (output_file != "default.nix") {
    if (file.exists(output_file)) {
      file.remove(output_file)
    }
    file.rename("default.nix", output_file)
    log_info("Renamed default.nix to {output_file}")
  }

  log_info("Generated {output_file} with rix::rix()")
  invisible(TRUE)
}

#' Create default.nix as symlink to default-ci.nix
#'
#' Ensures local dev environment matches CI environment
#'
#' @return Invisible TRUE on success
create_default_nix_symlink <- function() {
  log_info("Creating default.nix symlink")

  if (file.exists("default.nix")) {
    # Check if it's already a symlink to default-ci.nix
    if (Sys.readlink("default.nix") == "default-ci.nix") {
      log_info("default.nix already points to default-ci.nix")
      return(invisible(TRUE))
    }

    # Back up existing file
    backup_name <- paste0("default.nix.backup.", format(Sys.time(), "%Y%m%d_%H%M%S"))
    file.rename("default.nix", backup_name)
    log_warn("Backed up existing default.nix to {backup_name}")
  }

  # Create symlink
  file.symlink("default-ci.nix", "default.nix")
  log_info("Created default.nix -> default-ci.nix symlink")

  invisible(TRUE)
}

#' Generate all nix files
#'
#' Main function that generates:
#' 1. package.nix (package derivation)
#' 2. default-ci.nix (CI/dev environment)
#' 3. default.nix (symlink to default-ci.nix)
#'
#' @param nixpkgs_rev Character. Nixpkgs revision (default: R 4.4.1)
#' @param verify Logical. If TRUE, verify generated files can be built
#' @return Invisible list of generated files
#' @export
generate_all_nix_files <- function(
  nixpkgs_rev = "1482d00f8f658fd443526febba6c9fd9754cb356",
  verify = FALSE
) {
  log_info("=== Starting nix file generation ===")
  log_info("Using nixpkgs revision: {nixpkgs_rev}")

  # Create inst/logs if needed
  dir.create("inst/logs", showWarnings = FALSE, recursive = TRUE)

  # Generate files
  generate_package_nix(nixpkgs_rev, "package.nix")
  generate_default_ci_nix(nixpkgs_rev, "default-ci.nix")
  create_default_nix_symlink()

  generated_files <- c("package.nix", "default-ci.nix", "default.nix")

  log_info("=== Generated files ===")
  for (f in generated_files) {
    if (file.exists(f)) {
      log_info("✓ {f}")
    } else {
      log_error("✗ {f} - MISSING")
    }
  }

  # Verification (optional)
  if (verify) {
    log_info("=== Verifying generated files ===")
    verify_nix_files()
  }

  log_info("=== Nix file generation complete ===")
  log_info("Next steps:")
  log_info("1. Review generated files")
  log_info("2. Test locally: nix-build package.nix")
  log_info("3. Push to cachix: ../push_to_cachix.sh")
  log_info("4. Commit and push to GitHub")

  invisible(generated_files)
}

#' Verify generated nix files
#'
#' Runs basic checks to ensure files are valid
#'
#' @return Invisible TRUE if all checks pass
verify_nix_files <- function() {
  log_info("Verifying nix files...")

  # Check syntax with nix-instantiate
  files_to_check <- c("package.nix", "default-ci.nix")

  for (f in files_to_check) {
    log_info("Checking {f}...")
    result <- system2(
      "nix-instantiate",
      args = c("--parse", f),
      stdout = TRUE,
      stderr = TRUE
    )

    if (attr(result, "status") != 0) {
      log_error("Syntax error in {f}")
      stop("Nix syntax error in ", f)
    }
    log_info("✓ {f} syntax OK")
  }

  log_info("All nix files verified successfully")
  invisible(TRUE)
}

#' Update nix files when DESCRIPTION changes
#'
#' Convenience function to regenerate files after modifying DESCRIPTION
#'
#' @param ... Arguments passed to generate_all_nix_files()
#' @export
update_nix_files <- function(...) {
  log_info("Updating nix files based on current DESCRIPTION")
  generate_all_nix_files(...)
}

# If sourced directly (not from another script), show usage
if (sys.nframe() == 0) {
  cat("
Nix File Generator for R Packages
==================================

Usage:
  source('R/setup/generate_nix_files.R')

  # Generate all nix files:
  generate_all_nix_files()

  # Generate with verification:
  generate_all_nix_files(verify = TRUE)

  # Use different nixpkgs revision:
  generate_all_nix_files(nixpkgs_rev = 'YOUR_GIT_HASH')

  # Update after modifying DESCRIPTION:
  update_nix_files()

Generated files:
  - package.nix: Package derivation (runtime deps)
  - default-ci.nix: CI/dev environment (all deps + tools)
  - default.nix: Symlink to default-ci.nix

")
}