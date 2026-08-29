# Deferred Items — Phase 5

## Pre-existing test-host early-exit flake (found during 05-01, out of scope)

**Found:** 2026-08-29, during plan 05-01 Task 1/2 verification.

**Symptom:** `xcodebuild … test` exits 65 with "BoosterSimApp (PID) encountered an error (Early unexpected exit, operation never finished bootstrapping … The test runner exited with code 0 before establishing connection)" for 3–5 extra app launches AFTER all test cases pass. All Swift Testing cases pass (0 failures); the exit code is polluted by the post-test relaunches.

**Proof it predates 05-01:** reproduced identically on pristine HEAD (all 05-01 changes removed, only `CertificateServiceTests` selected): same early-exit signature, exit 65, both test cases passing. Bash output captured in the 05-01 execution session (2026-08-29 ~22:54 local).

**Suspects (unverified):** the scheme's test action launching the app for the BoosterSimAppUITests bundle after unit tests complete; UI-test host requiring macOS permissions (AGENTS.md: "UI tests depend on app launch and macOS permissions").

**Impact on 05-01 acceptance:** the plan's literal "xcodebuild test command exits 0" cannot be met on this machine even on pristine HEAD; suite-level green is demonstrated via per-case results (19/19 cases pass, 0 failures, 3 consecutive clean runs after the decode crash fix).

**Suggested follow-up:** investigate scheme test-action composition (`xcodebuild -list`/scheme edit, or `-skip-testing:BoosterSimAppUITests` at the scheme level), or the UI-test host's permission prerequisites. Do NOT fix inside a feature plan.
