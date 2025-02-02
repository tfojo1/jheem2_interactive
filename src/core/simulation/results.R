#' Transform simulation data for visualization
#' @param simset jheem simulation set object
#' @param settings list with:
#'   outcomes - character vector of outcomes to include
#'   facet.by - character vector of dimensions to facet by (or NULL)
#'   summary.type - type of summary to calculate
#' @return Transformed data structure
transform_simulation_data <- function(simset, settings) {
    print("Starting data transformation")
    print("Settings:")
    str(settings)

    # Add debug logging
    print("Debug information:")
    print("Available outcomes in simset:")
    print(simset$outcomes)
    print("EHE.SPECIFICATION exists:")
    print(exists("EHE.SPECIFICATION"))
    print("Available ontologies:")
    print(ls(pattern = "ONTOLOGY"))

    if (is.null(settings$outcomes)) {
        stop("outcomes must be specified in settings")
    }

    # Get raw plot data using prepare.plot
    plot_data <- prepare.plot(
        simset.list = list(simset = simset),
        outcomes = settings$outcomes,
        facet.by = settings$facet.by,
        summary.type = settings$summary.type
    )

    # Structure the result to match expected format
    result <- list(
        plot = plot_data
    )

    print("Transformed data structure:")
    str(result)

    return(result)
}

#' Get data prepared for plot display
#' @param simset jheem simulation set object
#' @param settings list of display settings
#' @return Raw simulation set for plot display
get_plot_data <- function(simset, settings) {
    simset
}
