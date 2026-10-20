# Changelog

## v0.1.0-beta — release candidate

Prepared on 2026-10-20. Publication and final verification are pending. This
entry describes the intended initial beta scope; it does not announce a live
tag, downloadable release, article or video.

### Added

- Original `APXTM_PARSE`, `APXTM_DIFF` and `APXTM_ENGINE` packages for bounded
  SQL-export parsing, semantic comparison and authorized snapshot/recovery.
- Definition ZIP artifacts, source/archive integrity checks, provenance,
  immutable snapshot/artifact updates and append-only application audit.
- Selected/all-eligible recovery preview, expiring single-use tokens, fresh
  target checks, validated pre-import backup and independent result verification.
- Separate full-definition restore preview and confirmation, restricted to
  matching snapshot/current ACL assignment state.
- Native Universal Theme manager with eight functional pages and APEX Accounts
  login; original two-page synthetic sample and APEXlang authoring sources.
- Owner-driven install/configure/register/recovery-policy scripts, version 1
  package reinstall, guarded uninstall, security and contribution guidance.
- Real database and browser test entry points, compatibility documentation and
  a recording script for a reproducible synthetic demonstration.
- Actual native overview/comparison/preview/result captures and both sample
  pages at baseline, changed, eligible-recovered and full-restored states.

### Safety and preservation decisions

- Recovery is disabled by default. The initial principal and target registries
  are empty; the direct owner authorizes them explicitly.
- Automatic repair covers only bounded recognized grid/row/field scalars
  explicitly present in both definitions. Template references/options/defaults
  are detection-only; missing or ambiguous identity is not guessed.
- Region display column is an eligible grid position. A pure bounded grid-plan
  check rejects recognized twelve-column overflow and same-row/sibling overlap;
  coupled position/span changes must form a valid recognized plan.
- Mixed item/BODY-button rows are manual except known numeric trailing buttons
  with new-row/new-column behavior; safe coupled mixed rows are also
  rejected rather than inferred.
- Actual APEX 26.2 parameter names now recognized include item `p_item_plug_id`,
  button `p_button_template_id`, and region `p_region_template_options` /
  `p_plug_item_display_point`; legacy aliases remain accepted. A live-export
  regression compares item parents with public metadata.
- Inherited Universal Theme bodies were absent even from the no-subscriptions
  export probe. Template name/class matching remains a pure unit model, with
  no certified live cross-theme equivalence.
- Actual browser rendering exposed overlap in the earlier changed fixture.
  Corrected region/item columns produce 14 real differences: 12 eligible and
  two omitted row flags left for manual review.
- Capture explicitly requests ACL assignments, saved reports, notifications and
  translations. Supporting-object installation is excluded.
- Full restore does not promise to roll back ACL assignments: different
  snapshot/current assignment state requires rejection before import.
- Source fingerprints normalize only the generated `Exported By` comment for
  cross-actor exports; archive hashes continue checking exact ZIP bytes.
- The engine completes its owned import transaction before independent export.
  Caller business DML is outside that autonomous transaction, and atomic
  application rollback is not promised.
- Native full POST submissions use explicit public redirects after success and
  rejection. This resolves the observed empty HTTP response after runtime
  definition export; protected notices render on the next GET.
- History authorization is separate from live-application health. Authorized
  stored downloads remain available for an absent/alias-changed target, while
  capture/compare/recovery retain strict live identity checks.
- New snapshots cross-check exported page, region, item and button identity sets
  against public live metadata; historical validation uses stored provenance.
- An actual synthetic native INSTALL failure returned ORA-20987. The operation
  was FAILED, its durable backup validated, and explicit owner reimport recovered
  the still-present fault application; no atomic rollback is inferred.
- Public scripts retain protective SQL/OS error handlers. SQL*Plus is the
  verified configuration client; SQLcl's observed guarded-configuration issue
  is documented rather than bypassed.

### Known limits

- Exact APEX 26.2.0 only; APEX 24.2 was unavailable for testing.
- Single-file generated SQL input. ZIP is storage/transport; APEXlang and split
  exports are not alternative parser inputs.
- No automatic cross-theme template mapping, absent-default synthesis or
  added/dropped component reconstruction.
- Definition backups exclude runtime data, workspace users and external
  dependencies. Imports may partially commit; application locks do not stop
  DBAs, the lock owner or independent import scripts.
- The manager declares workspace-wide **Modify Other Applications** authority.
  Its registry is an application control, not a platform sandbox.
- Native browser workflow: 16/16 checks in one 162.316-second automated run,
  three verified ZIP downloads, correct two-tab binding and zero JavaScript
  errors. SQL suites: 26 blocks (16 parser, nine semantic, one security).
- Latest corrected-fixture engine integration: 20/20 checks; final negative
  rerun: 12/12; independent history/access coverage: 20 checks. Another 10 native browser
  history checks verified six ZIP downloads after alias change/target removal and
  exact owner restoration. Release/media publication remains pending. The public
  repository is a development snapshot until the exact beta tag is created.
