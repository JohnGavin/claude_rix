#!/usr/bin/env Rscript
# verify_nix_r_env.R
# Verify that all R packages from default.R are loadable in the current Nix environment

library(cli)

cli_h1("Nix R Environment Verification")

# Dynamically load r_pkgs and pkgs_test from default.R
default_r_path <- "/Users/johngavin/docs_gh/rix.setup/default.R"

if (!file.exists(default_r_path)) {
  cli_alert_danger(paste("Cannot find default.R at:", default_r_path))
  cli_alert_info("Falling back to empty package list")
  r_pkgs <- character(0)
  pkgs_test <- character(0)
} else {
  cli_alert_info(paste("Loading package list from:", default_r_path))

  # Source default.R in a separate environment to avoid side effects
  temp_env <- new.env()

  tryCatch({
    # Suppress output from sourcing
    suppressMessages({
      source(default_r_path, local = temp_env)
    })

    # Extract r_pkgs and pkgs_test from the environment
    if (exists("r_pkgs", envir = temp_env)) {
      r_pkgs <- get("r_pkgs", envir = temp_env)
      cli_alert_success(paste("Loaded", length(r_pkgs), "R packages from default.R"))
    } else {
      cli_alert_warning("r_pkgs not found in default.R")
      r_pkgs <- character(0)
    }

    if (exists("pkgs_test", envir = temp_env)) {
      pkgs_test <- get("pkgs_test", envir = temp_env)
      cli_alert_success(paste("Loaded", length(pkgs_test), "core test packages from default.R"))
    } else {
      cli_alert_warning("pkgs_test not found in default.R, using defaults")
      pkgs_test <- c('usethis', 'devtools', 'gh', 'gert', 'logger', 'dplyr', 'duckdb', 'targets', 'testthat')
    }

    # Extract gh_pkgs (GitHub packages)
    if (exists("gh_pkgs", envir = temp_env)) {
      gh_pkgs_list <- get("gh_pkgs", envir = temp_env)
      # Extract package names from the list structure
      gh_pkg_names <- sapply(gh_pkgs_list, function(x) x$package_name)
      cli_alert_success(paste("Loaded", length(gh_pkg_names), "GitHub packages from default.R"))
      cli_alert_info(paste("GitHub packages:", paste(gh_pkg_names, collapse = ", ")))
    } else {
      cli_alert_warning("gh_pkgs not found in default.R")
      gh_pkg_names <- character(0)
    }

  }, error = function(e) {
    cli_alert_danger(paste("Error loading default.R:", e$message))
    cli_alert_info("Falling back to empty package list")
    r_pkgs <<- character(0)
    pkgs_test <<- c('usethis', 'devtools', 'gh', 'gert', 'logger', 'dplyr', 'duckdb', 'targets', 'testthat')
    gh_pkg_names <<- character(0)
  })
}

cli_h2("Environment Information")
cli_alert_info(paste("R version:", R.version.string))
cli_alert_info(paste("Platform:", R.version$platform))
cli_alert_info(paste("Running in Nix shell:", Sys.getenv("IN_NIX_SHELL", "not set")))

cli_h2("Library Paths")
lib_paths <- .libPaths()
for (i in seq_along(lib_paths)) {
  is_nix <- grepl("/nix/store", lib_paths[i])
  if (is_nix) {
    cli_alert_success(paste0("  [", i, "] ", lib_paths[i], " (Nix)"))
  } else {
    cli_alert_warning(paste0("  [", i, "] ", lib_paths[i], " (Non-Nix)"))
  }
}

cli_h2("Testing Core Development Packages")
results_core <- data.frame(
  package = character(),
  installed = logical(),
  loadable = logical(),
  path = character(),
  stringsAsFactors = FALSE
)

for (pkg in pkgs_test) {
  is_installed <- requireNamespace(pkg, quietly = TRUE)
  can_load <- FALSE
  pkg_path <- ""

  if (is_installed) {
    tryCatch({
      library(pkg, character.only = TRUE)
      can_load <- TRUE
      pkg_path <- find.package(pkg)
    }, error = function(e) {
      can_load <- FALSE
    })
  }

  results_core <- rbind(results_core, data.frame(
    package = pkg,
    installed = is_installed,
    loadable = can_load,
    path = pkg_path,
    stringsAsFactors = FALSE
  ))

  if (can_load) {
    is_nix <- grepl("/nix/store", pkg_path)
    if (is_nix) {
      cli_alert_success(paste(pkg, "- OK (Nix)"))
    } else {
      cli_alert_warning(paste(pkg, "- OK but NOT from Nix:", pkg_path))
    }
  } else if (is_installed) {
    cli_alert_danger(paste(pkg, "- Installed but cannot load"))
  } else {
    cli_alert_danger(paste(pkg, "- NOT installed"))
  }
}

