# BoosterSimApp — Deep Research Report

**Date:** June 2026 | **Prepared for:** Phuong

---

## 1. Executive Summary

BoosterSimApp là một macOS menu bar companion app gắn side panel floating vào iOS Simulator. Built với AppKit + SwiftUI, zero dependencies, targeting macOS 15+.

Ngách "iOS Simulator companion / developer tools" đang grow nhanh, led by RocketSim (~$100K ARR). Competitors: SimKit, ControlRoom, Proxyman, Pulse. AI coding agents (XcodeBuildMCP, RocketSim Agent Skill) đang reshape landscape.

BoosterSimApp hiện ở early stage — Phase 1 + Phase 6 complete, Phase 5 (network) partial. 73 files, ~6,556 LOC. Key gap: chưa có screenshot/recording, design overlays, app actions.

---

## 2. Project Analysis

| Attribute | Value |
|---|---|
| Path | /Users/ddx-pro17/BoosterSimApp/ |
| Type | macOS menu bar app (LSUIElement) |
| Tech Stack | Swift 6, AppKit, SwiftUI, Combine, Network |
| LOC | ~6,556 (73 Swift files) |
| Sandbox | Non-sandboxed |

### Feature Status

**✅ Complete:** Core Panel, Accessibility Inspector, Build Stats, Environment Overrides (11 toggles), Status Bar Control, Camera Toggle, Certificate Trust, Pulse Network Viewer

**❌ Not Started:** Screenshot/Recording, App Actions (push/deep link/reset), Design Overlays, Network Throttle/Block, Distribution/Signing

### Architecture

- Service-oriented: AppDelegate owns 16+ services via @Published/Combine
- SimulatorWindowTracker: dual-mode (CGWindowList poll + AXObserver real-time)
- SpringAnimator: CADisplayLink-driven spring physics
- PulseServer: NWListener TCP + Bonjour
- BoosterSimConnect: iOS framework with PulseProxy

---

## 3. Competitive Landscape

### Direct Competitors

| Tool | Type | Price | Key Features |
|---|---|---|---|
| RocketSim | Commercial (Indie) | Free + Pro + Teams | 30+ utilities, CLI/Agent Skill, recordings, design compare |
| SimKit | Freemium | Free + Pro | Network monitoring, capture, design overlays, mock APIs |
| ControlRoom | Open Source (MIT) | Free | simctl wrapper, status bar, push, deep links |
| SimPholders | Commercial | Free/Paid | App container browser |

### Adjacent Tools

| Tool | Price | Overlap |
|---|---|---|
| Proxyman | $59-129 | Network traffic inspection |
| Pulse (kean) | Free (OSS) | PulseProxy integration (already used) |
| XcodeBuildMCP | Free (Sentry OSS) | AI agent Xcode automation, 78+ tools |
| Helm | $9.99/mo | App Store Connect (different niche) |

### RocketSim Deep Dive

- Creator: Antoine van der Lee (SwiftLee, ex-WeTransfer)
- Revenue: ~$100K ARR (RevenueCat Launched podcast 2026)
- Timeline: 2019 deep link tool → 30+ utilities → full-time indie 2024
- Key 2025-26: Network Speed Control (v13), Connect (Pulse), CLI + Agent Skill, iOS 26
- Marketing: Blog-driven (SwiftLee), no ads, community-led

---

## 4. Market Analysis

- Global iOS developers: ~4-5M
- App Store ecosystem: $1.4T developer billings (2025)
- TAM: ~2-3M active iOS developers
- SAM: ~500K-1M who'd adopt a simulator companion
- Revenue potential: $250K-$1.5M/yr (1-3% conversion at $50/yr)

### Key Trends (2025-2026)

1. **AI Agent Integration** — Xcode 26.3 MCP, RocketSim Agent Skill, XcodeBuildMCP. THE defining trend.
2. **Network Debugging Democratization** — Pulse + Connect eliminating proxy certs
3. **Build Performance Analytics** — Team benchmarking becoming table stakes
4. **iOS 26 / Liquid Glass** — Design comparison tools more important
5. **Indie Dev Tools Renaissance** — Helm, RocketSim, SimKit thriving

---

## 5. SWOT

### Strengths
- Zero dependencies (Apple frameworks only)
- Swift 6 strict concurrency → future-proof
- Pulse network viewer already implemented
- Certificate trust management (unique)
- Solid architecture, well-documented (7 docs)
- Non-sandboxed enables powerful AX/camera features

### Weaknesses
- No screenshot/recording — THE killer feature
- No design overlays, push, deep links
- No distribution/signing — can't ship yet
- Single developer, no marketing audience

### Opportunities
- AI Agent integration (CLI/MCP for Cursor/Claude/Codex)
- Open source strategy (MIT, build community)
- Vietnamese/Asian dev community (underserved)
- Niche: automated accessibility testing, CI/CD integration
- Setapp distribution

