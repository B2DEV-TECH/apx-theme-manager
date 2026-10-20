# Runtime screenshots

These are actual screenshots of the authenticated original manager application,
captured on 2026-10-20 with Chrome and Playwright against Oracle APEX 26.2.0.
The main workflow uses disposable APXTM_LAB applications 104/105. The two history
images use the separate APXTM_VERIFY manager 106 and synthetic fixture 115. They
are not mockups.

`overview-desktop.png`, `application-desktop.png`, `comparison-desktop.png`,
`preview-desktop.png`, `selected-verified-desktop.png`, `verified-desktop.png`,
`restore-preview-desktop.png`, `restore-verified-desktop.png` and
`audit-desktop.png` show the actual manager workflow at a 1440×1080 viewport.
`application-mobile.png`, `comparison-mobile.png` and `guide-mobile.png` use
390×844. Wide tables scroll within their own region.

The `sample-baseline`, `sample-changed`, `sample-recovered-eligible` and
`sample-restored-definition` images show the original synthetic Project Desk.
Their `-review` counterparts show its second native Review Board page. Both
pages rendered successfully at all four stages. The changed fixture deliberately
changes valid grid proportions; it is not evidence of an Oracle theme defect.

Eligible recovery leaves two dropped explicit row flags untouched, so its
Project Desk screenshot still has different row placement from the baseline.
The separate full-definition restore screenshot shows the saved row placement.

[`workflow-evidence.json`](workflow-evidence.json) records 16 passing browser
checks, 14 observed differences (12 eligible and two dropped), verified backup
operations, three byte-identical ZIP download hashes and same-session two-tab
binding. [`read-only-evidence.json`](read-only-evidence.json) records the seven
desktop, mobile and anonymous-download checks. Timing metadata refers to an
automated browser run using this synthetic scenario; the private raw recordings
are not included in this directory.

`alias-changed-history.png` and `missing-target-history.png` show the native
Activity page while fixture 115 has a different live alias and while it has zero
live application rows, respectively. [`history-access-evidence.json`](history-access-evidence.json)
records ten passing browser/owner checks and six byte-identical ZIP downloads.
The baseline, real pre-import backup and proposed definition remained available
through native links in both states. Live controls excluded the fixture. An
explicit owner import then restored its exact saved definition; policy, named
principals and recovery flags remained unchanged.

The screenshots include synthetic test history. Displayed counts reflect the
captured lab state; installation starts with an empty registry and disabled
modification policy. The optional `scripts/apex-browser-smoke.mjs` reproduces the
read-only browser checks using the ignored local lab configuration. The guarded
`scripts/apex-browser-workflow.mjs --disposable-lab --record` reproduces the
workflow and records actual browser video when Playwright's FFmpeg is installed.
