---
title: "APEX Theme Manager: Snapshot, Compare and Recover a Synthetic Layout"
description: "A real four-minute APEX 26.2 lab demonstration of validated snapshots, semantic comparison, selected repair, verified backups and a separate definition restore."
language: "en"
publishedAt: "2026-10-20"
category: "oracle-apex"
tags: ["Oracle APEX", "PL/SQL", "Open Source", "Layout Recovery"]
author: "geraldo-viana"
draft: false
videoUrl: "https://b2dev.tech/media/videos/apxtm/v0.1.0-beta/apex-theme-manager-demo.mp4"
poster: "/images/articles/apxtm/demo-thumbnail.png"
duration: "03:59"
github: "https://github.com/B2DEV-TECH/apx-theme-manager"
related: ["oracle-apex-theme-manager-layout-recovery"]
chapters:
  - { at: "00:00", label: "Snapshot. Compare. Recover." }
  - { at: "00:19", label: "A known baseline" }
  - { at: "00:49", label: "Controlled layout changes" }
  - { at: "01:07", label: "Meaning and eligibility" }
  - { at: "01:30", label: "Review one repair" }
  - { at: "02:00", label: "Backup. Apply. Verify." }
  - { at: "02:28", label: "Remaining eligible values" }
  - { at: "02:52", label: "A separate restore operation" }
  - { at: "03:23", label: "A reproducible community beta" }
---

This records actual automated browser execution in an isolated APEX 26.2.0
laboratory. Project Desk and Review Board are original synthetic applications;
the changes were deliberately authored in APEXlang. The experiment does not
claim that a native theme switch caused the demonstrated layout changes.

The video is edited into chapters with labeled reading pauses and unchanged
runtime screenshots. Narration uses an installed synthetic English voice.
English subtitles are burned into the video; the separate
[WebVTT captions](/media/videos/apxtm/v0.1.0-beta/demo.en.vtt) and
[MP4 download](/media/videos/apxtm/v0.1.0-beta/apex-theme-manager-demo.mp4)
are also available. The measured duration is 239.685 seconds.

Read the [engineering article](/blog/oracle-apex-theme-manager-layout-recovery)
for the parser, transaction boundaries, authorization model and known limits.
The [source and installation guide](https://github.com/B2DEV-TECH/apx-theme-manager)
let you repeat the experiment in your own authorized development workspace.
Only APEX 26.2.0 was tested. This is an independent B2DEV TECH beta, not an
official Oracle product.

## Transcript

### Snapshot. Compare. Recover.

APEX Theme Manager captures application definitions, compares layout properties, and recovers a tested subset of compatible values.

This is an automated browser recording in a disposable APEX 26.2 laboratory. The pages and layout changes are synthetic.

### A known baseline

Project Desk and Review Board are the original sample pages. Notice the six-column fields and side-by-side regions.

In the manager, I select the registered sample and capture a named baseline. The snapshot is persisted and its source and ZIP hashes are verified.

A snapshot contains an application definition. It is not a backup of table rows, workspace accounts or external dependencies.

### Controlled layout changes

The changed fixture is imported through the public installation API, retaining the sample's component identities.

The project field is wider, the contact region is narrower, and several columns have moved. These edits were deliberately authored in APEXlang.

### Meaning and eligibility

Comparison identifies the component, property, baseline value and current value. It compares recognized definitions rather than SQL line numbers.

Twelve explicit grid changes are eligible. Two row flags disappeared at their defaults and remain detection-only. All eligible never means every difference.

### Review one repair

I select only the project field's column span. Preview records the exact selection and proposed definition without modifying the application.

The operation belongs to this actor and this application state. A later edit invalidates it. The proposed ZIP can be downloaded for inspection.

An incorrect confirmation is rejected. The intended target must be confirmed explicitly before the engine can apply the reviewed operation.

### Backup. Apply. Verify.

Apply rechecks permission and freshness, acquires the public application lock, and persists a validated backup before importing.

A normal import return is not sufficient. The engine independently re-exports the application and requires the complete normalized definition fingerprint to match.

The selected field is back to six columns. Other changes remain because only one property was selected.

### Remaining eligible values

A fresh comparison lets me preview and apply the remaining eligible grid values. Each operation has its own verified backup and audit outcome.

The omitted row flags still require review. Template references, template options and theme defaults are also detection-only in this beta.

### A separate restore operation

Full definition restore is separate. It requires stronger permission, identical exported ACL assignment state, and the exact restore confirmation.

This replaces the definition with the snapshot. It can replace unrelated application work too, so it is different from selected layout repair.

The restored sample is independently verified. Application imports are not advertised as atomic or transactionally reversible.

### A reproducible community beta

The repository contains the original source, portable installers, synthetic fixtures, security model and recorded test evidence.

Recovery starts disabled. The manager's Modify Other Applications authority is workspace-wide; use a dedicated trusted development workspace.

Only APEX 26.2.0 was tested. Modified SQL exports are not an Oracle-supported transformation contract. Read the limits before evaluating this independent B2DEV TECH beta.

