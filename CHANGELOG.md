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

### Safety and preservation decisions

- Recovery is disabled by default. The initial principal and target registries
  are empty; the direct owner authorizes them explicitly.
- Automatic repair covers only bounded recognized grid/row/field scalars
  explicitly present in both definitions. Template references/options/defaults
  are detection-only; missing or ambiguous identity is not guessed.
- Capture explicitly requests ACL assignments, saved reports, notifications and
  translations. Supporting-object installation is excluded.
- Full restore does not promise to roll back ACL assignments: different
  snapshot/current assignment state requires rejection before import.
- Source fingerprints normalize only the generated `Exported By` comment for
  cross-actor exports; archive hashes continue checking exact ZIP bytes.
- The engine completes its owned import transaction before independent export.
  Caller business DML is outside that autonomous transaction, and atomic
  application rollback is not promised.
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
- Final suite counts, independent review disposition, clean-install/uninstall
  results and browser/media evidence must be reconciled in the release report.
