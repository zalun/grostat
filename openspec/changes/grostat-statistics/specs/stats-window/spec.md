## ADDED Requirements

### Requirement: Statistics window opens from popover
The popover SHALL include a "Statistics..." button that opens the statistics window.

#### Scenario: Open statistics window
- **WHEN** user clicks "Statistics..." button in the popover
- **THEN** the statistics window opens and the popover closes

#### Scenario: Window already open
- **WHEN** user clicks "Statistics..." and the statistics window is already open
- **THEN** the existing window is brought to front (not a second window)

### Requirement: Singleton window lifecycle
The statistics window SHALL be a singleton NSWindow managed by AppDelegate.

#### Scenario: Only one instance exists
- **WHEN** the statistics window is opened multiple times
- **THEN** only one NSWindow instance is ever created

#### Scenario: Window closes normally
- **WHEN** user closes the statistics window (close button or Cmd+W)
- **THEN** the window hides but the instance is retained for reuse

### Requirement: Window hosts SwiftUI content
The statistics window SHALL use NSHostingController to embed SwiftUI views.

#### Scenario: SwiftUI view displayed
- **WHEN** the statistics window opens
- **THEN** SwiftUI chart views are rendered inside the window via NSHostingController

### Requirement: Window has appropriate size and title
The statistics window SHALL have a reasonable default size and the title "Statistics".

#### Scenario: Default window appearance
- **WHEN** the statistics window opens for the first time
- **THEN** the window title is "Statistics", the window is resizable, and has a minimum size that fits two charts side by side
