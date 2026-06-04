---
title: "GitHub Actions CI: Unit Test Gate"
description: "Add GitHub Actions workflow that runs unit tests on PRs and blocks merge on failure"
status: pending
priority: P2
effort: 30m
---

# GitHub Actions CI: Unit Test Gate

## Overview

Add a GitHub Actions workflow that runs `BoosterSimAppTests` on every PR to `main`. Branch protection requires the check to pass before merge.

**Key constraint:** macOS app (SDKROOT=macosx, deployment target 26.2). Must use `macos-15` runner with Xcode 26+.

## Phase 1: Create Workflow File

### File: `.github/workflows/ci.yml`

```yaml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  test:
    name: Unit Tests
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_26.3.app/Contents/Developer

      - name: Resolve SPM Dependencies
        run: xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -resolvePackageDependencies

      - name: Build & Test
        run: |
          xcodebuild test \
            -project BoosterSimApp.xcodeproj \
            -scheme BoosterSimApp \
            -destination 'platform=macOS' \
            -configuration Debug \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO

      - name: Upload Test Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: ~/Library/Developer/Xcode/DerivedData/**/Logs/Test/*.xcresult
```

### Notes

- `macos-15` runner required for macOS 26 SDK
- Xcode version may need adjustment based on GitHub runner availability
- Code signing disabled — tests don't need it on CI
- `BoosterSimConnect` (iOS target) is NOT tested here — it requires iOS Simulator which adds complexity. Add in separate workflow if needed.
- `BoosterSimAppUITests` excluded from CI — UI tests need simulator + are flaky. Add later if needed.

## Phase 2: Branch Protection (Manual)

Configure in GitHub repo Settings → Branches → Branch protection rules → `main`:

1. Enable "Require status checks to pass before merging"
2. Add required check: `Unit Tests` (matches job name)
3. Enable "Require branches to be up to date before merging" (recommended)

**This is done via GitHub UI or `gh` CLI, not code.**

```bash
# Via gh CLI (requires admin access):
gh api repos/phuongddx/BoosterSimApp/branches/main/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":["Unit Tests"]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":1}' \
  --field restrictions=null
```

## Todo List

- [ ] Create `.github/workflows/ci.yml`
- [ ] Push to a branch and verify workflow triggers on PR
- [ ] Configure branch protection rule for `main`
- [ ] Verify merge button is blocked when tests fail

## Success Criteria

1. PR to `main` triggers CI workflow
2. Unit tests run and report pass/fail
3. Merge button locked until `Unit Tests` check passes
4. Direct pushes to `main` also run tests (no gate, just reporting)

## Unresolved Questions

1. **Xcode version on runner:** `macos-15` runner may not have Xcode 26.x yet. May need `macos-26` runner or install Xcode manually. Check GitHub Actions runner images availability.
2. **Pulse SPM resolution:** First build will resolve Pulse package — may timeout on slow runners. Consider caching SPM derivatives.
