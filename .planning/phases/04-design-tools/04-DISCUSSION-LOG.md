# Phase 4: Design Tools - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-31
**Phase:** 4-Design Tools
**Areas discussed:** Grid & safe-area

---

## Area Selection

Offered gray areas (multiSelect): Overlay interaction, Design import path, Magnifier behavior, Grid & safe-area.

**User's choice:** Grid & safe-area only.

---

## Grid Composition

| Option | Description | Selected |
|--------|-------------|----------|
| Dual 8+4 grid | 8pt minor lines with emphasized 4pt subdivisions rendered together — Figma/Sketch major-minor style; matches criterion wording; replaces scaffold's single gridSpacing | ✓ |
| Single spacing picker | One grid with a spacing control (8pt/4pt/any) — simpler, closest to existing scaffold model | |

**User's choice:** Dual 8+4 grid
**Notes:** Locked as D-01 (CONTEXT.md).

---

## Safe-Area Inset Source

| Option | Description | Selected |
|--------|-------------|----------|
| Constants + override | Per-device-logical-size inset table auto-selected from detected Simulator device; editable manual fields + reset | ✓ |
| Constants only | Same auto table, no manual editing | |
| Manual only | Type insets every time; presets compensate | |

**User's choice:** Constants + override
**Notes:** Locked as D-02 (CONTEXT.md).

---

## Visual Defaults & Adjustability

| Option | Description | Selected |
|--------|-------------|----------|
| Defaults + adjustable | Adaptive defaults (system-blue grid, Xcode-like safe-area margins) AND keep scaffold's color/opacity controls | ✓ |
| Fixed style only | Locked constants, no controls — risks washing out on light app palettes | |
| You decide | Research/design pass decides palette and whether controls ship | |

**User's choice:** Defaults + adjustable
**Notes:** Locked as D-03 (CONTEXT.md).

---

## Overlay Layering

| Option | Description | Selected |
|--------|-------------|----------|
| Guides on top | grid/safe-area > ruler/magnifier readouts > imported design image > Simulator content | ✓ |
| Image on top | Imported artboard covers grid — purest visual comparison, loses grid while comparing | |
| You decide | Research/planning fixes documented z-order; only per-tool toggle requirement locked | |

**User's choice:** Guides on top
**Notes:** Locked as D-04 (CONTEXT.md); rated costly to reverse.

---

## Claude's Discretion

Recorded in CONTEXT.md: scaffold disposition (cut-over precedent from Phase 2), overlay window architecture, ruler/magnifier input model, design import path (incl. Figma API dependency trade-off), magnifier behavior, exact safe-area table values.

## Deferred Ideas

None — discussion stayed within phase scope.
