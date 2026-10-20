# Threat model

This is a privileged development administration tool. Its design checks below
are release requirements, not a claim that every adverse scenario has passed
integration tests. Use the published release evidence for the tested boundary.
There is no claim of safe production-wide recovery or atomic application import.

## Authority and trusted parties

Deploy the manager alone in a dedicated parsing schema within a trusted
development workspace. Anyone who can change its PL/SQL, pages, authentication
or authorization is an administrator of this trust boundary. A database owner,
DBA, APEX administrator or attacker controlling that authority can bypass its
tables/triggers, impersonate sessions or import an application directly.
APXTM does not protect against those parties.

**Modify Other Applications** gives the manager workspace-wide modification
authority at the APEX platform level. APXTM's narrower application registry and
roles are application controls; a compromised manager can bypass them. Keep the
workspace limited to applications for which that authority is acceptable. This
scope follows [Oracle's Runtime API Usage documentation](https://docs.oracle.com/en/database/oracle/apex/26.2/htmdb/configuring-security-attributes.html).

Only trusted release/source artifacts and exports from explicitly authorized
targets may enter the workflow. Exports can contain PL/SQL, SQL, JavaScript,
URLs, embedded files and confidential business logic. Treat downloaded ZIP/SQL
files as sensitive **executable artifacts**. Never execute a stranger's export
to discover what it contains, and do not turn uploaded text into SQL commands.

## Controls and remaining exposure

| Threat | Intended control | Boundary that remains |
| --- | --- | --- |
| Anonymous or unauthorized use | Authentication, manager authorization, server-side engine permission checks; no initial principals | Authenticated names are only meaningful if authentication and the manager code remain trusted |
| Target-ID substitution or cross-workspace use | Configured workspace and manager ID, explicit owner-maintained registry, repeated live identity checks | An owner can change registry data or application definitions directly |
| Arbitrary export expressions becoming code | Bounded lexical parsing; reject unknown expressions and duplicate/ambiguous identities; patch a tested scalar allowlist only | Importing a full application definition carries the target's existing executable code |
| Unrelated layout/code changes during a selected repair | Exact source spans, immutable selection, independent re-export and semantic checks | An export/import round trip is an APEX operation; engine checks need release-specific evidence |
| Stale comparison or replay | Fresh export fingerprint, expiring single-use preview token, actor/target binding, reauthorization on apply | A concurrent external writer can still race with the supported workflow |
| Concurrent writes | Per-target applying-operation constraint and public APEX application lock | App Builder locks do not stop the same lock owner, DBAs or independent SQL/import scripts |
| Artifact tampering or accidental corruption | Immutable snapshot/artifact updates; stored source/archive SHA-256 hashes; validation before use | Hashes are integrity checks, not signatures; a privileged database owner can change the code or storage |
| Interrupted or partially committed import | Persist a validated definition backup and operation state first; record failure; explicit independent verification/restore | Import is not an atomic transaction; runtime data and external services are outside the backup |
| Disclosure through downloads or UI | Permission checks for artifacts, escaped output, session-state protection and protected actions | Authorized readers can copy definitions; protect downloaded files and private logs |
| Loss of history | No automatic deletion; RESTORE-only typed retirement; provenance foreign keys; explicit uninstall consent | Owner-level DDL and loss of the database/storage are outside application controls |

Application locks are an aid for coordinated maintenance, not a general database
lock or a substitute for stopping external automation. Oracle describes them as
preventing **other** developers' changes through App Builder.
[Oracle's application-lock guide](https://docs.oracle.com/en/database/oracle/apex/26.2/htmdb/locking-and-unlocking-an-application.html)
and [26.2 public API release notes](https://docs.oracle.com/en/database/oracle/apex/26.2/htmrn/new-features.html)
describe the public mechanism.

## Operational boundary

Recovery starts disabled. Capture/compare registration does not enable import.
The owner separately accepts workspace authority, configures an existing lock
developer and enables a specific development target. Enforce the same checks on
all server entry points, including downloads and crafted requests. Hiding a
button or trusting a page item is insufficient.

Snapshots are definitions only: they omit runtime table rows, workspace users,
credentials and external dependencies. Supporting-object installation must not
run as part of a recovery. Preserve an independent trusted export and database
backups appropriate to the application. There is no outbound network service
required by APXTM; avoid adding credentials or network grants for installation.

Audit records should identify actor, target, action, timestamp, outcome and safe
error codes without copying source exports, credentials or tokens. The append-
only trigger protects ordinary updates/deletes, not a database owner. APEX debug
and SQL client transcripts also require confidential handling.

Release verification must include unauthorized/cross-workspace attempts,
tampered artifacts, stale/replayed previews, simultaneous requests, failure after
import has begun, fresh backup verification, and unrelated-property preservation
on synthetic applications. Confirm caller-transaction isolation experimentally;
do not infer commit behavior from an API name. See [access control](access-control.md)
and the [private reporting policy](../../SECURITY.md).
