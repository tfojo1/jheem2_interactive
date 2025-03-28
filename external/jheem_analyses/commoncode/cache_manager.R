# Deployment version of cache_manager.R
# This is a modified version of the original cache_manager.R specifically for deployment
# on shinyapps.io. It has fixed paths and more resilient error handling.

## DEPLOYMENT MODIFICATION: Set fixed paths for deployment
## These replace the dynamic path detection in the original file
JHEEM.CACHE.DIR <- "external/jheem_analyses/cached"
DATA.MANAGER.CACHE.METADATA.FILE <- "external/jheem_analyses/commoncode/data_manager_cache_metadata.Rdata"
PACKAGE.VERSION.CACHE.FILE <- "external/jheem_analyses/commoncode/package_version_cache.Rdata"

## PUBLIC INTERFACES

## DEPLOYMENT MODIFICATION: Comment out automatic installation of httr2
## This would fail on shinyapps.io due to no CRAN mirror being set
# if (nchar(system.file(package = "httr2")) == 0) {
#     install.packages("httr2")
# }

## This function will get the latest version of jheem2.
## If "refresh.cache" is TRUE, and there's a new version, it will be installed
## If "refresh.cache" is FALSE (the default), and there's a new version, you'll be told to refresh your cache
get.latest.jheem <- function(method=c('curl', 'shell'), verbose=T, refresh.cache=F) {
    method <- match.arg(method)

    cdata <- get.cache.data(verbose=FALSE)
    pkgs <- list(PACKAGE.VERSION.CACHE.FILE)
    names(pkgs) <- c('jheem2')

    response <- paste0("jheem2 version ", as.character(packageVersion('jheem2')))

    pkgs <- lapply(pkgs, function(pkg) tryCatch(get(load(pkg)), error=function(e) NULL))
    out.of.date <- ifelse(
        'jheem2' %in% names(pkgs) && !is.null(pkgs[['jheem2']]) && 'jheem2' %in% names(pkgs[['jheem2']]),
        packageVersion('jheem2') < pkgs[['jheem2']][['jheem2']],
        FALSE)

    if (verbose) {
        if (out.of.date) {
            cat("Your installed version, ", as.character(packageVersion('jheem2')), ", is older than the version in the cache, ", as.character(pkgs[['jheem2']][['jheem2']]), ". ")
        } else if (is.null(pkgs[['jheem2']]) || !('jheem2' %in% names(pkgs[['jheem2']])) || is.na(pkgs[['jheem2']][['jheem2']])) {
            cat("No version info for jheem2 in cache. ")
        } else {
            cat("Your installed version, ", as.character(packageVersion('jheem2')), ", is up to date with the cache. ")
        }
    }

    if (out.of.date) {
        if (refresh.cache) {
            message("Refreshing jheem2 from GitHub.")
            tryCatch({
                remotes::install_github('tfojo1/jheem2')
                NULL
            }, error=function(e) {
                message("Failed to install jheem2: ", e$message)
                e
            })
        } else if (verbose) {
            cat("Run this to get the latest:\n\ndevtools::install_github('tfojo1/jheem2')\n")
        }
    } else if (verbose) {
        cat("Your jheem2 package is current.")
    }

    invisible(response)
}

# DEPLOYMENT MODIFICATION: More robust error handling for metadata access
get.data.manager.cache.metadata <- function(pretty.print=TRUE, error.prefix="") {
  # Resilient version that handles missing files
  if (!file.exists(DATA.MANAGER.CACHE.METADATA.FILE)) {
    warning(paste0(error.prefix, "The metadata file is missing. Creating an empty one."))
    data.manager.cache.metadata <- list()
  } else {
    tryCatch({
      data.manager.cache.metadata <- get(load(DATA.MANAGER.CACHE.METADATA.FILE))
    }, error = function(e) {
      warning(paste0(error.prefix, "Could not load metadata file. Error: ", e$message, ". Creating an empty one."))
      data.manager.cache.metadata <- list()
    })
  }
  
  if (pretty.print) {
    if (length(data.manager.cache.metadata) == 0) {
      cat("Using empty metadata (no cached data managers available)\n")
    } else {
      cat("Local copies of each data manager must be last modified by these dates or later:\n")
      for (data.manager in names(data.manager.cache.metadata)) {
        cat(data.manager, "-", format(data.manager.cache.metadata[[data.manager]][["last.modified.date"]], usetz = T),"\n")
      }
    }
  }
  invisible(data.manager.cache.metadata)
}

# DEPLOYMENT MODIFICATION: More robust package version checking
is.package.out.of.date <- function(package="jheem2", verbose=FALSE) {
  error.prefix <- "Cannot check if package is out of date: "
  if (!is.character(package) || length(package)!=1 || is.na(package))
    stop(paste0(error.prefix, "'package' must be a single character value. Defaults to 'jheem2'"))
  if (!is.logical(verbose) || length(verbose)!=1 || is.na(verbose))
    stop(paste0(error.prefix, "'verbose' must be TRUE or FALSE"))
  if (nchar(system.file(package = package)) == 0)
    stop(paste0(error.prefix, "package '", package, "' is not installed. Install it with 'remotes::install_github(\"tfojo1/", package, "\")'"))
  
  # Try to load the package version file, but handle errors gracefully
  if (!file.exists(PACKAGE.VERSION.CACHE.FILE)) {
    warning(paste0(error.prefix, "The package version file could not be found. Assuming package is up to date."))
    return(FALSE)
  }
  
  # Load with error handling
  tryCatch({
    cache_file <- get(load(PACKAGE.VERSION.CACHE.FILE))
    if (!(package %in% names(cache_file))) {
      if (verbose)
        cat(paste0("No version requirement found for package '", package, "'. Assuming it's up to date.\n"))
      return(FALSE)
    }
    if (verbose)
      print(paste0("The version for package '", package, "' must be >= ", cache_file[[package]], "; installed version is ", as.character(packageVersion(package)), "."))
    return(packageVersion(package) < cache_file[[package]])
  }, error = function(e) {
    warning(paste0(error.prefix, "Failed to load package version cache: ", e$message, ". Assuming package is up to date."))
    return(FALSE)
  })
}

