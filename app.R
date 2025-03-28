# app.R


# Core UI packages
library(shiny)
library(shinyjs)
library(shinycssloaders)
library(cachem)
library(magrittr)
library(plotly)
library(httr2)  # Required for API calls

# Source configuration system
source("src/ui/config/load_config.R")

# Source components and helpers
source("src/ui/components/common/popover/popover.R")

# Source state management system
source("src/ui/state/types.R")
source("src/ui/state/store.R")
source("src/ui/state/visualization.R")
source("src/ui/state/controls.R")
source("src/ui/state/validation.R")

# Source state synchronization system
source("src/ui/components/common/display/state_sync.R")

# Source data layer components
source("src/data/cache.R")
source("src/data/unified_cache/helpers.R")
source("src/adapters/simulation_adapter.R")
source("src/adapters/intervention_adapter.R")

# Source display components
source("src/ui/components/common/display/plot_panel.R")
source("src/ui/components/common/display/table_panel.R")
source("src/ui/components/common/display/toggle.R")
source("src/ui/components/common/display/plot_controls.R")

# Source error handling
source("src/ui/components/common/errors/boundaries.R")
source("src/ui/components/common/errors/handlers.R")
source("src/ui/components/common/layout/panel.R")
source("src/ui/components/selectors/base.R")
source("src/ui/components/selectors/custom_components.R")
source("src/ui/components/selectors/choices_select.R")
source("src/ui/components/common/status/model_status.R")

source("src/ui/components/pages/prerun/layout.R")
source("src/ui/components/pages/custom/layout.R")


# Source server handlers
source("src/ui/components/pages/prerun/index.R")
source("src/ui/components/pages/custom/index.R")

# Source other required files
source("src/ui/components/common/display/display_size.R")
source("src/ui/components/common/display/handlers.R")

# Source page components
source("src/ui/components/pages/about/about.R")
source("src/ui/components/pages/about/content.R")
source("src/ui/components/pages/faq/faq.R")
source("src/ui/components/pages/faq/content.R")
source("src/ui/components/pages/team/team.R")
source("src/ui/components/pages/team/content.R")
source("src/ui/components/pages/team/member_card.R")
source("src/ui/components/pages/contact/contact.R")
source("src/ui/components/pages/contact/content.R")
source("src/ui/components/pages/contact/form.R")
source("src/ui/components/pages/overview/overview.R")
source("src/ui/components/pages/overview/content.R")

# Source download manager
source("src/ui/components/common/downloads/download_manager.R")

# Create a global download manager object that we'll initialize in server
DOWNLOAD_MANAGER <- NULL

library(jheem2)

