library(yaml)

#' Load YAML configuration file
#' @param path Path to YAML file
#' @return List containing configuration
load_yaml_file <- function(path) {
    # Debug print
    print(paste("Attempting to load:", path))

    # Check if file exists
    if (!isTRUE(file.exists(path))) {
        stop(sprintf("Configuration file not found: %s", path))
    }

    # Load and parse YAML
    tryCatch(
        {
            yaml::read_yaml(path)
        },
        error = function(e) {
            stop(sprintf("Error reading YAML file %s: %s", path, e$message))
        }
    )
}

#' Get base configuration
#' @return List containing base configuration
get_base_config <- function() {
    load_yaml_file("src/ui/config/base.yaml")
}

#' Get configuration for a specific component
#' @param component Name of the component
#' @return List containing component configuration
get_component_config <- function(component) {
    path <- file.path("src", "ui", "config", "components", paste0(component, ".yaml"))

    load_yaml_file(path)
}

#' Get default configuration
#' @return List containing default configuration
get_defaults_config <- function() {
    load_yaml_file("src/ui/config/defaults.yaml")
}

#' Get configuration for a specific page
#' @param page Name of the page
#' @return List containing page configuration
get_page_config <- function(page) {
    # Debug print
    print(paste("Loading config for page:", page))

    path <- file.path("src", "ui", "config", "pages", paste0(page, ".yaml"))
    if (!file.exists(path)) {
        stop(sprintf("Configuration file not found for page: %s", page))
    }

    load_yaml_file(path)
}

#' Get complete configuration for a page
#' @param page Name of the page
#' @return List containing complete configuration
get_page_complete_config <- function(page) {
    # Load all configurations
    base_config <- get_base_config()
    defaults_config <- get_defaults_config()
    page_config <- get_page_config(page)

    # Load component configs
    controls_config <- get_component_config("controls")

    # Merge configurations
    config <- merge_configs(base_config, defaults_config)
    config <- merge_configs(config, controls_config)
    config <- merge_configs(config, page_config)

    # Add page type
    config$page_type <- page

    # Validate the merged configuration
    validate_config(config)

    config
}

#' Merge configurations recursively
#' @param base Base configuration
#' @param override Configuration to merge on top
#' @return Merged configuration
merge_configs <- function(base, override) {
    if (is.null(override)) {
        return(base)
    }
    if (is.null(base)) {
        return(override)
    }

    if (!is.list(base) || !is.list(override)) {
        return(override)
    }

    merged <- base
    for (name in names(override)) {
        if (name %in% names(base) && is.list(base[[name]]) && is.list(override[[name]])) {
            merged[[name]] <- merge_configs(base[[name]], override[[name]])
        } else {
            merged[[name]] <- override[[name]]
        }
    }
    merged
}

#' Helper function to access nested configuration safely
#' @param config Configuration list
#' @param path Path to desired configuration (character vector)
#' @param default Default value if path not found
#' @return Configuration value or default
get_config_value <- function(config, path, default = NULL) {
    result <- config
    for (key in path) {
        if (!is.list(result) || is.null(result[[key]])) {
            return(default)
        }
        result <- result[[key]]
    }
    result
}

#' Format configuration value based on type
#' @param value Configuration value
#' @param type Expected type
#' @return Formatted value
format_config_value <- function(value, type) {
    switch(type,
        "numeric" = as.numeric(value),
        "logical" = as.logical(value),
        "character" = as.character(value),
        value
    )
}

#' Validate configuration structure
#' @param config Configuration to validate
#' @return TRUE if valid, throws error if invalid
validate_config <- function(config) {
    # Required sections for all configurations
    required <- c(
        "application",
        "theme",
        "defaults",
        "panels",
        "selectors"
    )

    # Check required sections
    missing <- setdiff(required, names(config))
    if (length(missing) > 0) {
        stop(sprintf(
            "Missing required configuration sections: %s",
            paste(missing, collapse = ", ")
        ))
    }

    # Page-specific validation based on page type
    if (!is.null(config$page_type)) {
        validate_page_config(config, config$page_type)
    }

    # Validate input types if present
    if (!is.null(config$input_types)) {
        for (type_name in names(config$input_types)) {
            type_config <- config$input_types[[type_name]]
            required_type_fields <- c("default_style", "multiple")
            missing <- setdiff(required_type_fields, names(type_config))
            if (length(missing) > 0) {
                stop(sprintf(
                    "Missing required fields for input type %s: %s",
                    type_name,
                    paste(missing, collapse = ", ")
                ))
            }
        }
    }

    TRUE
}

