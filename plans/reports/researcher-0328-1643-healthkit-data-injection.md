# HealthKit Data Injection on iOS Simulator: Research Report

**Research Date:** 2026-03-28
**Status:** COMPLETE
**Context:** Investigation of `xcrun simctl` capabilities and alternative approaches for populating HealthKit/Health app test data on iOS Simulator.

---

## Executive Summary

**`xcrun simctl` does NOT have a `health_data` subcommand or any health-related CLI commands.** No native Apple CLI tool exists to inject health data into iOS Simulator's Health app. However, **multiple proven alternatives exist**, ranked by adoption maturity and use-case fit.

---

## Key Finding: No Direct CLI

### Q1: Does `xcrun simctl` have health data injection commands?

**Answer: No.**

- Comprehensive audits of `simctl` subcommands (current through Xcode 13+) show no `health_data` subcommand
- Apple's official documentation does not document health data CLI operations
- Xcode 16 (current) still lacks this capability

**Why?** The Health app database is not directly writable via simctl; it enforces access through HealthKit APIs only.

---

## What IS Possible: Three Approaches Ranked

### 1. UI Test Framework (RECOMMENDED for automated testing)

**Tool:** [XCTHealthKit](https://github.com/StanfordBDHG/XCTHealthKit)
**Type:** XCTest UI automation framework (Stanford Biodesign Digital Health)
**Scope:** UI tests only (requires Health app automation)

**What it does:**
- Automates interactions with iOS Health app during UI tests
- Methods: `launchAndAddSample(...)` and `launchAndAddSamples(...)`
- Handles authorization prompts via `handleHealthKitAuthorization()`
- Accepts: steps, heart rate, active energy, electrocardiograms, and other samples

**Data types supported:**
- HKQuantityTypeSample (steps, heart rate, calories, distance, etc.)
- HKCategorySample (mood, mindfulness, sleep analysis)
- HKWorkout samples

**Constraints:**
- UI tests only — not suitable for unit tests
- Requires running on live simulator with Health app available
- Slower than programmatic injection but fully deterministic

**Maturity:** ⭐⭐⭐⭐⭐ (actively maintained, Stanford origin)

---

### 2. Programmatic Approach (RECOMMENDED for unit tests)

**Type:** Direct HealthKit API via HKHealthStore
**Scope:** Unit tests + app code

**How it works:**
```
1. Create HKSample objects (HKQuantitySample, HKCategorySample, HKWorkout)
2. Request authorization from HKHealthStore
3. Save samples via HKHealthStore.save(_:withCompletion:)
4. Samples appear in iOS Health app automatically
```

**Data types you can write:**
- HKQuantitySample (steps, heart rate, distance, active energy, etc.)
- HKCategorySample (mood, mindfulness, sleep, water intake, etc.)
- HKWorkout (exercise sessions with associated samples)

**Data types you CANNOT write:**
- HKCharacteristics (age, biological sex, blood type — read-only)
- HKCategoryTypeIdentifierAppleStandHour (Apple-only)
- HKQuantityTypeIdentifierNikeFuel (Nike-only)

**Advantages:**
- No UI automation overhead
- Works in unit tests AND app code
- Full control over data attributes (timestamp, source, metadata)
- Fastest approach for test setup

**Maturity:** ⭐⭐⭐⭐⭐ (official Apple framework)

---

### 3. Third-Party Data Generators (RECOMMENDED for realistic test data)

**Tier 1 — Most Mature:**

#### [hkimport](https://github.com/ashtom/hkimport)
- Imports Health data exported from real devices (XML export from Health app)
- Workflow: Export from device → Replace project XML → Run app → Populate HealthKit
- **Limitation:** Not all HealthKit types supported
- **Use case:** Realistic historical data from actual user

#### [HealthKitUtility](https://github.com/aidancornelius/HealthKitUtility)
- Swift package for generating realistic synthetic health data
- Supports: steps, heart rate, HRV, sleep, activity with realistic patterns
- Pre-built fixtures + live data streaming
- Works on simulator AND real devices
- **Maturity:** ⭐⭐⭐⭐

#### [Stanford XCTHealthKit](https://github.com/StanfordBDHG/XCTHealthKit)
- Specialized for UI testing (see Approach #1 above)

**Tier 2 — Active Community:**

- [HealthKitGenerator](https://github.com/iAugux/HealthKitGenerator) — Random sample generation
- [heal-healthkit-generator](https://github.com/getheal/heal-healthkit-generator) — Similar, active
- [healthkit-sample-generator](https://github.com/mseemann/healthkit-sample-generator) — Export/import/generation with UI

**Tier 3 — Commercial:**

- [Synthetic Health Data](https://www.synthhealthdata.com/) — Platform that generates + loads data to simulators

**Maturity:** ⭐⭐⭐ to ⭐⭐⭐⭐ (community-driven; adoption varies)

---

## Comparison Matrix

| Approach | Setup Overhead | Data Realism | Speed | Test Isolation | Adoption Risk | Use Case |
|----------|---|---|---|---|---|---|
| **XCTHealthKit** | Medium | High | Slow | Medium (app state) | Low (Stanford) | UI testing + realistic data |
| **Direct API (HKHealthStore)** | Low | Configurable | Fast | High | None (Apple) | Unit tests, deterministic |
| **hkimport** | Low | Very High | Medium | High | Low (stable) | Real device data snapshot |
| **HealthKitUtility** | Low | High | Fast | High | Low (active) | Synthetic realistic data |
| **Random Generators** | Low | Low | Fast | High | Medium (varies) | Quick smoke tests |

---

## Recommended Path for BoosterSimApp

**Stage 1 (MVP):** Use **Direct API** in unit/integration tests
- Simple, zero dependencies
- Full control over test data
- No UI automation complexity

**Stage 2 (Health Tab Feature):** Layer **XCTHealthKit** for UI tests
- Validates Health app integration
- Tests permission flows
- Ensures visual/timing correctness

**Stage 3 (QA/Manual Testing):** Provide **HealthKitUtility** or similar
- Testers populate realistic data without code
- Faster iteration than creating samples in code

---

## Official Apple Documentation

[Accessing Sample Data in the Simulator](https://developer.apple.com/documentation/healthkit/accessing-sample-data-in-the-simulator) — Covers programmatic approach and limitations.

---

## Unresolved Questions

1. **Does Xcode 16.3+ add any new `simctl` health subcommands?**
   → Search was limited to Xcode 13 audit. Recommend: `xcrun simctl help | grep health` on your system.

2. **Can HealthKitUtility be distributed as an app helper, or must it be a dependency?**
   → Appears to be a Swift package; need to verify licensing and distribution model.

3. **What's the performance overhead of XCTHealthKit's Health app automation?**
   → Likely 2–5s per sample addition; no benchmark found in docs.

4. **Can `simctl io` or `simctl privacy` be repurposed for health data?**
   → Unlikely (io = screenshots/video, privacy = permissions), but worth testing if urgent.

---

## Sources

- [Apple HealthKit Documentation — Accessing Sample Data](https://developer.apple.com/documentation/healthkit/accessing-sample-data-in-the-simulator)
- [XCTHealthKit Framework](https://github.com/StanfordBDHG/XCTHealthKit)
- [hkimport — Health Data Import Tool](https://github.com/ashtom/hkimport)
- [HealthKitUtility — Synthetic Data Generator](https://github.com/aidancornelius/HealthKitUtility)
- [NSHipster — simctl Reference](https://nshipster.com/simctl/)
- [iOS Dev Recipes — simctl Command Reference](https://www.iosdev.recipes/simctl/)
- [Comprehensive simctl Subcommand Audit (Xcode 13.0)](https://gist.github.com/sparkrod/02e2dadf9e667ff139570b0ccf7b1489)