cli_h2("Testing GitHub Packages")
results_gh <- data.frame(
  package = character(),
  installed = logical(),
  loadable = logical(),
  path = character(),
  stringsAsFactors = FALSE
)

if (length(gh_pkg_names) > 0) {
  for (pkg in gh_pkg_names) {
    is_installed <- requireNamespace(pkg, quietly = TRUE)
    can_load <- FALSE
    pkg_path <- ""

    if (is_installed) {
      tryCatch({
        library(pkg, character.only = TRUE)
        can_load <- TRUE
        pkg_path <- find.package(pkg)
      }, error = function(e) {
        can_load <- FALSE
      })
    }

    results_gh <- rbind(results_gh, data.frame(
      package = pkg,
      installed = is_installed,
      loadable = can_load,
      path = pkg_path,
      stringsAsFactors = FALSE
    ))

    if (can_load) {
      is_nix <- grepl("/nix/store", pkg_path)
      if (is_nix) {
        cli_alert_success(paste(pkg, "- OK (Nix, from GitHub)"))
      } else {
        cli_alert_warning(paste(pkg, "- OK but NOT from Nix:", pkg_path))
      }
    } else if (is_installed) {
      cli_alert_danger(paste(pkg, "- Installed but cannot load"))
    } else {
      cli_alert_danger(paste(pkg, "- NOT installed"))
    }
  }
} else {
  cli_alert_info("No GitHub packages to check")
}

cli_h2("Testing All R Packages (this may take a moment)")
results_all <- data.frame(
  package = character(),
  installed = logical(),
  loadable = logical(),
  path = character(),
  stringsAsFactors = FALSE
)

n_total <- length(r_pkgs)
n_ok <- 0
n_fail <- 0
n_missing <- 0

for (pkg in r_pkgs) {
  is_installed <- requireNamespace(pkg, quietly = TRUE)
  can_load <- FALSE
  pkg_path <- ""

  if (is_installed) {
    tryCatch({
      suppressPackageStartupMessages(library(pkg, character.only = TRUE))
      can_load <- TRUE
      pkg_path <- find.package(pkg)
      n_ok <- n_ok + 1
    }, error = function(e) {
      can_load <- FALSE
      n_fail <- n_fail + 1
    })
  } else {
    n_missing <- n_missing + 1
  }

  results_all <- rbind(results_all, data.frame(
    package = pkg,
    installed = is_installed,
    loadable = can_load,
    path = pkg_path,
    stringsAsFactors = FALSE
  ))
}

cli_h2("Summary Statistics")
cli_alert_info(paste("Total CRAN packages checked:", n_total))
cli_alert_success(paste("Successfully loadable:", n_ok, paste0("(", round(100*n_ok/n_total, 1), "%)")))
if (n_fail > 0) {
  cli_alert_warning(paste("Installed but failed to load:", n_fail))
}
if (n_missing > 0) {
  cli_alert_danger(paste("Not installed:", n_missing))
}

if (nrow(results_gh) > 0) {
  n_gh_total <- nrow(results_gh)
  n_gh_ok <- sum(results_gh$loadable)
  n_gh_fail <- sum(results_gh$installed & !results_gh$loadable)
  n_gh_missing <- sum(!results_gh$installed)

  cli_alert_info(paste("Total GitHub packages checked:", n_gh_total))
  cli_alert_success(paste("Successfully loadable:", n_gh_ok, paste0("(", round(100*n_gh_ok/n_gh_total, 1), "%)")))
  if (n_gh_fail > 0) {
    cli_alert_warning(paste("Installed but failed to load:", n_gh_fail))
  }
  if (n_gh_missing > 0) {
    cli_alert_danger(paste("Not installed:", n_gh_missing))
  }
}

# Show problematic packages
failed_pkgs <- results_all[results_all$installed & !results_all$loadable, "package"]
missing_pkgs <- results_all[!results_all$installed, "package"]
failed_gh_pkgs <- results_gh[results_gh$installed & !results_gh$loadable, "package"]
missing_gh_pkgs <- results_gh[!results_gh$installed, "package"]