# DEPLOYMENT MODIFICATION: More robust cache data access
get.cache.data <- function(verbose=T) {
    if (!dir.exists(JHEEM.CACHE.DIR)) {
        warning("Cannot find the cached directory in the deployment folder. Some functionality may be limited.")
        return(list())
    }
    
    metadata <- get.data.manager.cache.metadata(pretty.print=verbose)
    invisible(list(
        metadata=metadata
    ))
}

## This is a function to update the version number for a specific package
## If `version` is NULL, the package's current version is used
update.package.version.cache <- function(package="jheem2", version=NULL, pretty.print=T) {
    error.prefix <- "Cannot update package version: "
    path <- PACKAGE.VERSION.CACHE.FILE
    if (!is.character(package) || length(package)!=1 || is.na(package))
        stop(paste0(error.prefix, "'package' must be a single character value. Defaults to 'jheem2'"))
    if (nchar(system.file(package = package)) == 0)
        stop(paste0(error.prefix, "package '", package, "' is not installed. Install it with 'remotes::install_github(\"tfojo1/", package, "\")'"))

    if (is.null(version)) {
        version <- packageVersion(package)
    } else if (inherits(version, 'numeric_version')) {
        # good to proceed
    } else if (is.character(version) && length(version) == 1 && !is.na(version)) {
        version = package_version(version)
    } else {
        stop(paste0(error.prefix, "'version' must be a package_version, or a string that can be converted to one."))
    }
    
    dir_path <- dirname(path)
    if (!dir.exists(dir_path)) {
        dir.create(dir_path, recursive=TRUE)
    }
    
    if (file.exists(path)) {
        tryCatch({
            cache_file <- get(load(path))
        }, error = function(e) {
            warning(paste0(error.prefix, "Failed to load cache. Starting fresh. Error: ", e$message))
            cache_file <- list()
        })
    } else {
        cache_file <- list()
    }
    
    cache_file[[package]] <- version
    save(cache_file, file=path)
    
    if (pretty.print)
        cat("Version cache updated: ", package, " version ", version, "\n")
    
    invisible(version)
}

# DEPLOYMENT MODIFICATION: More robust cache existence check
refresh.cache.folder <- function(verbose=T) {
    if (!dir.exists(JHEEM.CACHE.DIR)) {
        warning("Cannot find the cached directory. Creating an empty one.")
        dir.create(JHEEM.CACHE.DIR, recursive = TRUE)
    }
    
    invisible(JHEEM.CACHE.DIR)
}

# DEPLOYMENT MODIFICATION: Added load.data.manager.from.cache function
# This is a simplified version that works with local files only for deployment
load.data.manager.from.cache <- function(file, set.as.default = FALSE, offline = TRUE) {
  error.prefix <- "Cannot load.data.manager.from.cache(): "
  
  # Get metadata with error handling
  cache.metadata <- get.data.manager.cache.metadata(pretty.print = FALSE)
  
  # Check if file is in metadata (but only warn, don't stop)
  if (!(file %in% names(cache.metadata))) {
    warning(paste0(error.prefix, "'", file, "' is not one of our cached files."))
  }
  
  # Try to load the file if it exists
  file_path <- file.path(JHEEM.CACHE.DIR, file)
  if (!file.exists(file_path)) {
    warning(paste0(error.prefix, "File not found in deployment cache: ", file_path))
    return(NULL)
  }
  
  # Load the data manager with error handling
  tryCatch({
    # Assuming load.data.manager is from the jheem2 package
    loaded.data.manager <- load.data.manager(file_path, set.as.default = set.as.default)
    return(loaded.data.manager)
  }, error = function(e) {
    warning(paste0(error.prefix, "Error loading data manager: ", e$message))
    return(NULL)
  })
}

# DEPLOYMENT MODIFICATION: Added is.cached.data.manager.out.of.date function
# This is a simplified version for deployment that always returns FALSE
is.cached.data.manager.out.of.date <- function(file, data.manager, error.prefix = "") {
  # In deployment environment, we'll assume files are up-to-date
  # This avoids triggering OneDrive download attempts
  return(FALSE)
}

# DEPLOYMENT MODIFICATION: Added download.data.manager.from.onedrive function
# This is a stub function for deployment that logs a warning and does nothing
download.data.manager.from.onedrive <- function(destination.file, onedrive.link, error.prefix = "", verbose = FALSE) {
  warning(paste0(error.prefix, "OneDrive downloads are not supported in the deployment environment."))
  # Return FALSE to indicate download was not performed
  return(FALSE)
}
