# Manual contribution information

Prepared for Geraldo Viana Jr. to review and enter manually if appropriate.
Nothing has been submitted to Oracle ACE, and no points or eligibility outcome
is asserted. Use the portal's current fields and rules when submitting; the
suggested labels below are descriptive, not claims about its present form.

## Article

**Title:** Beyond Theme Switching: Building a Layout Recovery Engine for Oracle APEX

**Author:** Geraldo Viana Jr.  
**Language:** English  
**Planned publication date:** October 20, 2026  
**Publisher:** B2DEV TECH  
**Topic:** Oracle APEX / PL/SQL / application layout recovery  
**Intended URL, not yet verified live:**
`https://b2dev.tech/blog/oracle-apex-theme-manager-layout-recovery`

**Suggested summary:**

An original technical article and open-source Oracle APEX/PLSQL project showing
how to capture validated application definitions, compare semantic layout
attributes and recover a tested scalar subset. It explains a bounded SQL-export
parser, explicit eligibility, stale/replay rejection, validated pre-import
backups, public APEX 26.2 locking/install APIs and independent verification of
the complete normalized post-import definition. The article covers native APEX
theme/subscription workflows, observed import transaction and ACL preservation
behavior, narrow generated-header normalization and workspace-wide authority.
Results come from synthetic fixtures on APEX 26.2.0 and Oracle AI Database 26ai
Free 23.26.3.0.0: 21 real SQL test blocks (13 parser, seven semantic, one security),
18 integration checks and 12 negative checks passed. A separate clean workspace
also exercised installation, selected recovery and removal consent with different
destination IDs. Final browser workflow and recording verification remain
pending. The article makes no other-version compatibility claim or reproduced
theme-switch defect claim. It states explicitly that public APIs do not make
modified generated SQL an Oracle-supported transformation contract.

## Open-source project

**Name:** APEX Theme Manager  
**Repository URL to verify after publication:**
`https://github.com/B2DEV-TECH/apx-theme-manager`  
**License for original source:** Apache-2.0  
**Technologies:** Oracle APEX, PL/SQL, Oracle Database; APEXlang/SQLcl for sample authoring  
**Release:** Pending final gates; intended initial label `v0.1.0-beta` only if
the tag and distributable are actually published.

**Suggested summary:**

An independent B2DEV TECH community application for immutable definition
snapshots, semantic layout comparison and controlled selected/all-eligible
recovery, with a separate full-definition restore workflow requiring matching
exported ACL role/assignment state. The repository
includes original PL/SQL packages, native APEX exports, an independently authored
synthetic sample, portable installer scripts, security documentation and
reproducible tests. Default recovery is disabled. Template/options mappings,
missing defaults and uncertain identities are detection-only. Whole-artifact
fingerprints retain the generated cache counter; only the recognized
`Exported By` header comment is normalized across actors, with the real actor
retained in immutable audit records. The generated Oracle SQL warning about
unsupported file modification remains a material limitation. Generated Oracle
components retain their own applicable terms and notices.

## Video

**Proposed title:** APEX Theme Manager: A Verified Layout Recovery Workflow  
**Language:** English captions/narration to confirm after reviewing the recording  
**Status:** Recording and final media verification pending  
**URL:** Pending; do not submit a reserved path as an existing video  
**Reserved media path:**
`/media/videos/apxtm/apex-theme-manager-demo.mp4`  
**Duration, publication date and editing disclosure:** Pending actual media

**Draft summary to use only if the final recording shows this workflow:**

A demonstration on the original two-page synthetic APEX application: capture a
baseline, apply controlled layout changes, compare eligible and ineligible
differences, preview one selected repair, confirm the target, inspect the
verified result and backup, then demonstrate remaining eligible recovery and
the separate restore workflow with compatible ACL state. The recording should retain failed/rejected
actions when relevant and disclose cuts, accelerated waits and captions. It
must not be described as a reproduced Oracle theme-switch defect.

## Before manual submission

Verify that the article is public at its final canonical URL and its author,
publication date and source links are correct. Confirm the repository/license,
actual release status and public test evidence. For video, replace every pending
field with the measured facts and a playable public URL; otherwise omit it.
Ensure all media is synthetic and free of credentials, connection details and
unrelated application content. Review article, project and video as separate
materials without assuming how the program counts them.

Keep the measured baseline metadata aligned with the final article: 112,448
CLOB characters, a 46,353-byte ZIP and 23 recognized components in the recorded
fixture. Twelve real layout differences comprise ten eligible numeric changes
and two DROPPED row flags. The active-theme detection test changed exported text
from theme 42 to 43; it did not import another theme. Do not describe that test
as an observed runtime theme-switch defect.

## Native site handoff

- Copy `article.md` to
  `content/articles/en/oracle-apex-theme-manager-layout-recovery.md` when ready.
  The filename determines the slug; do not add a slug field to frontmatter.
- Copy `project-entry.md` to `content/projects/apx-theme-manager.md`.
- Both files intentionally have `draft: true`. The existing loader excludes
  drafts from public lists, routes, search and feeds. Remove that flag only after
  source, release, media and site rendering gates pass.
- `oracle-apex` is the existing category. The author slug `geraldo-viana`
  resolves to Geraldo Viana Jr. Projects support `experimental` status.
- Native Markdown supports GFM tables, code-fence filenames, callout directives
  and Mermaid. Mermaid is enhanced in the browser, so check the rendered page.
- The current canonical article route is `/blog/<slug>`; the older
  `/engineering/articles/<slug>` route redirects there. Keep public URLs aligned
  with the actual deployed site.
- Activate the six commented screenshot insertion points and video block only
  after the referenced artifacts exist and have been reviewed. Add duration,
  captions and editing disclosure from the recording, not from this draft.
- Do not add a duplicate lab entry. This handoff does not edit, publish or deploy
  the website, and does not submit anything to an external portal.
