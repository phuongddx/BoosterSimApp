---
phase: 3
name: app-actions
created: 2026-08-30
source: user decisions during /gsd-manager plan-phase 3 (no discuss-phase run; these two scope calls were made explicitly by the user against research-proven platform limits)
---

# Phase 3 Context — App Actions

<decisions>
- **D-01:** Push permission guided manual grant — `simctl privacy` has NO notifications service (research-proven 2026-08-30 via positive controls; TCC.db has no UserNotifications row), so grant/revoke push permission is not automatable. SHIP: push sending with a permission control that detects current APNS state (via spawn test-push probe) and links/guides the user to Settings → Notifications for the manual grant, documented as a platform limitation. Locked (user decision 2026-08-30). Category: scope-resolution.
- **D-02:** Destructive keychain clear with CA reconcile — per-app keychain clear does not exist on Simulator (device-wide only; wipes the Phase 5 local CA). SHIP: an explicit destructive action — red-typed confirmation naming the blast radius (ALL device keychains + local CA), then automatic CA re-reconcile afterward via the existing CertificateService. Locked (user decision 2026-08-30). Category: scope-resolution.
</decisions>

### Claude's Discretion

- Everything else in 03-RESEARCH.md's Recommended Approach (AppActionService facade, DerivedDataAppScanner, UserDefaultsEditorService, stdin-extended SimCtlService, AppActionCatalog, DeepLinkService migration onto the seam, searchable Actions tab sections) — follow the binding research.
- Reuse-not-rebuild for dark/light, Dynamic Type, and deep links (already shipped in the Actions tab via Phase 6 + DeepLinkSectionView; criterion 3/2 items are completion/polish, not rebuilds).
