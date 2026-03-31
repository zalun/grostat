## ADDED Requirements

### Requirement: Two independent charts displayed side by side
The statistics window SHALL display exactly two charts side by side, each with its own metric selector.

#### Scenario: Default chart layout
- **WHEN** the statistics window opens
- **THEN** two charts are rendered side by side, each showing its persisted metric selection

### Requirement: Each chart has a metric dropdown
Each chart SHALL have a dropdown to select which metric to display.

#### Scenario: Available metrics
- **WHEN** user opens a chart's metric dropdown
- **THEN** the options are: Energy (kWh), Power DC (kW), Power AC (kW), Voltage Vmax (V), Temperature (°C), Power per String

#### Scenario: Change metric
- **WHEN** user selects a different metric from the dropdown
- **THEN** the chart re-renders with data for the newly selected metric

### Requirement: Metric selection persisted
Each chart's selected metric SHALL be persisted in UserDefaults.

#### Scenario: Reopen statistics window
- **WHEN** user closes and reopens the statistics window
- **THEN** both charts show the same metrics that were selected before closing

#### Scenario: App restart
- **WHEN** the app is restarted
- **THEN** both charts show the same metrics that were selected in the previous session

### Requirement: Primary period shown as solid line with area fill
The primary period data SHALL be rendered as a solid line in solar gold with a 10% opacity area fill beneath.

#### Scenario: Primary line rendering
- **WHEN** a chart displays data
- **THEN** the primary period is a solid catmullRom-interpolated line in solar gold with an area fill at ~10% opacity

### Requirement: Comparison period shown as dashed line
The comparison period data SHALL be rendered as a dashed line in cool blue.

#### Scenario: Comparison line rendering
- **WHEN** a chart displays comparison data
- **THEN** the comparison period is a dashed catmullRom-interpolated line in cool blue, without area fill

### Requirement: Hover tooltip shows both period values
Hovering on a chart SHALL display a vertical rule and tooltip with values from both periods.

#### Scenario: Hover over data point
- **WHEN** user hovers over a chart at a given x-position
- **THEN** a vertical rule line appears, and a tooltip shows the primary and comparison values at that point

#### Scenario: Hover where only one period has data
- **WHEN** user hovers at a point where only the primary period has data (comparison has a gap)
- **THEN** the tooltip shows the primary value and indicates no comparison data

### Requirement: Power per String shows two lines
When the "Power per String" metric is selected, the chart SHALL show ppv1 and ppv2 as two distinct lines instead of primary/comparison overlay.

#### Scenario: Power per String display
- **WHEN** user selects "Power per String" metric
- **THEN** the chart shows ppv1 and ppv2 as two separate lines (no comparison overlay for this metric)

### Requirement: Charts follow design system
Charts SHALL follow the visual style defined in .impeccable.md.

#### Scenario: Visual styling
- **WHEN** charts are rendered
- **THEN** they use catmullRom interpolation, subtle grid lines, minimal axis labels, monospaced digits for values, and generous padding