#' Validate page-specific configuration
#' @param config Configuration to validate
#' @param page Page type
#' @return TRUE if valid, throws error if invalid
validate_page_config <- function(config, page) {
    # Basic validation of config structure
    if (!is.list(config)) {
        stop("Configuration must be a list")
    }
    TRUE
}

#' Get configuration for a specific selector
#' @param selector_id Selector identifier
#' @param page_type Page type ("prerun" or "custom")
#' @param group_num Optional group number for custom page
#' @return Selector configuration
get_selector_config <- function(selector_id, page_type, group_num = NULL) {
    # Debug print
    print(paste("Getting config for selector:", selector_id))
    print(paste("Page type:", page_type))
    print(paste("Group num:", group_num))

    # Validate inputs
    if (!is.character(page_type) || length(page_type) != 1) {
        stop("page_type must be a single character string")
    }
    if (!is.character(selector_id) || length(selector_id) != 1) {
        stop("selector_id must be a single character string")
    }
    if (!is.null(group_num) && (!is.numeric(group_num) || length(group_num) != 1)) {
        stop("group_num must be NULL or a single number")
    }

    # Load complete configuration for the page
    config <- get_page_complete_config(page_type)

    # Get input type defaults
    input_types <- config$input_types %||% list()

    # Get base selector configuration based on context
    selector_config <- if (page_type == "custom" && !is.null(group_num)) {
        if (selector_id %in% c("age_groups", "race_ethnicity", "biological_sex", "risk_factor")) {
            # Demographics selectors
            config$demographics[[selector_id]]
        } else if (selector_id == "intervention_dates") {
            # Date selector
            config$interventions$dates
        } else if (selector_id %in% names(config$interventions$components)) {
            # Any intervention component from the config
            config$interventions$components[[selector_id]]
        } else {
            # Standard selectors
            config$selectors[[selector_id]]
        }
    } else {
        config$selectors[[selector_id]]
    }

    if (is.null(selector_config)) {
        # Debug print of available configurations
        print("Available configurations:")
        print("Demographics:")
        print(names(config$demographics))
        print("Intervention components:")
        print(names(config$interventions$components))
        print("Selectors:")
        print(names(config$selectors))
        stop(sprintf("No configuration found for selector: %s", selector_id))
    }

    # Merge with input type defaults if applicable
    if (!is.null(selector_config$type) && !is.null(input_types[[selector_config$type]])) {
        type_defaults <- input_types[[selector_config$type]]
        selector_config$input_style <- selector_config$input_style %||% type_defaults$default_style
        selector_config$multiple <- selector_config$multiple %||% type_defaults$multiple
    }

    # Generate ID with group number if provided
    id <- if (!is.null(group_num)) {
        paste("int", selector_id, group_num, page_type, sep = "_")
    } else {
        paste("int", selector_id, page_type, sep = "_")
    }

    # Add generated ID to config
    selector_config$id <- id

    selector_config
}

#' Get model dimension mapping
#' @param dimension Dimension name (age, sex, risk, race)
#' @param ui_value UI value to map
#' @return Model value
get_model_dimension_value <- function(dimension, ui_value) {
    config <- get_defaults_config()
    mappings <- config$model_dimensions[[dimension]]$mappings

    if (is.null(mappings[[ui_value]])) {
        stop(sprintf("No mapping found for %s value: %s", dimension, ui_value))
    }

    mappings[[ui_value]]
}

#' Source the model specification file from appropriate location
#' @return NULL invisibly
source_model_specification <- function() {
  # Get model specification config from base config
  base_config <- get_base_config()
  model_config <- base_config$model_specification
  
  if (is.null(model_config)) {
    stop("Model specification configuration not found in base.yaml")
  }
  
  # Get file paths from config
  main_file <- model_config$main_file
  dev_path <- model_config$development_path
  deploy_path <- model_config$deployment_path
  model_name <- model_config$name
  
  # Construct full paths
  external_path <- file.path(dev_path, main_file)
  internal_path <- file.path(deploy_path, main_file)
  
  # Try to source the file
  if (file.exists(external_path)) {
    message(paste0("Sourcing ", model_name, " specification from development path"))
    source(external_path)
  } else if (file.exists(internal_path)) {
    message(paste0("Sourcing ", model_name, " specification from deployment path"))
    source(internal_path)
  } else {
    stop(paste0(model_name, " specification file not found in either location: ", 
               external_path, " or ", internal_path))
  }
  
  invisible(NULL)
}