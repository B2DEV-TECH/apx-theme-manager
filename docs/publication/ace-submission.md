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
Free 23.26.3.0.0: 26 real SQL test blocks (16 parser, nine semantic, one security),
20 integration checks and 12 negative checks passed after reviewer fixes.
Recorded evidence also has 20 independent history checks,
16 main browser checks and ten browser history checks passing. Both sample pages
were captured at four workflow states; browser checks verified three ZIP hashes,
two-tab operation binding and zero JavaScript errors.
A separate clean workspace exercised installation, selected recovery and removal
consent with different destination IDs. Article publication and the beta release
tag remain pending; the demonstration MP4 is public. The article makes no other-version compatibility claim or
reproduced theme-switch defect claim. It states explicitly that public APIs do
not make modified generated SQL an Oracle-supported transformation contract.

## Open-source project

**Name:** APEX Theme Manager  
**Public development repository (beta release pending):**
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
missing defaults and uncertain identities are detection-only. A bounded
twelve-column grid-plan check rejects recognized overflow and same-row/sibling
overlap. New captures cross-check component identity sets against public live
metadata; history authorization permits stored downloads without a healthy live
target. Whole-artifact fingerprints retain the generated cache counter; only the
recognized `Exported By` header comment is normalized across actors, with the real actor
retained in immutable audit records. The generated Oracle SQL warning about
unsupported file modification remains a material limitation. Generated Oracle
components retain their own applicable terms and notices.
Mixed item/BODY-button rows remain manual except known numeric trailing buttons
with new-row/new-column behavior. Actual item parents are verified against
public metadata; pure template name/class models do not certify live cross-theme
equivalence when inherited Universal Theme bodies are absent.

## Video

**Proposed title:** APEX Theme Manager: A Verified Layout Recovery Workflow  
**Language:** English captions; synthetic English narration  
**Status:** Public MP4 verified anonymously; Chrome playback passed  
**URL:**
`https://b2dev.tech/media/videos/apxtm/v0.1.0-beta/apex-theme-manager-demo.mp4`  
**English captions:**
`https://b2dev.tech/media/videos/apxtm/v0.1.0-beta/demo.en.vtt`  
**Measured duration:** 239.685 seconds (3:59.685)  
**Captions / chapters:** 23 caption cues / nine chapters  
**Public verification date:** October 20, 2026  
**Editing disclosure:** Actual automated browser footage edited into chapters
with labeled reading pauses and unchanged runtime screenshots; no APEX screens
were reconstructed. The pages and layout changes are synthetic. Narration uses
an installed Windows synthetic English voice. Captions are burned into the MP4;
the optional WebVTT track is not enabled by default.

**Suggested summary:**

A demonstration on the original two-page synthetic APEX application: capture a
baseline, apply controlled layout changes, compare eligible and ineligible
differences, preview one selected repair, confirm the target, inspect the
verified result and backup, then demonstrate remaining eligible recovery and
the separate restore workflow with compatible ACL state. The edited recording
uses actual automated browser footage, labeled reading pauses, synthetic English
narration and captions. It is not a reproduced Oracle theme-switch defect.

Anonymous hosting verification returned HTTP 200 for the exact 8,547,836-byte
MP4, HTTP 206 for a byte-range request and HTTP 200 for the exact WebVTT. See
`media/publication-evidence.json` for the SHA-256 and recorded checks.

## Before manual submission

Verify that the article is public at its final canonical URL and its author,
publication date and source links are correct. Confirm the repository/license,
actual release status and public test evidence. Recheck video playback and the
published MP4/caption URLs at manual submission time.
Ensure all media is synthetic and free of credentials, connection details and
unrelated application content. Review article, project and video as separate
materials without assuming how the program counts them.

Keep the measured baseline metadata aligned with the final article: 112,448
CLOB characters, a 46,353-byte ZIP and 23 recognized components in the recorded
fixture. Fourteen real layout differences comprise twelve eligible numeric changes
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
- The article now has six active real screenshot blocks and the verified public
  MP4/caption URLs. Copy the six screenshot assets and video poster unchanged to
  their referenced site paths, then check native rendering before clearing draft.
- Do not add a duplicate lab entry. This handoff does not edit, publish or deploy
  the website, and does not submit anything to an external portal.