# UI Creation
ui <- function() {
  # Load base configuration
  config <- get_base_config()

  # Default selections from config
  selected_tab <- config$application$defaults$selected_tab %||% "custom_interventions"
  app_title <- config$application$name

  tags$html(
    style = "height:100%",
    tags$title(app_title),

    # Initialize Shiny extensions
    shinyjs::useShinyjs(),

    # Load JavaScript extensions
    extendShinyjs(
      script = "js/layout/panel-controls.js",
      functions = c("ping_display_size", "ping_display_size_onload", "set_input_value")
    ),
    extendShinyjs(
      script = "js/interactions/download_plotly.js",
      functions = c("download_plotly")
    ),
    extendShinyjs(
      script = "js/interactions/sounds.js",
      functions = c("chime", "chime_if_checked")
    ),
    extendShinyjs(
      script = "js/interactions/download_progress.js",
      functions = c()
    ),

    # Load CSS files based on config
    tags$head(
    tags$link(
    rel = "stylesheet",
    type = "text/css",
    href = "css/main.css"
    ),

        # Explicitly load download progress CSS
        tags$link(
          rel = "stylesheet",
          type = "text/css",
          href = "css/components/feedback/download_progress.css"
        ),

      # Load JavaScript files
      lapply(config$theme$scripts, function(script) {
        tags$script(src = script)
      }),
      # Load our state synchronization script
      tags$script(src = "js/state/visualization-sync.js"),
      tags$link(rel = "stylesheet", href = "https://cdn.jsdelivr.net/npm/choices.js/public/assets/styles/choices.min.css"),
      tags$script(src = "https://cdn.jsdelivr.net/npm/choices.js/public/assets/scripts/choices.min.js"),
      tags$script("console.log('Dependencies loaded');"),
    ),
    tags$body(
      style = "height:100%;",
      # Add model status indicator
      create_model_status_ui(),
      # Download progress container is rendered by download_manager.R
      uiOutput("download_progress_container"),
      # Add hidden input for status tracking
      tags$input(type = "text", id = "model_status", style = "display:none;"),
      navbarPage(
        id = "main_nav",
        title = app_title,
        collapsible = FALSE,
        selected = selected_tab,

        # Overview tab
        tabPanel(
          id = "overview",
          value = "overview",
          title = "Overview",
          make_tab_popover(
            "overview",
            title = config$pages$overview$popover$title,
            content = config$pages$overview$popover$content
          ),
          create_overview_page(config)
        ),

        # Pre-run tab
        tabPanel(
          title = "Pre-Run",
          value = "prerun_interventions",
          create_prerun_layout()
        ),

        # Custom tab
        tabPanel(
          title = "Custom",
          value = "custom_interventions",
          create_custom_layout()
        ),

        # FAQ tab
        tabPanel(
          title = "FAQ",
          value = "faq",
          make_tab_popover(
            "faq",
            title = config$pages$faq$popover$title,
            content = config$pages$faq$popover$content
          ),
          create_faq_page(config)
        ),

        # About tab
        tabPanel(
          title = "About the JHEEM",
          value = "about_the_jheem",
          make_tab_popover(
            "about_the_jheem",
            title = config$pages$about$popover$title,
            content = config$pages$about$popover$content
          ),
          create_about_page(config)
        ),

        # Team tab
        tabPanel(
          title = "Our Team",
          value = "our_team",
          make_tab_popover(
            "our_team",
            title = config$pages$team$popover$title,
            content = config$pages$team$popover$content
          ),
          create_team_page(config)
        ),

        # Contact tab
        tabPanel(
          title = "Contact Us",
          value = "contact_us",
          make_tab_popover(
            "contact_us",
            title = config$pages$contact$popover$title,
            content = config$pages$contact$popover$content
          ),
          create_contact_page(config)
        )
      )
    )
  )
}

