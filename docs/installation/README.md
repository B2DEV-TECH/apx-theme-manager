# Install APEX Theme Manager

Use a dedicated development workspace and a dedicated parsing schema. Start with
synthetic applications that you can discard. This project's initial target is
exact APEX 26.2.0 SQL exports; APEX 24.2 and other versions are untested. An installed
APEX version or a successful package compile does not establish recovery safety.

The laboratory has Oracle AI Database 26ai Free 23.26.3.0.0 and APEX 26.2.0.
A separate clean workspace has verified core installation/reinstallation,
configuration, target registration and read-only snapshot capture. Consult the
release evidence for the complete tested scope; this does not establish every
client, recovery scenario or environment.

## Prerequisites

- An existing Oracle Database/APEX environment with a working APEX web endpoint.
- SQL*Plus with a UTF-8-capable client configuration for the administration
  quickstart below. SQL*Plus 23.26.3 is the verified configuration client.
  SQLcl 26.3 is used for APEXlang authoring; see its script limitation below.
  No host-specific paths or service names are built into the installer.
- A schema assigned to the intended workspace, with `CREATE SESSION`,
  `CREATE TABLE`, `CREATE PROCEDURE`, `CREATE TRIGGER`, and an appropriate
  tablespace quota. Use ordinary schema privileges, without DBA or APEX instance
  administration roles.
- A **direct** `EXECUTE` grant on `SYS.DBMS_CRYPTO` for the parsing schema. A DBA
  must review and issue that grant separately; the installer never grants it.
- An existing unlocked workspace administrator for initial manager access, and
  an existing workspace developer/administrator to own application locks if
  recovery will be enabled.

The runtime is database PL/SQL and APEX. Node.js, node-oracledb, Playwright and
SQLcl authoring commands are optional development tools, not a runtime server.

## Verified SQL client distinction

Use **SQL*Plus 23.26.3** for the bind-based configuration and administration flow
in this guide, including configure, recovery enable/disable and uninstall.
SQLcl 26.3 successfully ran `@installer/install.sql` twice in the clean lab,
including the idempotent reinstall. Its handling of the guarded configuration
script behaved differently:

| Client / command | Observed result |
| --- | --- |
| SQLcl 26.3 / `@installer/configure.sql`, typed binds, fresh direct owner session | Printed `WHENEVER` help, exited with status 0, and did not apply configuration |
| SQL*Plus 23.26.3 / the same exact script and typed binds | Configuration succeeded |

An ignored diagnostic copy without `WHENEVER` lines let SQLcl execute the body,
isolating the observed problem to client error-handler processing. That is not
a supported workaround: keep the protective handlers in the public scripts.
A zero SQLcl exit status alone is insufficient evidence that configuration ran.
Check the expected database state with `installer/verify.sql`. Reconnecting
after import is still required by this guide; it does not resolve this SQLcl
limitation. Use SQLcl for the documented APEXlang authoring workflow.

## Install the core and manager

Download the whole trusted release/source tree, including `database/`, `apex/`
and `installer/`. Review the [threat model](../security/threat-model.md) first.
The distributed manager export explicitly declares Runtime API Usage `O`
(**Modify Other Applications**). Importing it accepts workspace-wide APEX
modification authority even though APXTM's own recovery policy starts disabled.
Review that authority before import and use a dedicated trusted workspace.
Open a **fresh, dedicated** database connection as the parsing-schema owner;
these scripts perform DDL and commit their setup changes. Do not run them inside
a session containing unrelated uncommitted work.

Use `sqlplus /nolog`, then connect with
`connect <schema>@<connect_identifier>` and enter the password at the prompt.
Do not put passwords in commands, script files, Git, or shared transcripts.
Start the SQL client in the repository root and run:

```sql
@installer/install.sql
```

The public wrapper include paths resolve from the repository root. Start
SQL*Plus there. The core installer checks APEX
and `DBMS_CRYPTO`, applies schema version 1, then compiles `APXTM_PARSE`,
`APXTM_DIFF` and `APXTM_ENGINE`. It checks required objects and compilation
errors. A fresh installation has no principals, no registered applications and
`modification_policy = DISABLED`. The scripts create no schema, workspace, user
or privileged grant.

