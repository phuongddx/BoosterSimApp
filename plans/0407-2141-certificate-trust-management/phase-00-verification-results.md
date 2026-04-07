# Phase 0 Verification Results

## SimCtlService.run
- Execution model: argv-array
- Evidence: `Process` uses `executableURL = /usr/bin/xcrun` and `arguments = ["simctl"] + args` in [SimCtlService.swift](/Users/ddphuong/Projects/next-labs/sim-dev-tool/BoosterSimApp/BoosterSimApp/Services/SimCtlService.swift#L39)

## SimulatorWindow name property
- Actual properties: `deviceName` and fallback `displayName`
- Evidence: [SimulatorWindow.swift](/Users/ddphuong/Projects/next-labs/sim-dev-tool/BoosterSimApp/BoosterSimApp/Models/SimulatorWindow.swift#L22)

## simctl keychain booted with 2+ sims
- Result: command succeeded with two booted devices
- Evidence:
  - Booted devices observed via `list_sims`: `00AFDCEE-858A-4B7D-B5B4-08D3B1D6CAFB` and `72963F3C-AE33-43D5-AE8F-674374EAFD4A`
  - `xcrun simctl keychain booted add-root-cert /tmp/cert-trust-phase0.pem` exited `0`
- Decision: still require explicit UDID. A successful `"booted"` install with multiple devices is worse than a hard failure because the target device is ambiguous.

## iOS Simulator trust without Settings toggle
- Verified cert is trusted: pending Phase 3 smoke test
- Notes: no safe claim yet. This must be validated with real HTTPS traffic in Simulator Safari after the feature is wired.

## simctl keychain subcommands available
- add-cert: yes
- add-root-cert: yes
- reset: yes
- remove-cert: no
- list: no
- Evidence: `xcrun simctl help keychain`

## /usr/bin/openssl
- Version: `LibreSSL 3.3.6`
- Present on macOS 15: yes
- Evidence:
  - `/usr/bin/openssl version`
  - `file /usr/bin/openssl`

## Notes
- Phase 0 is complete for the non-manual assumptions. The Simulator trust-toggle smoke test remains deferred to Phase 3.
- The current Xcode `simctl keychain` help surface does not expose a list/remove command, so cross-relaunch trust verification cannot rely on `simctl` alone.
- Temporary verification files were created under `/tmp`: `cert-trust-phase0.key`, `cert-trust-phase0.pem`.
