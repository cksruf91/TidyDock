# Repository Guidelines

## Project Structure & Module Organization
- `TidyDock/` contains the SwiftUI application source (entry point in `TidyDock/TidyDockApp.swift`, UI in `TidyDock/ContentView.swift`).
- `Assets.xcassets/` under `TidyDock/` stores images and app assets.
- `TidyDockTests/` holds unit tests (XCTest).
- `TidyDockUITests/` holds UI tests (XCUITest).
- Xcode project: `TidyDock.xcodeproj`.

## Build, Test, and Development Commands
- Open in Xcode: `open TidyDock.xcodeproj` (recommended for running/debugging).
- Build from CLI (requires full Xcode):
  - `xcodebuild -project TidyDock.xcodeproj -scheme TidyDock -configuration Debug build`
- Run unit tests (requires full Xcode):
  - `xcodebuild -project TidyDock.xcodeproj -scheme TidyDock -configuration Debug test`
- Run UI tests (requires full Xcode):
  - `xcodebuild -project TidyDock.xcodeproj -scheme TidyDock -configuration Debug -destination 'platform=macOS' test`

## Coding Style & Naming Conventions
- Swift standard style: 4-space indentation, trailing commas only when needed.
- Naming: `UpperCamelCase` for types, `lowerCamelCase` for variables/functions, `camelCase` for file-local identifiers.
- SwiftUI views are `struct` types conforming to `View`.
- Keep files small and focused (one primary view or model per file).

## Testing Guidelines
- Frameworks: XCTest for unit tests, XCUITest for UI tests.
- Test names should describe behavior (e.g., `testContainerListLoads()`), and belong in `TidyDockTests/` or `TidyDockUITests/` accordingly.
- Run tests via Xcode Test action or the `xcodebuild` commands above.

## Commit & Pull Request Guidelines
- Commit history is minimal and does not indicate a formal convention. Use short, imperative summaries (e.g., "Add container list view").
- PRs should include:
  - A brief description of what changed and why.
  - Screenshots or recordings for UI changes.
  - Notes on how to test (commands or steps).

## Configuration & Environment Notes
- This app targets macOS and should be built with full Xcode (command-line tools are insufficient).
- If Docker integration is added, document socket paths or permissions in code comments and README updates.
