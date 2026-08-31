# API Coverage — Phase 4 Design Tools

No external API integration: the phase composes Apple system frameworks only (AppKit, SwiftUI, Combine, CoreGraphics, ScreenCaptureKit, UniformTypeIdentifiers) over in-repo seams; the Figma/Sketch artboard import is deliberately file/drag/paste-based — the Figma REST API was evaluated and REJECTED in 04-RESEARCH.md (Alternatives Considered: OAuth token management + network stack against the Apple-only ethos, REQ-nfr-03 heritage), and a plan-level prohibition forbids any network client in the design-overlay sources.

> Detector note: the api-coverage scan fired `detected: true` on the terms "api"/"rest", both of which occur only in the *rejection* of the Figma REST API (04-RESEARCH.md Alternatives Considered and the 04-02 locality prohibition). Re-reading the phase scope confirms no external API, SDK, or service is integrated, so per the checkpoint protocol this reasoned declaration stands in place of a matrix — no capability rows exist to decide.
