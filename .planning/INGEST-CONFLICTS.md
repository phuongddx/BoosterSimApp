## Conflict Detection Report

Ingest set: 10 docs (2 PRD, 1 SPEC, 7 DOC, 0 ADR). Mode: new. Precedence applied:
ADR > SPEC > PRD > DOC (no per-doc overrides; no locked decisions exist).
Cycle detection: no cycles (ingest-set edges: system-architecture → design-guidelines /
project-overview-pdr / project-roadmap; 2026-03-28-health-data-generator → project-roadmap;
all other cross-references point outside the ingest set). Max traversal depth 2 (cap 50).

### BLOCKERS (0)

None. No LOCKED-vs-LOCKED ADR contradictions (no ADRs ingested), no UNKNOWN-low-confidence
classifications, no cross-reference cycles, and MODE=new means no existing-context checks apply.

### WARNINGS (2)

[WARNING] Competing acceptance variants for external-dependency policy (REQ-nfr-03)
  Found: docs/project-overview-pdr.md NFR-03 requires "Zero external dependencies (Apple frameworks only)"
  Found: docs/project-roadmap.md Phase 5 (checked) records "BoosterSimConnect — iOS framework with PulseProxy activation (Pulse/PulseProxy SPM integrated)"
  Found: BoosterSimApp.xcodeproj/project.pbxproj links Pulse 5.1.0+ (github.com/kean/Pulse.git) and PulseProxy as packageProductDependencies on BOTH the BoosterSimApp native target and the BoosterSimConnect framework target
  Found: docs/codebase-summary.md understates the linkage as "Pulse/PulseProxy SPM (BoosterSimConnect framework only)"; docs/journals/2026-04-12-booster-sim-connect-activation.md states "zero external dependencies added" for its changeset
  Impact: Synthesis cannot pick without losing intent — either NFR-03 is violated by the current build (Pulse is load-bearing for the Connect traffic viewer), or the requirement must be rewritten/scoped; downstream REQUIREMENTS.md would otherwise contradict the actual project configuration
  → Choose one variant before routing: relax/rewrite NFR-03 (e.g., scope the exception to Pulse via BoosterSimConnect) or remove the Pulse/PulseProxy products from the BoosterSimApp target. Both variants are preserved in intel/requirements.md (REQ-nfr-03 vs REQ-roadmap-phase5-network-tools).

[WARNING] Health Data Generator: journal reports complete, repo shows removed
  Found: docs/journals/2026-03-28-health-data-generator.md (Status: Resolved) claims the feature is "complete, integrated, building, and ready to QA" with 7 files and an updated roadmap; docs/journals/2026-03-28-health-data-generator-discovery.md records the full approach and plans/0328-1642-health-data-generator/ retains the 5-phase plan
  Expected: docs/project-roadmap.md and docs/codebase-summary.md contain no Health Data Generator scope or files, matching the working tree — git history shows 9bf180c "feat(health-data): add BoosterHealth companion + health data generator" followed by 3b1015f "refactor: remove BoosterHealth companion app and health data service" (both reachable from main); no BoosterHealth/ directory or Health*.swift files exist
  Impact: Downstream routing could either resurrect a deliberately removed feature from a stale journal or silently discard the institutional knowledge that a working implementation once existed and is recoverable
  → Decide before routing: if Health Data Generation is still wanted, add it as explicit roadmap scope (removed implementation + existing plans are reusable); if not, mark both 2026-03-28 health journals as superseded so the roadmapper does not route scope from them

### INFO (1)

[INFO] Auto-resolved: PRD > DOC on external dependencies
  Note: docs/system-architecture.md Key Design Decisions table records "Zero external dependencies — minimal footprint, no SPM overhead, pure Apple framework stability", which contradicts docs/project-roadmap.md (PRD) whose Phase 5 records Pulse/PulseProxy SPM integrated (repo confirms linkage on both targets). Per precedence PRD outranks DOC: the roadmap stands and the architecture doc's zero-dependency row is recorded as stale in intel/context.md (topic: architecture-key-design-decisions). The still-open PRD-vs-PRD variant is tracked separately in the WARNING above.
