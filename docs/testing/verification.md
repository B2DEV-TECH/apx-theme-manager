# Verification record — initial beta

Recorded on 2026-10-20 using synthetic applications created for this project.
These results describe the beta candidate. Runtime and authorization checks
passed; final media/publication verification and the release tag are tracked
separately. The machine-readable [test report](test-results.json) includes the
exact source hashes and confirms all six compiled package sources match Git.

## Environment and completed checks

| Check | Actual result |
| --- | --- |
| Runtime | Oracle AI Database 26ai Free 23.26.3.0.0; APEX 26.2.0; Windows |
| PL/SQL units | 26 blocks passed: 16 parser, 9 semantic, 1 authorization/input |
| Engine integration | 20 cases passed against the final completeness, history, actual item-parent and conservative mixed-grid controls |
| Negative suite | 12 cases passed, including simultaneous fresh-session recovery claims |
| Independent final-core check | Six valid package units, 26 blocks passed; actual-export identity/property probes and cross-actor fingerprint equality |
| Clean installation | Second schema/workspace; SQLcl core twice; actual SQL*Plus core twice, manager installation, configuration, registration and capture |
| Uninstall | Missing/wrong consent rejected; exact consent removed only APXTM objects; unrelated sentinel and APEX applications survived; reinstall passed |
| Portable sample | New destination app/offset, baseline capture and changed import with preserved IDs passed. That earlier fixture had 10 eligible differences; the final rendered fixture has 12 eligible and 2 DROPPED flags |
| Installer refusal | Existing app ID, wrong change confirmation and wrong saved offset rejected without source change |
| Actual failed installation | Latest fault app 116: native INSTALL returned ORA-20987; operation 32 FAILED; independently valid durable backup 39 survived |
| Fault-app recovery | Explicit owner reimport restored the synthetic fault application; no transactional rollback claim |
| Native browser workflow | All 16 checks passed with no JavaScript errors; actual selected repair, all-eligible repair, full restore, stale requests, unsafe selection and two-tab binding. A separate final rerun passed after parser hardening |
| Historical access | 20 database checks passed after guarded alias change/public application removal; historical reads remain authorized, live operations remain denied |
| Native historical access | 10 browser checks passed; six baseline/backup/proposal ZIP downloads matched stored hashes while the target alias changed or the target was absent |

The historical-read fix has passed both database and native-browser checks.
Application absence was deliberately induced with the guarded public removal
API; it was not observed as an outcome of the failed INSTALL. The owner then
reimported the saved trusted definition and verified its complete fingerprint.

Browser verification exposed overlapping columns in the original controlled
fixture. The independently authored fixture was corrected, and coupled-grid
checks now reject recognized overflow/overlap before creating a proposal. Both
actual sample pages render at baseline, changed, eligible-recovered and restored
states. Eligible repair leaves the two omitted row defaults for manual review;
only the separate full restore returns the complete baseline definition.

The complete independent installation report, exact source hashes and historical
findings are in [clean-install-result.json](clean-install-result.json). Earlier
failed findings remain recorded with their subsequent disposition; they are
not silently rewritten as passing runs.

## What the engine tests cover

The integration suite validates durable ZIP/source integrity, deduplication,
caller-transaction isolation, actual generated application context, unchanged
and controlled changed definitions, preview without modification, typed
confirmation, selected and all-eligible repair, validated backups, replay
rejection, stale comparisons/requests and separately authorized full restore.

The negative suite verifies denied roles, self/non-allowlisted targets,
workspace mismatch, immutable metadata, corrupted archives, expired tokens,
wrong APEX application/principal context, cross-actor fingerprints and actual
simultaneous requests on two fresh database connections. One import verifies;
the other claim is rejected. The successful request releases its public lock.

New snapshots also compare exported page, region, item and button identity sets
with public live metadata before persistence. Historical snapshot validation
checks its stored hashes/identity; it does not assume the current application
still has the baseline's component count.

## Observed issues and resulting controls

- APEX export after pending DML succeeded. ORA-01453 was not reproduced.
- INSTALL left metadata DML and locks pending. The engine completes its owned
  import transaction before independent re-export, without committing caller DML.
- Exporter comments differed by actor. Only the bounded generated `Exported By`
  comment is canonicalized; the actor remains in immutable provenance/audit.
- A template body could change under the same ID. This is now detected and
  remains ineligible for automatic mapping.
- Active theme selection in actual 26.2 exports occurs in generated
  `wwv_imp_workspace.create_flow`; a text-only actual-export test detects it.
- A changed theme file-cache counter generated false conflicts. Only that
  parsed counter is ignored in semantic theme context; artifact hashes retain it.
- A stale second preview previously overwrote shared FIXED history. Its own
  request now fails without changing the earlier verified outcome.
- Native full import retained existing ACL assignments. Divergent exported
  role/assignment state now rejects full restore before import. Scalar repairs
  preserve the test assignment and verify the entire resulting definition.
- A new direct-owner connection lacked APEX workspace package context for the
  public lock. Apply now selects the trusted workspace after authorization.
- Windows SQL*Plus nested `@@../...` includes did not resolve from the documented
  root directory. Public wrappers now use explicit repository-root includes.
- SQLcl 26.3 printed WHENEVER help and exited zero without configuring. Public
  scripts retain their guards; SQL*Plus is the verified administration client.
- A runtime export persisted its snapshot but left an empty HTTP response.
  The six export-capable POST actions now explicitly redirect through the public
  APEX API on success and failure; the final browser run verified nonempty pages
  or explicit redirects for every submitted export path.
- Native report column sorting overrode SQL history ordering. History reports
  now retain SQL descending order without a conflicting native column sort.
- Live identity authorization blocked backup access after target damage. A
  separate server-side READ-history boundary validates stored identity and
  integrity while all live-operation guards remain enforced.
- Actual item exports use `p_item_plug_id`. A regression now checks every sample
  item's exported region against public live metadata; moving a component
  between regions invalidates its scalar eligibility.
- Actual button-template and region-option/display-point aliases were missed
  by the first parser. They now have detection-only regression coverage.
- Items and BODY buttons can share a grid. Arbitrary mixed/interleaved rows are
  rejected for manual review, even if a proposed combination looks numerically
  valid. Only known trailing new-row/new-column BODY buttons are supported.

## Measured fixture and limits

One recorded baseline contained 112,448 CLOB characters and compressed to 46,353
ZIP bytes. The parser recognized 23 components. These are fixture measurements,
not capacity claims. Test step timings include validation/query overhead and
are not export-only benchmarks. Memory ceilings and large real applications
have not been benchmarked.

Only APEX 26.2.0 was available. APEX 24.2 is untested. No actual theme-switch
defect was reproduced; the demonstration uses independently authored synthetic
layout changes. Template/options/default recovery, missing-parameter synthesis,
component recreation and cross-copy ID mapping remain unsupported.

ACL preservation and its restore conflict were tested. The export explicitly
requests saved reports, notifications and translations, but independent runtime
preservation scenarios for those features and workflow instances remain
untested. Runtime table data, workspace users and external dependencies are
outside the definition backup. Hard process termination at every import phase
has not been exhaustively tested; an interrupted APPLYING request requires
manual inspection. Imports are not advertised as atomic or transactionally
reversible.

Oracle-generated SQL warns that modifying exports is unsupported. This project's
experimental transformer and public API usage do not create an Oracle support
contract for edited artifacts. See [compatibility](../compatibility.md) and
the [threat model](../security/threat-model.md).
