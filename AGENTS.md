# Agent Notes

This repository is a macOS SwiftUI app using an Xcode workspace plus a Swift Package for most feature code.

**Project Map**
- App shell: `Clay/` (minimal app target, entry point in `Clay/ClayApp.swift`).
- Primary code: `ClayPackage/Sources/ClayFeature/`.
- Tests: `ClayPackage/Tests/ClayFeatureTests/` (Swift Testing) and `ClayUITests/`.
- Build settings: `Config/*.xcconfig`, entitlements in `Config/Clay.entitlements`.

**Key Entry Points**
- `Clay/ClayApp.swift`: app entry and command menu.
- `ClayPackage/Sources/ClayFeature/ContentView.swift`: root view and tab routing.

**State, Content, Persistence**
- Engine: `ClayPackage/Sources/ClayFeature/Engine/GameEngine.swift`.
- Persisted state: `ClayPackage/Sources/ClayFeature/Models/GameState.swift` (Codable).
- Persistence: `ClayPackage/Sources/ClayFeature/Engine/Persistence.swift` writes to Application Support `Clay/save.json` with rotating backups.
- Content data: `ClayPackage/Sources/ClayFeature/Resources/content.json` loaded by `Engine/ContentLoader.swift` and modeled by `Models/ContentDefinitions.swift`.

**UI Design System**
- Colors and layout constants: `UI/DesignSystem/ClayTheme.swift`.
- Fonts: `UI/DesignSystem/FontRegistry.swift` (registers fonts from `Resources/Fonts`).
- Shared components: `UI/DesignSystem/Components.swift`.

**Build and Test**
- Open `Clay.xcworkspace` in Xcode.
- Run unit tests from `ClayPackage` with `swift test`.
- UI tests run via the `Clay/Clay.xctestplan` in Xcode.

**Conventions and Gotchas**
- `GameEngine` is `@MainActor`; keep state mutations on the main actor.
- If you add fields to `GameState`, update `GameEngine.defaultState(...)` and consider decode defaults/migration so existing saves keep loading.
- If you add content fields, update both `content.json` and `Models/ContentDefinitions.swift` to keep the schema aligned.
- Adding new tabs requires updates to `ClayTab` plus the command menu in `Clay/ClayApp.swift` and sidebar UI.
