# Display Components

## Overview
The display components handle visualization of plots and tables in the JHEEM2 web application. These components work closely with the state management system to control visibility and content updates.

## Directory Contents

### plot_panel.R
Main plot display component that:
- Manages plot visibility and rendering
- Handles loading states and errors
- Uses conditional panels for state-based display
- Key features:
  - Responsive plot sizing
  - Loading indicators
  - Error message display
  - State-based visibility control

### plot_controls.R
Handles plot control settings:
- Manages outcome selection
- Controls faceting options
- Handles summary type selection
- Default settings management
- Input validation and processing

### button_control.R
Manages display control buttons:
- Handles redraw button state
- Controls share button visibility
- Syncs button states with plot data
- Provides button enable/disable functions

### handlers.R
Event handlers for display components:
- Initializes display event handlers
- Manages run/redraw button events
- Handles display size changes
- Sets up initial display state

### toggle.R
Toggle component for plot/table switching:
- Creates plot/table toggle UI
- Manages toggle button states
- Handles toggle events
- Updates visualization state

### table_panel.R
Table display component that:
- Manages tabular data presentation
- Handles data pagination
- Coordinates with plot state
- Key features:
  - Sortable columns
  - Pagination controls
  - Export functionality

### state_sync.R
Synchronization between state and UI:
- Observes state changes from central store
- Updates toggle button CSS classes
- Sends messages to JavaScript for UI updates
- Maintains UI-state consistency

## Component Architecture

### Plot Panel Structure
```
plot_panel
├── conditional_panel (visibility control)
│   ├── plot_output
│   │   └── loading_indicator
│   └── error_message
├── plot_controls
│   ├── outcomes_selector
│   ├── facet_selector
│   └── summary_type_selector
└── display_toggle
    ├── plot_button
    └── table_button
```

### State Integration
Components use these state inputs:
- `{page_id}-visualization_state`: Controls visibility
- `{page_id}-display_type`: Switches between plot/table
- `{page_id}-plot_status`: Manages loading states

### Control Flow
1. User interacts with controls
2. Handlers process events
3. State updates trigger conditional panels
4. Display components update accordingly

### Default Handling
The control settings system uses a specific hierarchy for defaults:
1. Direct config defaults (`controls$outcomes$defaults`)
2. User-selected values from inputs
3. Fallback to config-specified defaults

Important: Always use explicit defaults from config rather than deriving them from options.
Example:
```r
# Correct:
controls$outcomes$defaults

# Incorrect - may select wrong options:
sapply(head(controls$outcomes$options, 2), `[[`, "id")
```

## Usage Example

```r
# UI Definition
create_plot_panel(id = "custom", type = "static")

# Server Logic
plot_panel_server(
  id = "custom",
  data = reactive({ ... }),
  settings = reactive({ ... })
)

# Control Settings
get_control_settings(input, "custom")

# Button State Management
sync_buttons_to_plot(input, plot_data)
```

## Important Notes
- Always use full prefixed IDs for state inputs
- Handle loading states appropriately
- Manage error states and messages
- Coordinate plot/table transitions
- Ensure proper event handler initialization
- Maintain button state synchronization

## Data Access Patterns
Components now use simulation state:

### Plot Panel
- Gets raw simset from simulation state
- Uses simplot for visualization
- Direct use of JHEEM2 simulation objects
- Example:
```r
sim_state <- store$get_current_simulation_data(id)
plot <- simplot(
    sim_state$simset,
    outcomes = settings$outcomes,
    ...
)
```

### Table Panel
- Uses transformed data from simulation state
- Handles pagination locally
- Format and display logic separated
- Example:
```r
transformed_data <- store$get_current_transformed_data(id, settings)
formatted <- format_table_data(transformed_data, config)
```

### State Integration
- Components check simulation state
- Use store methods for data access
- Maintain view synchronization
- Handle state transitions properly

## Cross-Page Button State Management

An important fix was implemented in the button state management system to prevent cross-page interference.

### The Issue

Previously, when generating projections on one page, the toggle buttons on other pages would become disabled because:

1. The `sync_buttons_to_plot` function would process a list of pages that included both the active page and inactive pages
2. For inactive pages where data wasn't available, it would disable the toggle buttons
3. This created a confusing user experience where buttons became unusable

### The Fix

The `sync_buttons_to_plot` function in `button_control.R` was modified to:

- Only enable buttons when data is available for a page
- Never disable buttons for other pages that don't currently have data

```r
# Modified function in button_control.R
for (suffix in names(plot_and_table_list)) {
    # Only process pages where data exists - NEVER disable other pages
    if (!is.null(plot_and_table_list[[suffix]])) {
        set_redraw_button_enabled(input, suffix, TRUE)
        set_share_button_enabled(input, suffix, TRUE)
    } else {
        # Skip disabling buttons for pages that don't have data
        print(paste("Skipping button updates for inactive page:", suffix))
    }
}
```

This ensures that generating plots on one page never interferes with the toggle buttons on another page, maintaining proper page isolation.

### Panel Specific Classes

The visualization panels now include page-specific CSS classes for more reliable element selection:

```r
tags$div(
  class = paste0("main-panel main-panel-plot ", id, "-plot-panel"),
  ...
)
```

This improves the targeting of JavaScript operations and helps maintain proper page independence.
