---
name: "APEX Theme Manager"
description: "Original Oracle APEX and PL/SQL project for definition snapshots, semantic layout comparisons and controlled recovery of a tested scalar subset."
language: "en"
status: "experimental"
technologies: ["Oracle APEX", "PL/SQL", "Oracle Database", "APEXlang", "SQLcl"]
programmingLanguage: "PL/SQL"
license: "Apache 2.0"
repository: "https://github.com/B2DEV-TECH/apx-theme-manager"
docs: "https://github.com/B2DEV-TECH/apx-theme-manager/tree/main/docs"
related: ["oracle-apex-theme-manager-layout-recovery"]
draft: true
featured: false
---

APEX Theme Manager is an independent B2DEV TECH community application for
snapshotting application definitions, comparing layout attributes and recovering
selected compatible values while preserving the approved current definition's
unrelated source. The runtime is native APEX and PL/SQL.

The engineering focus areas:

- **Definition snapshots** stored as UTF-8 ZIP artifacts with source/archive
  SHA-256 hashes, provenance and validation.
- **Semantic comparison** for pages, regions, items, buttons and theme/template
  context, with observed differences separate from recovery eligibility.
- **Controlled recovery** for recognized numeric grid and row/field scalars
  explicitly present in both definitions. Template/options mappings remain
  detection-only. A bounded twelve-column plan rejects recognized overflow and
  same-row/sibling overlap. Shared/interleaved item/BODY-button rows stay manual;
  only known numeric trailing buttons with new-row/new-column behavior are supported.
- **Preview and verification** with actor/target binding, a single-use token,
  freshness checks, public APEX application locks, a durable validated backup and
  a complete normalized post-import export fingerprint check.
- **Explicit authority** through owner-managed principals and target registration,
  with recovery disabled by default and a separate full-definition restore role.
  Restore rejects divergent exported ACL role/assignment state for manual review.
- **Historical access** independent of live-app availability, so authorized
  backup/proposal downloads remain possible after target deletion or alias change.

The recorded synthetic lab run uses APEX 26.2.0 and Oracle AI Database 26ai Free
23.26.3.0.0: 26 real SQL blocks, 20 integration checks and 12 negative checks
passed after reviewer fixes. Recorded evidence also contains
20 independent history checks, 16 main browser checks and ten browser history
checks passing. The corrected two-page fixture has 14 differences: 12 eligible
and two omitted row flags. Actual captures show both
pages at baseline, changed, eligible-recovered and restored states. Browser
checks verified three ZIP hashes, operation binding across tabs and no JavaScript
errors. A separate clean workspace exercised different destination IDs. The
beta includes a real four-minute demonstration with English captions and
identified synthetic narration. These results do not establish
compatibility with APEX 24.2 or other versions. The sample demonstrates
controlled APEXlang-authored layout edits, not an observed theme-switch defect.
Actual item parents are compared with live metadata; inherited Universal Theme
bodies remain unavailable, so pure name/class models certify no live cross-theme
equivalence.

The manager export declares workspace-wide **Modify Other Applications**
authority. Review the threat model before importing it into a dedicated trusted
development workspace. An import can partially commit; there is no atomic
rollback promise. Snapshots exclude runtime table data, users and external
dependencies.

Only the generated `Exported By` header comment is normalized across actors;
the actual actor remains in immutable audit records. A generated theme cache
counter is excluded from semantic theme-context comparison, while the complete
artifact fingerprint retains it. Oracle's generated SQL warns that file
modification is unsupported: the project's bounded transformer remains an
independent beta, and public APIs do not confer Oracle support on edited SQL.

The original source is Apache-2.0; generated Oracle components retain their
applicable terms and notices. Node.js and browser tooling are development-only.

<!-- Publication gate: copy to content/projects/apx-theme-manager.md only after
public source/release checks. Keep draft:true until approved for publication.
Optional screenshot, after the actual native capture is copied and verified on the site:
screenshot: "/images/articles/apxtm/manager-overview.png"
Set latestRelease only after the actual beta tag is published and verified.
Do not create a duplicate lab entry for this same project.
-->