# Server function
server <- function(input, output, session) {
  # Create error boundary for model loading
  model_boundary <- create_error_boundary(
    session,
    output,
    "global",
    "model_spec",
    state_manager = get_store()
  )

  # Create model status manager
  model_status <- create_model_status_manager(session, model_boundary)

  # Make the model status functions available to other components
  session$userData$load_model_spec <- model_status$load_model_spec
  session$userData$is_model_spec_loaded <- model_status$is_loaded

  # Backward compatibility for code that might still use the old function names
  # session$userData$load_ehe_spec <- model_status$load_model_spec
  # session$userData$is_ehe_spec_loaded <- model_status$is_loaded

  # Auto-load the model specification after UI is rendered
  session$onFlushed(function() {
    message("UI rendered, auto-loading model specification...")
    model_status$load_model_spec()
  })

  # Create reactive value at server level
  plot_state <- reactiveVal(
    lapply(c("prerun", "custom"), function(x) NULL) %>%
      setNames(c("prerun", "custom"))
  )

  # Initialize caches using the cache module
  cache_config <- get_component_config("caching")
  # Initialize unified cache manager
  cache_manager <- tryCatch({
    get_cache_manager()
  }, error = function(e) {
    print(sprintf("[APP] Error initializing cache manager: %s", e$message))
    NULL
  })
  
  # Initialize download progress container UI
  output$download_progress_container <- renderUI({
    tags$div(
      id = "download-progress-container",
      class = "download-progress-container"
    )
  })
  
  # Initialize download manager immediately instead of waiting for onFlushed
  # This ensures the reactive observers are established from the beginning
  DOWNLOAD_MANAGER <<- create_download_manager(session, output)
  print("[APP] Download manager initialized during server startup")
  
  # Initialize UI Messenger for direct messaging (bypassing reactive system)
  source("src/ui/messaging/ui_messenger.R")
  UI_MESSENGER <- create_ui_messenger(session)
  session$userData$ui_messenger <- UI_MESSENGER
  print("[APP] UI messenger initialized")
  
  
  # Schedule periodic cleanup if cache manager was initialized
  if (!is.null(cache_manager)) {
    cleanup_interval <- cache_config$unified_cache$cleanup_interval_ms %||% 600000
    print(sprintf("[APP] Scheduling cache cleanup every %d ms", cleanup_interval))
  }
  
  # For backward compatibility, also initialize old caches
  initialize_caches(cache_config)

  # Initialize panel servers with reactive settings
  plot_panel_server(
    "prerun",
    settings = reactive({
      get_control_settings(input, "prerun")
    })
  )

  table_panel_server(
    "prerun",
    settings = reactive({
      get_control_settings(input, "prerun")
    })
  )

  plot_panel_server(
    "custom",
    settings = reactive({
      get_control_settings(input, "custom")
    })
  )

  table_panel_server(
    "custom",
    settings = reactive({
      get_control_settings(input, "custom")
    })
  )

  # Initialize display setup (replaces add.display.event.handlers)
  initialize_display_setup(session, input)

  # Initialize page handlers (these now handle their own display events)
  initialize_prerun_handlers(input, output, session, plot_state)
  initialize_custom_handlers(input, output, session, plot_state)

  # Initialize state synchronization for both pages
  create_visualization_sync("prerun", session)
  create_visualization_sync("custom", session)

  # Log that sync is initialized
  message("=== Visualization state sync initialized for all pages ===")

  # Initialize contact handlers using new framework-agnostic handler
  initialize_contact_handler(input, output, session)

  # Periodic cleanup of old simulations and cache
  observe({
    # Get cleanup interval from config with fallback
    cleanup_interval <- 600000 # Default: 10 minutes

    tryCatch(
      {
        cleanup_config <- get_component_config("state_management")$cleanup
        if (!is.null(cleanup_config$cleanup_interval)) {
          cleanup_interval <- cleanup_config$cleanup_interval
        }
      },
      error = function(e) {
        print(paste0("[APP] Error loading cleanup config: ", e$message, ". Using default interval."))
      }
    )

    invalidateLater(cleanup_interval)
    print("[APP] Running scheduled cleanup")
    
    # Run cleanup on unified cache manager
    print("[APP] Running unified cache cleanup")
    if (!is.null(cache_manager)) {
      tryCatch({
        cache_manager$cleanup(force = FALSE)
      }, error = function(e) {
        print(sprintf("[APP] Error in unified cache cleanup: %s", e$message))
      })
    } else {
      print("[APP] Skipping unified cache cleanup (manager not initialized)")
    }

    # For backward compatibility, also run old cleanup
    print("[APP] Running simulation cleanup")
    get_store()$cleanup_old_simulations(force = FALSE)
  })
}

# Run the application
shinyApp(ui = ui, server = server, onStart = function() {
  pkg_env <- asNamespace("jheem2")
  internal_fns <- ls(pkg_env, all.names = TRUE)

  for (fn in internal_fns) {
    if (exists(fn, pkg_env, inherits = FALSE) && is.function(get(fn, pkg_env))) {
      assign(fn, get(fn, pkg_env), envir = .GlobalEnv)
    }
  }
})
