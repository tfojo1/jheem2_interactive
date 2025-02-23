#' Format table data for display
#' @param transformed_data Output from transform_simulation_data
#' @param config Configuration list from get_defaults_config
#' @return Formatted data frame for table display
format_table_data <- function(transformed_data, config) {
    if (is.null(transformed_data) || is.null(transformed_data$plot)) {
        return(data.frame())
    }

    # Extract components
    df.sim <- transformed_data$plot$df.sim
    df.truth <- transformed_data$plot$df.truth
    is_summary <- "value.mean" %in% names(df.sim)

    # Helper for number formatting
    format_number <- function(x) {
        ifelse(is.na(x), "NA",
            ifelse(x >= 100, as.character(round(x)),
                as.character(round(x, 1))
            )
        )
    }

    # Save current options and ensure they're restored
    old_digits <- getOption("digits")
    on.exit(options(digits = old_digits))
    options(digits = 7)

    # Create base data frame
    sim_data <- data.frame(
        Year = df.sim$year,
        Outcome = df.sim$outcome.display.name,
        Source = rep("Projected", nrow(df.sim)),
        stringsAsFactors = FALSE
    )

    # Add values based on mode
    if (is_summary) {
        sim_data$Value <- paste0(
            format_number(df.sim$value.mean), " (",
            format_number(df.sim$value.lower), "-",
            format_number(df.sim$value.upper), ")"
        )
    } else {
        sim_data$Value <- format_number(df.sim$value)
        if ("sim" %in% names(df.sim)) {
            sim_data$Simulation <- as.numeric(as.character(df.sim$sim))
        }
    }

    # Add dimension columns
    dimension_ids <- sapply(config$plot_controls$stratification$options, function(x) x$id)
    direct_dims <- intersect(names(df.sim), dimension_ids)
    facet_cols <- grep("^facet\\.by\\d+$", names(df.sim), value = TRUE)

    if (length(direct_dims) > 0) {
        for (col in direct_dims) {
            sim_data[[col]] <- df.sim[[col]]
        }
    } else if (length(facet_cols) > 0) {
        for (i in seq_along(facet_cols)) {
            col_name <- paste0("Category", i)
            sim_data[[col_name]] <- df.sim[[facet_cols[i]]]
        }
    }

    # Get column order from config
    ordered_cols <- character(0)
    for (col in config$table_structure$display_order) {
        if (col == "dimensions") {
            dim_cols <- setdiff(
                names(sim_data),
                sapply(config$table_structure$base_columns, function(x) x$id)
            )
            ordered_cols <- c(ordered_cols, dim_cols)
        } else if (col %in% names(sim_data)) {
            ordered_cols <- c(ordered_cols, col)
        }
    }

    # Return data frame with columns in configured order
    sim_data[, ordered_cols]
}

#' Get data prepared for table display with optional pagination
#' @param simset jheem simulation set object
#' @param settings list of display settings
#' @param pagination optional list with page and page_size
#' @return Formatted data frame or paginated data structure
get_table_data <- function(simset, settings, pagination = NULL) {
    # Get transformed data as before
    transformed <- transform_simulation_data(simset, settings)
    formatted <- format_table_data(transformed, get_component_config("controls"))

    # If no pagination requested, return data frame as before
    if (is.null(pagination)) {
        return(transformed) # Keep original behavior
    }

    # Apply pagination
    total_rows <- nrow(formatted)
    start_idx <- ((pagination$page - 1) * pagination$page_size) + 1
    end_idx <- min(start_idx + pagination$page_size - 1, total_rows)

    # Return paginated structure
    list(
        data = formatted[start_idx:end_idx, , drop = FALSE],
        metadata = list(
            total_rows = total_rows,
            current_page = pagination$page,
            has_more = end_idx < total_rows
        )
    )
}
