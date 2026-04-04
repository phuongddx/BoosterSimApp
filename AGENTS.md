# Repository Guidelines

## Project Structure & Module Organization
`BoosterSimApp/` contains the macOS app source. Keep AppKit lifecycle code in `App/`, domain models in `Models/`, long-lived logic in `Services/`, shared constants in `Utilities/`, floating panel code in `Windows/`, and SwiftUI screens in `Views/` (`MenuBar/`, `Onboarding/`, `Preferences/`, `Shared/`, `SideWindow/`). Assets live in `BoosterSimApp/Assets.xcassets`. Unit tests are in `BoosterSimAppTests/`; UI tests are in `BoosterSimAppUITests/`. Supporting design and architecture notes live in `docs/`.

## Build, Test, and Development Commands
Open the project in Xcode with `open BoosterSimApp.xcodeproj` and run with `Cmd+R`. Terminal build:

```bash
xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build
```

Run tests from Xcode when possible because UI tests depend on app launch and macOS permissions. Terminal test command:

```bash
xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test
```

Use the app against a live iOS Simulator on macOS 15+ with Xcode 16.3+.

## Coding Style & Naming Conventions
Use Swift 6 with strict concurrency and 4-space indentation. Follow the repository standard in `docs/code-standards.md`: `PascalCase.swift` filenames, file name matching the primary type, `final class` by default for services/controllers, and `@MainActor` for UI-bound types. Organize files with `// MARK:` sections. Prefer small SwiftUI views and move reusable atoms into `Views/Shared/`. Do not hardcode layout values; use `Utilities/DesignTokens.swift`.

## Testing Guidelines
Add behavior-focused unit tests under `BoosterSimAppTests/` using Swift Testing (`import Testing`, `@Test`, `#expect`). Put launch and interaction coverage in `BoosterSimAppUITests/` using XCTest. Name unit tests after the behavior they verify and UI tests with `test...` methods, for example `testLaunchPerformance()`. No coverage gate is defined yet; contributors should add tests for new services, positioning logic, and permission-related fallbacks.

## Commit & Pull Request Guidelines
Follow the existing Conventional Commit style seen in history: `feat(side-window): ...`, `fix(env-overrides): ...`, `docs: ...`. Keep scopes specific to the area changed. PRs should include a short summary, testing performed, linked issue or plan when applicable, and screenshots or recordings for visible UI changes to the side panel, onboarding, or preferences.

## Security & Configuration Tips
Do not commit personal paths, derived data, or permission-specific machine state. Features that touch Accessibility, Screen Recording, or `simctl` should document required permissions and degraded behavior when access is denied.