The following snippets are templates: replace angle-bracket values with the
actual IDs and account name from **your** workspace. Bind variables keep those
values out of script-text substitution. Choose an unused manager application ID:

```sql
variable apxtm_workspace_id number
variable apxtm_manager_app_id number
begin
  :apxtm_workspace_id := <workspace_id>;
  :apxtm_manager_app_id := <unused_manager_application_id>;
end;
/
@installer/install_apex.sql
```

Complete the importing connection's own import transaction, then reconnect in
SQL*Plus as the same owner before configuration to clear importer/session state.
Do not invoke autonomous recovery from a parent session holding application
metadata locks. Redeclare the same numeric binds and the existing administrator:

```sql
variable apxtm_workspace_id number
variable apxtm_manager_app_id number
variable apxtm_admin_user varchar2(255)
begin
  :apxtm_workspace_id := <workspace_id>;
  :apxtm_manager_app_id := <manager_application_id_just_imported>;
  :apxtm_admin_user := '<existing_workspace_administrator>';
end;
/
@installer/configure.sql
```

`install_apex.sql` imports `apex/f104.sql` using the workspace, schema, application
ID and generated offset supplied through the public install context. The source
file name is not the destination application ID. Existing applications are
refused; this script is not an overwrite/upgrade command.

`configure.sql` verifies the workspace, existing manager application and its
parsing schema, and an unlocked workspace administrator. It explicitly grants
`RESTORER` to `DB:<OWNER>` and `APEX:<UPPERCASE_ADMIN>`. No runtime page can grant
that access. Re-running configuration disables recovery for every registered
target, preserves other principals, and refuses a different workspace or manager
identity. Review existing principals before reusing an installation.

## Register a development target

Choose an application you own in the configured workspace, separate from the
manager. Only the direct database owner can register it:

```sql
variable apxtm_target_app_id number
begin
  :apxtm_target_app_id := <target_application_id>;
end;
/
@installer/register_application.sql
@installer/verify.sql
```

Registration is an allowlist entry, not recovery permission. Sign in to the
manager as the configured APEX administrator and exercise capture/comparison
before enabling modification. A snapshot is an **application definition**; it
does not back up runtime table data, workspace users, credentials or external
dependencies.

## Explicitly enable development recovery

First review the manager's **Shared Components → Security Attributes → Runtime
API Usage** setting. The supplied export declares **Modify Other Applications**,
which permits changes throughout the workspace. Retain it only after accepting
that authority for this trusted manager. It is not limited by the APXTM registry at the APEX
platform level. See [Oracle's security attribute documentation](https://docs.oracle.com/en/database/oracle/apex/26.2/htmdb/configuring-security-attributes.html).

With manager use stopped and no import in progress, run in SQL*Plus as the direct
owner:

```sql
variable apxtm_lock_user varchar2(255)
variable apxtm_enable_confirmation varchar2(300)
begin
  :apxtm_lock_user := '<existing_workspace_developer>';
  :apxtm_enable_confirmation := 'ENABLE RECOVERY FOR <target_application_id>';
end;
/
@installer/enable_recovery.sql
```

This checks the existing registered main application/workspace identity and
development build status, excludes the manager and working copies, verifies the
lock account, and sets `DEVELOPMENT` plus `allow_recovery=Y`
for that target. The confirmation must contain the exact decimal target ID
already bound to `apxtm_target_app_id`. Each additional target requires its own
explicit invocation. The lock account is shared configuration, so changing it
affects future operations for all enabled targets.

To disable future modification requests for all targets:

```sql
@installer/disable_recovery.sql
```

This does not cancel an import already executing. Application locks coordinate
App Builder edits by other users; they cannot exclude the lock owner, DBAs or
independent import scripts. Arrange a quiet maintenance window.

## Check the installation

`installer/verify.sql` checks required objects and reports configuration,
principals and registered targets. It does not perform a recovery test. Verify
the authenticated capture → compare → preview → confirm → independent result
check on a disposable application, then repeat on a second clean installation.
Record exact database/APEX versions and rejected unauthorized, stale and replay
requests. Only the release's published evidence establishes tested behavior.

See [maintenance and removal](maintenance.md) for upgrades, retention and failed
imports, and [access control](../security/access-control.md) for principal roles.
