# Actual synthetic workflow recording and reproduction

The original synthetic sample was recorded on October 20, 2026. The edited
MP4 is 239.686 seconds (1600 × 1200, H.264/AAC), with 23 English captions and
synthetic narration from an installed Windows voice. It uses actual automated
APEX 26.2.0 execution and unchanged runtime screenshots, with labeled reading
pauses. No APEX screens were reconstructed. There is no music or human-voice
claim. Public hosting is verified separately from local production.

The successful source run passed all 16 browser checks without JavaScript
errors. Local Chrome decoded audio/video, loaded all 23 WebVTT cues and sought
successfully through all nine chapters. See [edit manifest](demo-edit-manifest.json)
and [playback evidence](demo-playback-evidence.json) for hashes and measurements.

The following script and shot list also document how to repeat the recording.
Use only the original synthetic sample in an authorized disposable laboratory.

The scenario demonstrates controlled APEXlang-authored layout changes. Do not
describe it as a recording of a reproduced APEX theme-switch defect.

## Preparation

- Finish the current test run and reserve the sample for recording; do not run
  integration suites or manual imports concurrently.
- Confirm the manager/target/workspace identities, installed versions, baseline
  fixture, actor role and enabled development recovery for that target.
- Complete all fixture imports in their owning connection before starting the
  manager workflow. Confirm no inherited metadata transaction or unrelated lock
  is holding the target.
- Keep credentials, session IDs, tokens, connection details and unrelated apps
  out of the recording. Use only fictional data and synthetic test accounts.
- Record a readable desktop viewport and capture mobile behavior separately if
  included. Inspect text at the intended playback size.

The optional original-Windows-lab automation is:

```text
node scripts/apex-browser-workflow.mjs --disposable-lab --record
```

It overwrites the guarded original sample. Review its fixed lab endpoint, Chrome
path and source IDs before running; it is not a generic recording command for
another installation. It writes actual Playwright footage and timing evidence
under ignored `.local/ui-agent-workflow/`. Automated browser footage needs an
explicit automation label and does not imply narration was recorded.

## Capture sequence

| Stage | Show | Narration point / evidence |
| --- | --- | --- |
| Context | Manager name and exact APEX version, fictional two-page sample | “This is a controlled synthetic layout-recovery experiment.” |
| Baseline | Project Desk and Review Board; capture a named snapshot | “This stores a definition, not table data or external dependencies.” |
| Controlled change | The independently authored changed fixture, then actual changed pages | Explain the known grid changes and omitted row defaults; do not edit source invisibly and present it as an observed defect |
| Comparison | Component/property, baseline/current values, classification and eligibility | “Detection and automatic repair are separate decisions.” |
| Selected preview | One eligible scalar, target application, expected/proposed fingerprints | “Preview changes no application; a later edit invalidates it.” |
| Confirmation | Deliberately enter the actual target ID confirmation | Avoid displaying the one-use token or browser developer tools |
| Result | VERIFIED operation, durable backup reference, actual target property | Explain the independent normalized full-export check, not merely the API return |
| Remaining eligible | Compare again, preview all remaining eligible grid differences, apply | “All eligible does not include the DROPPED row flags.” |
| Restore | Separate full-definition restore preview and confirmation | State that matching ACL assignment state is required; restore is another import and does not back up runtime data |
| Close | Actual final state, source/testing documentation | State the exact tested version, workspace-wide manager authority and remaining limitations |

If a rejection is included, show its real trigger and unchanged target. An
incorrect confirmation, stale preview or replay should not be simulated with
edited captions over an unrelated successful operation. Keep failures visible
when they explain a result, and distinguish a retake from a continuous run.

## Short narration draft

“APEX Theme Manager snapshots an application definition and compares recognized
layout properties. Here, Project Desk and Review Board are synthetic pages; the
changes were deliberately authored in APEXlang.

“The comparison shows both the changed value and whether the engine can repair
it. This grid span is explicit in both exports, so I can select it. A row flag
that disappeared at its default is detection-only.

“Preview binds the selection to the current application state. Apply checks it
again, validates and saves a backup, imports through the public API, then
independently re-exports the definition. VERIFIED requires the approved
normalized fingerprint, not just a successful import call.

“The full restore path is separate. It requires stronger permission and matching
ACL assignments. Imports can partially commit; there is no atomic rollback
promise. The manager has workspace-wide Modify Other Applications authority;
use a dedicated trusted development workspace. Only APEX 26.2.0 has been tested
in this lab.”

Adjust narration to what the final footage actually shows. Omit unrecorded
actions and do not retain a success sentence if a final check fails.

## Local editing tools

`media/narration.json` is the exact spoken/caption text. The optional
`scripts/narrate-video.ps1` uses an already installed Windows English voice;
it downloads nothing. `scripts/build-demo-video.mjs` requires FFmpeg, ffprobe
and a Playwright-compatible browser. Pass their executable paths through
`--ffmpeg`, `--ffprobe` and `--chrome` if they are not on the normal path.
It requires a passing recorded run, checks source files before encoding,
preserves actual-time video speed and writes its output under ignored `.local/`.
The checked-in captions, thumbnail, chapters and edit manifest are small public
production artifacts; raw and intermediate recordings remain excluded.

## Editing and publication

Review the raw footage first. Record the measured duration and exact edits.
Disclose cuts and accelerated waits in the opening card/caption; label automation
and any retaken sequence. Add accurate English captions and verify their timing.
Do not describe a silent Playwright recording as original spoken narration.

Export a browser-compatible video, verify playback, readable controls, captions,
audio (if present), thumbnail and final encoding. Use real runtime screenshots;
do not replace missing steps with mockups. The reserved article media path is
`/media/videos/apxtm/apex-theme-manager-demo.mp4`; it is not a claim that the file
exists or is published. Activate article media links only after verification.

Keep raw/intermediate captures, credentials and private transcripts out of Git.
Public screenshots/video must contain only reviewed synthetic content. If a
complete recording cannot be produced, publish this as a recording kit with the
blocker stated; do not claim the kit is a finished demonstration video.