### Threats
- RocketSim: dominant, ~$100K ARR, growing
- SimKit: direct clone, already on App Store
- Apple: could build side panel into Xcode (26.3 MCP is a step)
- Platform risk is REAL

---

## 6. Feature Gap Analysis

| Feature | BoosterSimApp | RocketSim | Priority |
|---|---|---|---|
| Side panel | ✅ | ✅ | — |
| AX inspector | ✅ | ✅ | — |
| Env overrides | ✅ | ✅ | — |
| Status bar config | ✅ | ✅ | — |
| Build stats | ✅ | ✅ | — |
| Camera sim | ✅ | ✅ | — |
| Network viewer (Pulse) | ✅ | ✅ | — |
| Certificate trust | ✅ | ✅ | — |
| Network speed control | ❌ | ✅ | HIGH |
| Screenshot capture | ❌ | ✅ | CRITICAL |
| Screen recording / GIF | ❌ | ✅ | CRITICAL |
| Design comparison | ❌ | ✅ | HIGH |
| Grid/safe area overlay | ❌ | ✅ | MEDIUM |
| Color picker | ❌ | ✅ | MEDIUM |
| Push notifications | ❌ | ✅ | HIGH |
| Deep links | ❌ | ✅ | HIGH |
| Location simulation | ❌ | ✅ | MEDIUM |
| User Defaults editor | ❌ | ✅ | MEDIUM |
| CLI / Agent Skill | ❌ | ✅ | STRATEGIC |

---

## 7. Strategic Recommendations

### PHASE A — Ship MVP (Month 1-2) [CRITICAL]
1. Screenshot capture (ScreenCaptureKit)
2. Screen recording + GIF export
3. Code signing + notarization
4. GitHub repo + landing page
5. Privacy manifest

### PHASE B — Competitive Features (Month 3-4) [HIGH]
1. Push notifications (xcrun simctl push)
2. Deep links (xcrun simctl openurl)
3. Network speed control
4. App reset / clear keychain
5. Location simulation

### PHASE C — Differentiation (Month 5-6) [STRATEGIC]
1. AI Agent: CLI + MCP server for Cursor/Claude/Codex
2. Open source core (MIT)
3. Accessibility test reports (WCAG audit)
4. Design comparison (Figma/Sketch import)

### PHASE D — Distribution (Month 7-12)
1. Mac App Store
2. Setapp partnership
3. Content marketing
4. Vietnamese dev community

### Business Model
- **FREE:** Core panel, AX inspector, env overrides, build stats
- **PRO ($5-8/mo):** Screenshots, recordings, network throttle, design tools, CLI
- **EDGE:** Open source + AI agent + accessibility testing

---

## 8. Technical Assessment

### Architecture Score: 8/10

✅ Clean service-oriented design
✅ Swift 6 strict concurrency
✅ Well-documented (7 docs, GitNexus indexed)
✅ Design tokens system
✅ Dual-mode simulator detection
⚠️ Large files (TrafficDetailView 295 LOC)
⚠️ Test coverage minimal

### Key Technical Risks

1. Non-sandboxed requirement limits Mac App Store
2. AXObserver/CGWindowList APIs private-ish
3. Pulse binary protocol parsing fragile
4. No CI/CD pipeline
5. Certificate management uses OpenSSL shell-out

---

## 9. Verdict

**🟡 STRONG POTENTIAL / EARLY STAGE**

BoosterSimApp có kiến trúc solid, đã implement những features khó nhất (Pulse network, certificate trust, spring physics). Đang thiếu "table stakes" (screenshots, push, deep links).

#1 priority: ship screenshot/recording + distribution. Strategic differentiator: AI agent integration — trend mới nhất, còn room cho nhiều players.

Nếu open source + AI agent tools → niche riêng giữa RocketSim (commercial) và ControlRoom (basic OSS).

---

## Sources

1. RocketSim Official — rocketsim.app
2. RocketSim App Store — apps.apple.com (id1504940162)
3. RevenueCat Launched Podcast Ep. 88, Antoine van der Lee (2026)
4. RocketSim 13.0 — SwiftLee / avanderlee.com (Jan 2025)
5. ControlRoom — github.com/twostraws/ControlRoom (MIT)
6. SimKit — dev.to/ealtaca, Mac App Store (id6756196371)
7. Pulse — github.com/kean/Pulse
8. Proxyman Pricing — proxyman.com/pricing
9. Helm — apps.apple.com (id6479357934)
10. XcodeBuildMCP — xcodebuildmcp.com, github.com/getsentry/XcodeBuildMCP
11. Apple $1.4T Report — apple.com/newsroom (June 2026)
12. codersera.com (April 2026)
13. BoosterSimApp internal docs
14. neonwatty.com
15. reddit.com/r/iOSProgramming (2025)

---
*Generated June 2026 | Prepared for Phuong | 15 sources | 9 sections*
