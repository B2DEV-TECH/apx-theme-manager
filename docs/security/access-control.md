# Access control

The initial installation has an empty principal registry and target registry.
`DISABLED` is the default modification policy. Access is checked in the engine
as well as the APEX interface; runtime users cannot register targets or grant
themselves permissions.

| Stored role | Authority |
| --- | --- |
| `READER` | Read authorized targets, capture/validate/download definitions and compare |
| `RECOVERER` | Reader actions plus preview/apply eligible layout recovery |
| `RESTORER` | Recoverer actions plus full definition restore and explicit snapshot retirement |

A role does not bypass the configured workspace, application allowlist, parsing
schema or manager exclusion. Live capture/comparison also requires the current
application to match its registered identity. Recovery additionally requires the
development policy and per-target recovery flag.
The role table describes the intended API boundary; release evidence must show
which positive and negative paths were exercised.

## Actor identity

The engine derives `APEX:<UPPERCASE_USER>` from the authenticated APEX context;
it does not accept an actor from a page item or request parameter. Owner tools
use `DB:<UPPERCASE_SESSION_USER>` in a direct parsing-schema owner session.
APEX accounts and database accounts with the same visible name are distinct.
No privileges are granted to `PUBLIC` by this project.

The owner explicitly invokes `installer/configure.sql` to grant `RESTORER` to
the database owner and one existing unlocked workspace administrator. It checks
that the manager actually exists under the specified workspace and schema.
Subsequent principal changes are deliberate owner maintenance of
`APXTM_PRINCIPALS`; `enabled='N'` revokes a principal, and a lower stored role
limits future requests. Re-running configuration does not revoke prior admins.
Review the complete registry when personnel or authentication changes.

The initial UI uses APEX Accounts. Connecting another authentication provider
requires a separate review of authenticated identity, account collision,
authorization and logout behavior before assigning APXTM roles.

## Target and modification policy

`APXTM_ENGINE.REGISTER_APPLICATION` is a direct database-owner operation. It
records an existing application's workspace, parsing schema and identity. It is
not a request that the runtime can approve, and registration alone never enables
recovery. The manager cannot be a target.

Recovery additionally needs an enabled appropriate principal, an enabled matching
target with `allow_recovery='Y'`, `modification_policy='DEVELOPMENT'`, and an
existing workspace developer/administrator configured as `lock_user`. Review
the manager's workspace-wide **Modify Other Applications** authority before
using `installer/enable_recovery.sql`. See [installation](../installation/README.md).

Apply must recheck authorization, source freshness and the immutable preview
selection before using its token. A preview is not durable approval for an
application that subsequently changed. Restore has a separate preview and
requires `RESTORE` authority; it is another import, not a transaction rollback.
The UI must bind confirmation to the actual operation and display the target,
backup and selected effects before the user confirms.

## Historical definitions

`APXTM_ENGINE.CAN_READ_HISTORY(application_id)` returns `1` only for an enabled
READ principal and enabled registered target in the configured workspace and
current parsing schema, excluding the manager. It does not require the live
application to exist or retain its registered alias. This keeps pre-import
backups available after a partial import damages the target identity.

Snapshot validation and snapshot/proposal ZIP downloads use this history check.
They still verify archive/source hashes, ZIP contents and exported application,
workspace and schema identity. Activity uses the same history permission to
show operations, audit entries and definition snapshots. Disabling modification
policy or setting `allow_recovery='N'` does not revoke these read permissions;
disabling the principal or registered target does.

History access grants no authority to capture, compare, preview, apply, restore
or retire an absent or changed application. Those paths retain live identity
checks. A downloaded artifact is a sensitive executable definition for owner
review, not permission to import it into whichever application now uses an ID.
