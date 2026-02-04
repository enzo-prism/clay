# Contributing to Clay

Thanks for taking the time to contribute. This project is a macOS SwiftUI app with an Xcode workspace and a Swift Package for most feature code.

## Development Setup

Requirements:
- macOS 15+
- Xcode 16+

Getting started:
1. Clone the repo
2. Open `Clay.xcworkspace` in Xcode
3. Select the `Clay` scheme and Run

## Project Structure

- App shell: `Clay/`
- Primary feature code: `ClayPackage/Sources/ClayFeature/`
- Unit tests: `ClayPackage/Tests/ClayFeatureTests/`
- UI tests: `ClayUITests/`
- Build settings: `Config/*.xcconfig`

## Running Tests

- Unit tests: `cd ClayPackage && swift test`
- UI tests: run the `Clay/Clay.xctestplan` in Xcode

## Conventions

- Keep state mutations on the main actor. `GameEngine` is `@MainActor`.
- If you add fields to `GameState`, update `GameEngine.defaultState(...)` and add decode defaults/migration so existing saves keep loading.
- If you add content fields, update both `Resources/content.json` and `Models/ContentDefinitions.swift`.
- Adding new tabs requires updates to `ClayTab`, the command menu in `Clay/ClayApp.swift`, and the sidebar UI.

## Assets and Licensing

- Keep third‑party assets in `Resources/` and ensure the attribution files are updated.
- If you add fonts, register them in `UI/DesignSystem/FontRegistry.swift`.

## Security

- Do not commit secrets (API keys, tokens, credentials).
- Use environment variables or the macOS Keychain for local development.

## Pull Requests

- Describe the intent and scope of the change.
- Include test evidence or explain why tests are not needed.
- Keep changes focused and small when possible.