if (length(failed_pkgs) > 0 || length(failed_gh_pkgs) > 0) {
  cli_h2("Packages That Failed to Load")
  if (length(failed_pkgs) > 0) {
    cli_alert_info("CRAN packages:")
    for (pkg in failed_pkgs) {
      cli_alert_danger(paste("  ", pkg))
    }
  }
  if (length(failed_gh_pkgs) > 0) {
    cli_alert_info("GitHub packages:")
    for (pkg in failed_gh_pkgs) {
      cli_alert_danger(paste("  ", pkg))
    }
  }
}

if (length(missing_pkgs) > 0 || length(missing_gh_pkgs) > 0) {
  cli_h2("Packages Not Installed")
  if (length(missing_pkgs) > 0) {
    cli_alert_info("CRAN packages:")
    for (pkg in missing_pkgs) {
      cli_alert_danger(paste("  ", pkg))
    }
  }
  if (length(missing_gh_pkgs) > 0) {
    cli_alert_info("GitHub packages:")
    for (pkg in missing_gh_pkgs) {
      cli_alert_danger(paste("  ", pkg))
    }
  }
}

# Check for non-Nix packages
non_nix_pkgs <- results_all[results_all$loadable & !grepl("/nix/store", results_all$path), ]
non_nix_gh_pkgs <- results_gh[results_gh$loadable & !grepl("/nix/store", results_gh$path), ]

if (nrow(non_nix_pkgs) > 0 || nrow(non_nix_gh_pkgs) > 0) {
  cli_h2("Warning: Packages NOT from Nix")
  cli_alert_warning("These packages loaded successfully but are not from the Nix store:")
  if (nrow(non_nix_pkgs) > 0) {
    cli_alert_info("CRAN packages:")
    for (i in seq_len(nrow(non_nix_pkgs))) {
      cli_alert_warning(paste("  ", non_nix_pkgs$package[i], "-", non_nix_pkgs$path[i]))
    }
  }
  if (nrow(non_nix_gh_pkgs) > 0) {
    cli_alert_info("GitHub packages:")
    for (i in seq_len(nrow(non_nix_gh_pkgs))) {
      cli_alert_warning(paste("  ", non_nix_gh_pkgs$package[i], "-", non_nix_gh_pkgs$path[i]))
    }
  }
}

cli_h2("Nix Store Health Check")
cli_alert_info("Checking for broken Nix store paths in PATH...")
path_dirs <- strsplit(Sys.getenv("PATH"), ":")[[1]]
nix_dirs <- path_dirs[grepl("/nix/store", path_dirs)]
broken_paths <- character()

for (nix_dir in nix_dirs) {
  if (!dir.exists(nix_dir)) {
    broken_paths <- c(broken_paths, nix_dir)
    cli_alert_danger(paste("Broken:", nix_dir))
  }
}

if (length(broken_paths) == 0) {
  cli_alert_success("All Nix store paths in PATH are valid!")
} else {
  cli_alert_danger(paste("Found", length(broken_paths), "broken Nix store paths"))
  cli_alert_info("You may need to rebuild your Nix environment")
}

cli_h2("Recommendation")
all_ok <- n_ok == n_total &&
  (nrow(results_gh) == 0 || sum(results_gh$loadable) == nrow(results_gh))
all_from_nix <- nrow(non_nix_pkgs) == 0 && nrow(non_nix_gh_pkgs) == 0
no_broken_paths <- length(broken_paths) == 0

if (all_ok && all_from_nix && no_broken_paths) {
  cli_alert_success("✓ Your Nix R environment is healthy!")
  cli_alert_success("All packages (CRAN and GitHub) are loadable from Nix store paths.")
} else {
  cli_alert_warning("⚠ Issues detected with your Nix R environment")
  if (n_missing > 0 || n_fail > 0 || (nrow(results_gh) > 0 && sum(!results_gh$loadable) > 0)) {
    cli_alert_info("Suggestion: Rebuild your Nix environment:")
    cli_alert_info("  cd /Users/johngavin/docs_gh/rix.setup")
    cli_alert_info("  ./default.sh")
  }
  if (nrow(non_nix_pkgs) > 0 || nrow(non_nix_gh_pkgs) > 0) {
    cli_alert_info("Some packages are from non-Nix locations - this may cause inconsistencies")
  }
  if (length(broken_paths) > 0) {
    cli_alert_info("Broken Nix paths detected - run nix-collect-garbage and rebuild")
  }
}

# Return exit code
if (all_ok && no_broken_paths) {
  quit(status = 0)
} else {
  quit(status = 1)
}
