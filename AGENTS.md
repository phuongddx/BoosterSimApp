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

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **BoosterSimApp** (1402 symbols, 1430 relationships, 0 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## When Debugging

1. `gitnexus_query({query: "<error or symptom>"})` — find execution flows related to the issue
2. `gitnexus_context({name: "<suspect function>"})` — see all callers, callees, and process participation
3. `READ gitnexus://repo/BoosterSimApp/process/{processName}` — trace the full execution flow step by step
4. For regressions: `gitnexus_detect_changes({scope: "compare", base_ref: "main"})` — see what your branch changed

## When Refactoring

- **Renaming**: MUST use `gitnexus_rename({symbol_name: "old", new_name: "new", dry_run: true})` first. Review the preview — graph edits are safe, text_search edits need manual review. Then run with `dry_run: false`.
- **Extracting/Splitting**: MUST run `gitnexus_context({name: "target"})` to see all incoming/outgoing refs, then `gitnexus_impact({target: "target", direction: "upstream"})` to find all external callers before moving code.
- After any refactor: run `gitnexus_detect_changes({scope: "all"})` to verify only expected files changed.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Tools Quick Reference

| Tool | When to use | Command |
|------|-------------|---------|
| `query` | Find code by concept | `gitnexus_query({query: "auth validation"})` |
| `context` | 360-degree view of one symbol | `gitnexus_context({name: "validateUser"})` |
| `impact` | Blast radius before editing | `gitnexus_impact({target: "X", direction: "upstream"})` |
| `detect_changes` | Pre-commit scope check | `gitnexus_detect_changes({scope: "staged"})` |
| `rename` | Safe multi-file rename | `gitnexus_rename({symbol_name: "old", new_name: "new", dry_run: true})` |
| `cypher` | Custom graph queries | `gitnexus_cypher({query: "MATCH ..."})` |

## Impact Risk Levels

| Depth | Meaning | Action |
|-------|---------|--------|
| d=1 | WILL BREAK — direct callers/importers | MUST update these |
| d=2 | LIKELY AFFECTED — indirect deps | Should test |
| d=3 | MAY NEED TESTING — transitive | Test if critical path |

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/BoosterSimApp/context` | Codebase overview, check index freshness |
| `gitnexus://repo/BoosterSimApp/clusters` | All functional areas |
| `gitnexus://repo/BoosterSimApp/processes` | All execution flows |
| `gitnexus://repo/BoosterSimApp/process/{name}` | Step-by-step execution trace |

## Self-Check Before Finishing

Before completing any code modification task, verify:
1. `gitnexus_impact` was run for all modified symbols
2. No HIGH/CRITICAL risk warnings were ignored
3. `gitnexus_detect_changes()` confirms changes match expected scope
4. All d=1 (WILL BREAK) dependents were updated

## Keeping the Index Fresh

After committing code changes, the GitNexus index becomes stale. Re-run analyze to update it:

```bash
npx gitnexus analyze
```

If the index previously included embeddings, preserve them by adding `--embeddings`:

```bash
npx gitnexus analyze --embeddings
```

To check whether embeddings exist, inspect `.gitnexus/meta.json` — the `stats.embeddings` field shows the count (0 means no embeddings). **Running analyze without `--embeddings` will delete any previously generated embeddings.**

> Claude Code users: A PostToolUse hook handles this automatically after `git commit` and `git merge`.

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
