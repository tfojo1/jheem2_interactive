# src/ui/components/pages/prerun/handlers/initialize.R

#' Initialize handlers for prerun page
#' @param input Shiny session object
#' @param output Shiny output object
#' @param session Shiny session object
#' @param plot_state Reactive value for plot state
initialize_prerun_handlers <- function(input, output, session, plot_state) {
    ns <- session$ns

    # Get configuration
    config <- get_page_complete_config("prerun")

    # Create managers
    vis_manager <- create_visualization_manager(session, "prerun", ns("visualization"))

    # Initialize handlers
    initialize_prerun_visualization_handlers(input, output, session, vis_manager)

    # Create managers
    validation_manager <- create_validation_manager(session, "prerun", ns("validation"))

    # Store validation manager in session for access by other functions
    session$userData$validation_manager <- validation_manager

    # Initialize display handlers
    initialize_display_handlers(session, input, output, vis_manager, "prerun")
    initialize_display_setup(session, input)

    # initialize_intervention_handlers(input, output, session, validation_manager, config)

    # Validate location selection
    validation_boundary <- create_validation_boundary(
        session,
        output,
        "prerun",
        "location_validation",
        validation_manager = validation_manager
    )

    # Reset downstream selections when location changes
    observeEvent(input$int_location_prerun, {
        print(paste("Location selected:", input$int_location_prerun))

        validation_boundary$validate(
            input$int_location_prerun,
            list(
                validation_boundary$rules$required("Please select a location"),
                validation_boundary$rules$custom(
                    test_fn = function(value) !is.null(value) && value != "none",
                    message = "Please select a location"
                )
            ),
            field_id = "int_location_prerun"
        )

        if (input$int_location_prerun == "none") {
            updateRadioButtons(session, "int_aspect_prerun", selected = "none")
        }
    })

    # Handle generate button
    observeEvent(input$generate_projections_prerun, {
        print("[PRERUN] === Generate Button Event ===")

        # Check all validations
        print("[PRERUN] 1. Checking validations...")
        validation_results <- validation_manager$is_valid()

        if (validation_results) {
            print("[PRERUN] 2. Collecting settings...")
            settings <- collect_prerun_settings(input)
            print("[PRERUN] Settings collected:")
            str(settings)

            print("[PRERUN] 3. Updating visibility...")
            vis_manager$set_visibility("visible")

            print("[PRERUN] 4. Calling update_display...")
            vis_manager$update_display(input, output, settings)
        } else {
            showNotification(
                "Please select a location and intervention settings first",
                type = "warning"
            )
        }
    })
}

#' Collect settings for prerun page
#' @param input Shiny input object
#' @return List of settings
collect_prerun_settings <- function(input) {
    print("Collecting prerun settings:")
    settings <- list(
        location = isolate(input$int_location_prerun),
        aspect = isolate(input$int_intervention_aspects_prerun),
        population = isolate(input$int_population_groups_prerun),
        timeframe = isolate(input$int_timeframes_prerun),
        intensity = isolate(input$int_intensities_prerun)
    )
    print("Settings collected:")
    print(settings)
    settings
}
