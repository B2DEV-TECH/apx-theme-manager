# Release and publication report

Verified October 20, 2026. This is an independently developed community beta,
not a stable or general-purpose theme migration guarantee.

## Public deliverables

| Deliverable | Verified location / result |
| --- | --- |
| Source and README | [B2DEV-TECH/apx-theme-manager](https://github.com/B2DEV-TECH/apx-theme-manager) |
| Versioned release | [v0.1.0-beta](https://github.com/B2DEV-TECH/apx-theme-manager/releases/tag/v0.1.0-beta), explicitly a prerelease |
| Release commit | `d9ad9b3dee4a3bd865202289ed75a49302f4a90a` |
| Installation | [Portable installation guide](../installation/README.md), full source ZIP and individual native exports |
| Demonstration application | [Original two-page lab and baseline/changed exports](../../samples/layout-lab/README.md) |
| Article | [Beyond Theme Switching: Building a Layout Recovery Engine for Oracle APEX](https://b2dev.tech/blog/oracle-apex-theme-manager-layout-recovery), Geraldo Viana Jr.; native 15-minute reading estimate |
| Video page | [Recorded synthetic layout recovery workflow](https://b2dev.tech/engineering/videos/apex-theme-manager-layout-recovery-demo), transcript and nine chapters |
| MP4 | [239.685-second actual laboratory recording](https://b2dev.tech/media/videos/apxtm/v0.1.0-beta/apex-theme-manager-demo.mp4), English subtitles and identified synthetic English narration |
| Website project entry | [APEX Theme Manager](https://b2dev.tech/open-source/apx-theme-manager) |
| Manual ACE information | [Separate article, project and video summaries](../publication/ace-submission.md); nothing submitted automatically |

All nine GitHub release assets were downloaded anonymously and matched their
local SHA-256 values. The portable source ZIP has 247 entries, including the
installer, native application, packages, fixtures and test evidence; excluded
credentials, `.local`, Git metadata and development dependencies are absent.
See [release verification](release-evidence.json).

The website source was published through its existing Git/Next.js/Cloudflare
workflow. The engineering video template was activated as a native dynamic
static route; its visual implementation was preserved. The draft visibility
test was corrected to allow published videos while still excluding drafts.
Public checking also found and corrected a missing PNG content type on the
native extensionless Open Graph response. No separate visual system was added.

## Architecture and security

The runtime is Oracle Database + Oracle APEX. `APXTM_PARSE`, `APXTM_DIFF` and
`APXTM_ENGINE` implement bounded parsing/patching, structured comparison and
the authorized operation lifecycle. Nine tables hold configuration, principals,
registered applications, deduplicated ZIP artifacts, immutable snapshots,
comparisons, differences, operations and audit. Three triggers protect snapshot
and artifact updates and append-only audit. Six package units are VALID.

The manager has eight functional native APEX pages plus APEX Accounts login.
Node.js/Playwright, SQLcl authoring tools and FFmpeg are optional development or
media tooling, not runtime services.

Recovery starts disabled. Server-side roles, explicit target registration,
workspace/schema/alias checks, self-exclusion, typed target confirmation,
actor-bound expiring single-use requests, source freshness, public application
locks and a unique active-operation constraint restrict project operations.
Every apply persists a validated backup before installation and independently
re-exports the complete normalized definition before declaring VERIFIED.
Historical reads retain authorization and integrity checks if a target vanishes.

The APEX **Modify Other Applications** capability remains workspace-wide; these
application controls are not a platform sandbox. A schema owner, DBA, same lock
owner or external import process is outside the claimed concurrency boundary.
Imports may partially commit, and no transactional application rollback is
promised. Full restore requires its own role/confirmation and matching exported
ACL state. Backups contain sensitive executable application definitions, not
runtime table data, workspace accounts or external dependencies.

## Executed verification

| Check | Actual result |
| --- | --- |
| PL/SQL | 26 blocks passed: 16 parser, nine semantic, one authorization/input |
| Engine integration | 20 passed, including actual exported item parents versus public live metadata |
| Negative tests | 12 passed, including simultaneous fresh-session claims and replay/authorization rejection |
| Independent history suite | 20 passed after deliberate alias change/removal of a newly allocated synthetic target |
| Native workflow | 16 passed; final rerun after parser hardening, no JavaScript errors |
| Native historical access | 10 passed; six hash-verified baseline/backup/proposal downloads with changed/absent live target |
| Independent review | 26 SQL blocks and 11 focused actual-export/mixed-grid probes passed |
| Actual installation failure | Native ORA-20987; FAILED operation retained a verified backup; explicit owner reimport succeeded |
| Independent installation | Separate schema/workspace, different destination IDs/offsets, repeated core installation and guarded uninstall; unrelated sentinel/application survived |
| Site | 44 tests, type checks and static build passed; lint had zero errors and one pre-existing ignored scratch warning |
| Public website | 11 desktop/mobile/discovery checks passed; seven images matched exact published hashes; canonical, author/date and PNG Open Graph response verified |
| Public media | MP4 hash matched, byte-range HTTP 206 supported, 23 caption cues loaded in the deployed article; Chrome decoded audio/video and sought nine chapters |

The complete raw-derived summaries and source hashes are in
[test-results.json](../testing/test-results.json),
[independent review](../testing/final-review.json),
[verification notes](../testing/verification.md) and
[publication evidence](../publication/publication-evidence.json). Historical
failures remain documented with their correction; they were not rewritten as
passing tests.

Only **APEX 26.2.0**, on Oracle AI Database 26ai Free **23.26.3.0.0**, was tested.
The sample has 14 known differences: 12 eligible scalars and two omitted row
flags requiring review. Both sample pages rendered at baseline, changed,
eligible-recovered and fully restored states. The video uses actual automated
browser footage and unchanged runtime screenshots, with labeled reading pauses.
No native theme-switch defect was reproduced or claimed.

The original lab's sample was returned to its validated baseline using a new
VERIFIED restore and durable backup. Both laboratory recovery policies are now
DISABLED, with zero enabled recovery targets, zero APPLYING operations and zero
invalid project objects. Histories remain available. See
[final laboratory state](../testing/final-lab-state.json).

## Remaining unsupported or untested work

- APEX 24.2 and releases other than exact 26.2.0 are untested.
- Automatic template/option/theme-default mapping, absent-parameter synthesis,
  component recreation and cross-copy identity mapping are unsupported. Actual
  inherited Universal Theme bodies were absent; name/class mapping has only
  bounded unit-model coverage, without certified live cross-theme equivalence.
- Arbitrary shared/interleaved item/BODY-button rows require manual review;
  only known trailing new-row/new-column BODY buttons pass the beta boundary.
  Grid checks are not a general visual proof.
- Saved-report, notification and translation preservation flags are requested,
  but independent preservation scenarios remain untested. Runtime workflow
  instances and external dependencies are outside this backup scope.
- Large real application memory/performance limits and hard process termination
  at every import phase have not been exhaustively tested. Interrupted imports
  require explicit owner inspection and documented recovery.
- Oracle-generated SQL warns that modified exports are unsupported. This
  independent tested transformer does not create an Oracle support contract.

No publication or recording blocker remains. These explicit limits are the
reason for the beta label. Oracle ACE eligibility, contribution classification
and any credit are decisions for the program; submission remains manual.
