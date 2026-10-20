# Maintenance, backups and removal

Use a fresh dedicated owner connection in SQL*Plus, with no unrelated pending
DML. SQL*Plus 23.26.3 is the verified configuration client; the
[installation guide](README.md#verified-sql-client-distinction) records a SQLcl
26.3 `WHENEVER` handling issue that can skip configuration while returning
status 0. Keep all protective handlers in the distributed scripts. Complete any
prior import in its owning connection, then reconnect before administration.
Stop manager use before maintenance and preserve an independently stored export of the target
application, plus an appropriate database backup of APXTM history. A database
backup of APXTM and an application-definition ZIP serve different purposes.

## Reinstall or upgrade

The initial schema version is `1`. Re-running `installer/install.sql` with a
complete version 1 schema keeps stored rows and recompiles the packages and
immutability triggers. It is not a migration engine: an unknown schema version
is refused. A partially created schema needs inspection; do not mark it complete
by editing `schema_version`, drop arbitrary objects, or blindly re-run an
installer from another release.

For a reviewed version 1 package reinstall, run in SQL*Plus:

```sql
@installer/disable_recovery.sql
@installer/upgrade.sql
@installer/verify.sql
```

The upgrade entry point refuses an applying operation or enabled modification
policy. DDL commits: package/trigger replacement is not an atomic rollback.
Keep the previous trusted source tree and database backup. If compilation fails,
leave recovery disabled, inspect `USER_ERRORS`, restore the intended package
version, and verify before reopening access.

Manager application updates are a separate import reviewed by the owner.
`install_apex.sql` intentionally refuses overwrites. Preserve the existing
manager ID, authentication, authorization, parsing schema and security settings
when reviewing an update in App Builder. Retest on a disposable workspace before
upgrading an installation with history. Future schema changes must ship an
explicit, version-checked migration and recovery instructions.

## Failed or interrupted application import

An APEX import can commit and can fail after changing part of an application.
Neither a PL/SQL exception nor `ROLLBACK` proves the application was restored.
A returned API call also does not prove that the expected properties survived.

1. Stop edits/imports for the target and disable future manager recovery requests.
2. Inspect Activity's operation, audit entry and definition snapshot history.
   Download and retain the validated durable backup ZIP. Authorized history
   reads remain available if the live application is missing or its alias has
   changed, and when modification policy or per-target recovery is disabled.
   READ principal, enabled target registration, workspace and parsing-schema
   checks still apply. Treat an `APPLYING` operation after an interruption as
   unresolved until investigated. Do not clear its status just to retry.
3. If the target still exists, export and inspect its actual current definition.
   Otherwise record its absence. Preserve that evidence before taking another
   action; do not include it in public reports.
4. If appropriate, use the separate restore preview and explicit confirmation
   workflow with a `RESTORER` account and a validated backup. It performs another
   import with its own risks. The manager refuses live recovery when the target
   is absent or its registered identity has changed. In that case, or if the
   manager is unavailable, the workspace owner must review the retained trusted
   definition and use supported APEX tooling for an explicit import. History
   access does not authorize overwriting a new application that reuses an ID.
5. Re-export independently, check the intended and unrelated properties, and
   resolve any remaining application lock under its actual owner.

Recovery snapshots omit table data, workspace users and external dependencies.
Arrange their recovery separately when needed. Retest behavior after any
restoration, and preserve evidence of partial failures. Release evidence records
the specific failure paths exercised; other partial-import outcomes remain possible.

## Retention

There is no automatic retention deletion. Set a deliberate retention policy
based on storage, restore needs and confidentiality. Download and verify any
artifact you need to keep before requesting removal.

`APXTM_ENGINE.RETIRE_SNAPSHOT` requires `RESTORE` authority and the exact typed
confirmation `DELETE <snapshot_id>`. Foreign keys prevent deleting snapshots or
artifacts referenced by comparisons or operations. Rejection means the history
is still referenced; do not disable constraints or remove audit rows to force
deletion. Retirement is not a promise to garbage-collect all stored artifacts.

## Uninstall

Export anything you need to retain, stop manager use, and disable recovery. The
uninstaller permanently removes this installation's APXTM tables, history,
snapshots/backups, audit, triggers and packages. It uses a fixed object list,
without `CASCADE CONSTRAINTS`. Unknown schema versions, an applying operation,
or unrelated foreign-key dependencies require inspection before removal.

The default is refusal. In a fresh direct schema-owner SQL*Plus connection,
declare a bind and type the exact uppercase database owner name into the
confirmation:

```sql
@installer/disable_recovery.sql
variable apxtm_uninstall_confirmation varchar2(300)
begin
  :apxtm_uninstall_confirmation := 'DROP APXTM DATA IN <SESSION_USER>';
end;
/
@installer/uninstall.sql
```

The script never drops a workspace, application, user/schema or unrelated table.
Remove the manager application separately in App Builder after verifying its
actual identity; do not remove any application supporting objects belonging to
another project. A DBA may separately review whether the schema's
`DBMS_CRYPTO` grant is still needed. Drop operations commit and an interrupted
uninstall can leave a partial installation; preserve the console transcript and
inspect before proceeding.
