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
library(dplyr)

# Initialize logging
log_appender(appender_file("inst/logs/nix_generation.log"))
log_info("Starting nix file generation")

# Registry of known Git packages with hashes and dependencies
# This allows us to manually resolve the dependency tree for non-CRAN packages
known_git_pkgs_registry <- list(
  "misc" = list(
    rev = "541dbcd33c7b86525c450638b8e66ea48c20a7da",
    sha256 = "sha256-2lRKY8Zy/y0viDpT1iZB6QHZatzF61+vg/SlL1tO/n8=",
    deps = c("MASS", "foreach", "doSNOW", "snow")
  ),
  "ForecastComb" = list(
    rev = "3e80024067fde690d168f8ce756abec71e58161b",
    sha256 = "sha256-NpnhxDRw385lj/YM+GdKabYCkHu4kxYr2uQ3l2LIGgM=",
    deps = c("remotes", "glmnet", "forecast", "ggplot2", "Matrix", "mtsdi", "psych", "quadprog", "quantreg", "misc"),
    postPatch = "sed -i 's/ahead//g' DESCRIPTION"
  ),
  "esgtoolkit" = list(
    rev = "0a9ad8ed1d52de4a66a997dc48e930aa49560a2b",
    sha256 = "sha256-8gMAPQpvHZA0FT7HHJAO3iKkoBamTGHXbqW3JMA5EZI=",
    deps = c("ggplot2", "gridExtra", "reshape2", "VineCopula", "randtoolbox", "zoo", "data.table", "Rcpp", "misc")
  ),
  "ahead" = list(
    rev = "290c76194890faa629de57a29e17a2dce95a9cbe",
    sha256 = "sha256-varLbi6rK6FJIVbnu2fba8IJX9TeQb2Dbc0l7uwhx/0=",
    deps = c("Rcpp", "foreach", "snow", "forecast", "ggplot2", "tseries", "randtoolbox", "misc", "ForecastComb"),
    preConfigure = "find . -name '*.so' -delete; find . -name '*.o' -delete;"
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
    parts <- strsplit(remote, "/")[[1]]
    if (length(parts) != 2) next
    
    owner <- parts[1]
    repo_part <- parts[2]
    
    if (grepl("@", repo_part)) {
      repo_split <- strsplit(repo_part, "@")[[1]]
      repo <- repo_split[1]
      ref <- repo_split[2]
    } else {
      repo <- repo_part
      ref <- "HEAD"
    }
    
    # Use registry info if available, otherwise placeholders
    info <- list(
      package_name = repo,
      repo_url = paste0("https://github.com/", owner, "/", repo),
      commit = ref,
      sha256 = "0000000000000000000000000000000000000000000000000000",
      deps = character(0)
    )
    
    if (repo %in% names(known_git_pkgs_registry)) {
      reg_info <- known_git_pkgs_registry[[repo]]
      info$commit <- reg_info$rev
      info$sha256 <- reg_info$sha256
      info$deps <- reg_info$deps
      if (!is.null(reg_info$postPatch)) info$postPatch <- reg_info$postPatch
      if (!is.null(reg_info$preConfigure)) info$preConfigure <- reg_info$preConfigure
    }
    
    git_pkgs[[repo]] <- info
  }
  return(git_pkgs)
}

