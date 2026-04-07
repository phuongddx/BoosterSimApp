# Brainstorm: Network Tools Feature Breakdown

**Date:** 2026-04-06
**Parent Issue:** phuongddx/BoosterSimApp#4

---

## Key Finding

iOS Simulator shares macOS host's network stack entirely — no separate layer. This means:
- **Proxy approach** works: Simulator inherits system proxy settings
- **pfctl/dnctl** works: traffic shaping applies to all processes (including Simulator)
- **simctl keychain** works: direct cert management per Simulator
- **Per-app scoping** requires Network Extension (Apple entitlement, high complexity) — deferred

## Sub-Issues Created

| Issue | Feature | Approach | Root? | Effort |
|-------|---------|----------|:-----:|:------:|
| #6 | Traffic Monitor | NWListener proxy + request log | No* | ~6h |
| #7 | Speed Control | pfctl + dnctl + SMJobBless | Yes | ~8h |
| #8 | Airplane Mode | Proxy 503 rejection | No | ~1h |
| #9 | Request Blocking | Proxy domain/path rules | No | ~3h |
| #10 | Certificate Trust | simctl keychain + openssl | No | ~3h |

## Dependency Graph

```
#10 (Certs) ─────────────── independent
#7  (Throttle) ──────────── independent
#6  (Proxy) → #8 (Airplane) → #9 (Blocking)
```

## Recommended Build Order

1. **#10 Certificate Trust** — simplest, uses existing SimCtlService, immediate value
2. **#6 Traffic Monitor** — proxy foundation, unlocks #8 and #9
3. **#8 Airplane Mode** — trivial once proxy exists (~1h)
4. **#9 Request Blocking** — rule engine on top of proxy
5. **#7 Speed Control** — highest complexity (SMJobBless helper), independent track

## Approaches Evaluated & Rejected

| Approach | Why Rejected |
|----------|-------------|
| Network Extension (NEFilterDataProvider) | Requires Apple entitlement request, System Extension target, high deployment friction. Overkill for MVP. |
| DYLD_INSERT_LIBRARIES injection | High complexity, only captures URLSession traffic, fragile across iOS versions. Consider for Phase 2+. |
| CFNETWORK_DIAGNOSTICS | Read-only, requires process restart, unstructured log parsing. Debugging tool, not production UI. |
| `nettop` / `proc_pidinfo` passive observation | Read-only, no content visibility, no blocking/throttling. Only useful as supplementary widget. |
| `/etc/hosts` manipulation | Requires root, system-wide, no path-level blocking, no per-Simulator scoping. |

## Key Constraints

- `networksetup` (system proxy) affects ALL Mac traffic — must auto-revert on quit
- pfctl/dnctl require root → SMJobBless privileged helper (admin prompt on first install)
- HTTPS content inspection possible but deferred (MITM proxy + per-host cert gen = very high complexity)
- No `xcrun simctl` network commands exist — confirmed

## Unresolved Questions

1. Does `networksetup -setwebproxy` require admin password on macOS 15+?
2. Apps using direct IP/socket connections bypass proxy — acceptable limitation?
3. Multiple simultaneous Simulators: proxy applies to all. Per-Simulator routing needs separate proxy ports.

## Research Artifacts

- Full technical report: `plans/reports/researcher-0406-2308-network-inspection-manipulation.md`
- Codebase scout: `plans/reports/Explore-0405-NetworkTools-Scout.md`
