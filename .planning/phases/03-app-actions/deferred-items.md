# Phase 3 — Deferred Items

Out-of-scope discoveries logged per the executor scope boundary (not auto-fixed; each is a pre-existing gap untouched by 03-05's files).

| # | Found during | Item | Status |
|---|--------------|------|--------|
| 1 | 03-05 Task 1 (docs truth pass) | `docs/codebase-summary.md` directory tree omits the **Phase 2 capture surface** (CaptureService/ScreenshotService/RecordingService/CaptureExporter/TouchIndicatorController/CaptureSaveRouter/CaptureThumbnailPanel/CaptureCompositor + capture models/views + 3 capture test files) — the file was last touched in Phase 5 (209fa8e) and Phase 2's 02-04 pass updated only `docs/system-architecture.md`. 03-05 added the Phase 3 inventory and corrected the Capture feature-section status word, but did not backfill the Phase 2 tree (scope). Backfill when docs are next touched. | open |
| 2 | 03-02 deviation 6 / 03-04 deviation 7 (03-05 documents, does not fix — SimCtlService outside the plan's files_modified) | `SimCtlService.run` prints `xcrun simctl <argv>` before every invocation (Phase-1 diagnostic). Phase 3 verbs put openurl URLs and defaults VALUES in argv, so the echo brushes the never-log-values/URLs prohibitions at the seam. Documented in `docs/system-architecture.md` § App Actions "Known logging gap". Fix = redact/parse-argv at the print site in SimCtlService. | open |
