# Verification record — initial beta

Recorded on 2026-10-20 using synthetic applications created for this project.
This is working-tree evidence. **Release gates remain open while the native
browser workflow and final media/publication checks are in progress.**

## Environment and completed checks

| Check | Actual result |
| --- | --- |
| Runtime | Oracle AI Database 26ai Free 23.26.3.0.0; APEX 26.2.0; Windows |
| PL/SQL units | 21 blocks passed: 13 parser, 7 semantic, 1 authorization/input |
| Engine integration | 18 cases passed before the final completeness guard; final rerun pending |
| Negative suite | 12 cases passed before the final completeness guard; final rerun pending |
| Independent final-core check | Six valid package units, 21 blocks passed, actual-export active-theme detection and cross-actor fingerprint equality |
| Clean installation | Second schema/workspace; SQLcl core twice; actual SQL*Plus core twice, manager installation, configuration, registration and capture |
| Uninstall | Missing/wrong consent rejected; exact consent removed only APXTM objects; unrelated sentinel and APEX applications survived; reinstall passed |
| Portable sample | New destination app/offset, baseline capture, changed import with preserved IDs: 10 eligible grid differences and 2 DROPPED flags |
| Installer refusal | Existing app ID, wrong change confirmation and wrong saved offset rejected without source change |
| Actual failed installation | Deliberately invalid numeric attribute in a new synthetic fault app: native INSTALL returned ORA-20987; operation FAILED; validated durable backup survived |
| Fault-app recovery | Explicit owner reimport restored the synthetic fault application; no transactional rollback claim |
| Native browser workflow | Persisted snapshot + empty HTTP response isolated to runtime export; explicit POST/redirect/GET passes capture; complete rerun pending |

Open release issues: complete the native workflow/video, and retain authorized
backup/history access when a failed import leaves the target absent or its
identity changed. That read-path fix is in progress; live operations must still
reject an absent or changed target.

Visual browser verification also exposed overlapping columns in the controlled
changed fixture. Its layout must be corrected and the expected differences
updated before a demonstration/release can be presented as working.

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