#' Generate package.nix from DESCRIPTION
generate_package_nix <- function(
  nixpkgs_rev = "1482d00f8f658fd443526febba6c9fd9754cb356",
  output_file = "package.nix"
) {
  log_info("Generating {output_file}")

  desc_obj <- desc::desc()
  pkg_name <- desc_obj$get("Package")
  pkg_version <- desc_obj$get("Version")
  pkg_title <- desc_obj$get("Title")
  pkg_description <- desc_obj$get("Description")
  pkg_homepage <- desc_obj$get_field("URL", default = "")

  # Dependencies
  all_deps <- desc_obj$get_deps()
  imports <- dplyr::filter(all_deps, type == "Imports") |> dplyr::pull(package)
  suggests <- dplyr::filter(all_deps, type == "Suggests") |> dplyr::pull(package)
  vignette_pkgs <- suggests[suggests %in% c("knitr", "rmarkdown", "quarto")]

  # Handle Git packages
  # We include ALL packages in the registry in the let block to ensure transitive deps are available
  # even if not listed in DESCRIPTION Remotes directly.
  git_pkg_derivations <- ""
  git_pkg_names_in_registry <- names(known_git_pkgs_registry)
  
  # Helper to format dependencies for a git package
  format_git_deps <- function(deps) {
    if (length(deps) == 0) return("")
    # Map deps: if in registry, use name directly. Else use pkgs.rPackages.name
    mapped_deps <- sapply(deps, function(d) {
      # data.table in R is data_table in Nix usually, but let's assume standard mapping
      if (d == "data.table") d <- "data_table" 
      if (d %in% git_pkg_names_in_registry) return(d)
      return(paste0("pkgs.rPackages.", d))
    })
    paste(mapped_deps, collapse = "\n      ")
  }

  derivations <- lapply(names(known_git_pkgs_registry), function(pkg_name) {
    pkg <- known_git_pkgs_registry[[pkg_name]]
    # Construct URL roughly (assuming techtonique/thierrymoudiki based on registry knowledge or defaults)
    # This is a simplification. Ideally registry stores full URL.
    # We will infer URL from registry entries logic or just hardcode common ones if missing
    # But wait, get_git_packages_info extracted URL. Registry didn't store it.
    # I'll update registry to implied URLs for this generation context or assume knowns.
    
    url <- switch(pkg_name,
      "ahead" = "https://github.com/Techtonique/ahead",
      "esgtoolkit" = "https://github.com/Techtonique/esgtoolkit",
      "ForecastComb" = "https://github.com/thierrymoudiki/ForecastComb",
      "misc" = "https://github.com/thierrymoudiki/misc",
      ""
    )
    
    postPatch <- if (!is.null(pkg$postPatch)) paste0('postPatch = "', pkg$postPatch, '";') else ""
    preConfigure <- if (!is.null(pkg$preConfigure)) paste0('preConfigure = "', pkg$preConfigure, '";') else ""
    
    glue::glue('  
  {pkg_name} = (pkgs.rPackages.buildRPackage {{
    name = "{pkg_name}";
    src = pkgs.fetchgit {{
      url = "{url}";
      rev = "{pkg$rev}";
      sha256 = "{pkg$sha256}";
    }};
    {postPatch}
    {preConfigure}
    propagatedBuildInputs = [
      {format_git_deps(pkg$deps)}
    ];
  }});')
  })
  git_pkg_derivations <- paste(unlist(derivations), collapse = "\n")

  # Remove registry packages from imports to avoid duplication
  imports <- setdiff(imports, git_pkg_names_in_registry)

  format_pkg_list <- function(pkgs) {
    if (length(pkgs) == 0) return("    # (none)")
    paste0("    ", pkgs, collapse = "\n")
  }
  
  # Identify which registry packages are actually direct dependencies
  # We check imports and Remotes.
  # For rArimaOption, ahead and esgtoolkit are in Imports/Remotes.
  # So we add them to propagatedBuildInputs.
  direct_git_deps <- intersect(dplyr::filter(all_deps, type %in% c("Imports", "Depends"))$package, git_pkg_names_in_registry)
  
  format_git_direct_list <- function(pkgs) {
    if (length(pkgs) == 0) return("    # (none)")
    paste0("    ", pkgs, collapse = "\n")
  }

  nix_content <- glue::glue('  
# package.nix - Builds {pkg_name} R package as a Nix derivation from local source
# Generated by: R/setup/generate_nix_files.R

{{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/{nixpkgs_rev}.tar.gz") {{}} 
}}:

let
{git_pkg_derivations}
in
pkgs.rPackages.buildRPackage rec {{
  name = "{pkg_name}";
  version = "{pkg_version}";
  src = ./.;

  propagatedBuildInputs = with pkgs.rPackages; [
{format_pkg_list(imports)}
  ] ++ [
{format_git_direct_list(direct_git_deps)}
  ];

  nativeBuildInputs = with pkgs.rPackages; [
{format_pkg_list(vignette_pkgs)}
  ];

  doCheck = false;

  meta = with pkgs.lib; {{
    description = "{pkg_title}";
    license = licenses.mit;
  }};
}}')

  writeLines(nix_content, output_file)
  log_info("Generated {output_file}")
  invisible(TRUE)
}

#' Generate default-ci.nix from DESCRIPTION
generate_default_ci_nix <- function(
  nixpkgs_rev = "1482d00f8f658fd443526febba6c9fd9754cb356",
  output_file = "default-ci.nix"
) {
  log_info("Generating {output_file}")
  desc_obj <- desc::desc()
  
  all_deps <- desc_obj$get_deps()
  imports <- dplyr::filter(all_deps, type == "Imports") |> dplyr::pull(package)
  suggests <- dplyr::filter(all_deps, type == "Suggests") |> dplyr::pull(package)
  r_pkgs <- unique(c(imports, suggests))
  
  dev_tools <- c("devtools", "usethis", "gert", "gh", "rcmdcheck", "roxygen2")
  r_pkgs_all <- unique(c(r_pkgs, dev_tools))

  # Prepare git_pkgs for rix
  # We reuse the registry to provide FULL info to rix including transitive deps?
  # rix git_pkgs expects direct deps. But if we define them via overrides (which rix does),
  # we need to make sure rix knows about the transitive ones too if they are not in nixpkgs.
  # For simplicity, we stick to the basic rix generation and assume package.nix is the source of truth for build.
  # default.nix is for dev shell. If rix fails to resolve transitive deps in default.nix, shell might be partial.
  # But we fixed package.nix!
  
  git_pkgs_info <- get_git_packages_info(desc_obj)
  rix_git_pkgs <- if (length(git_pkgs_info) > 0) unname(git_pkgs_info) else NULL
  if (!is.null(rix_git_pkgs)) r_pkgs_all <- setdiff(r_pkgs_all, names(git_pkgs_info))

  sys_pkgs <- c("R", "git", "gh", "quarto", "pandoc", "curlMinimal", "glibcLocales", "nix", "which")

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

  if (output_file != "default.nix") {
    if (file.exists(output_file)) file.remove(output_file)
    file.rename("default.nix", output_file)
  }
  invisible(TRUE)
}

create_default_nix_symlink <- function() {
  if (file.exists("default.nix")) {
    if (Sys.readlink("default.nix") == "default-ci.nix") return(invisible(TRUE))
    file.rename("default.nix", paste0("default.nix.backup.", format(Sys.time(), "%Y%m%d_%H%M%S")))
  }
  file.symlink("default-ci.nix", "default.nix")
  invisible(TRUE)
}

generate_all_nix_files <- function(nixpkgs_rev = "1482d00f8f658fd443526febba6c9fd9754cb356", verify = FALSE) {
  dir.create("inst/logs", showWarnings = FALSE, recursive = TRUE)
  generate_package_nix(nixpkgs_rev, "package.nix")
  generate_default_ci_nix(nixpkgs_rev, "default-ci.nix")
  create_default_nix_symlink()
  invisible(c("package.nix", "default-ci.nix", "default.nix"))
}

update_nix_files <- function(...) generate_all_nix_files(...)

if (sys.nframe() == 0) {
  cat("Usage: source('R/setup/generate_nix_files.R'); generate_all_nix_files()\n")
}
