# Public Oracle API research

Research checked on 2026-10-20 against public Oracle documentation. Laboratory
metadata was separately inspected on APEX 26.2.0. Documentation and matching
signatures establish available APIs; they do not establish safe transaction,
locking or round-trip behavior. Integration evidence must record those results.

## Export format changes

[APEX_EXPORT.GET_APPLICATION, 26.2](https://docs.oracle.com/en/database/oracle/apex/26.2/aeapi/GET_APPLICATION_Function.html)
returns `APEX_T_EXPORT_FILES`. Its `p_type` defaults to `c_type_sql`; documented
types include `SQL` and `APEXLANG`. The initial parser consumes only the full,
single-file SQL form. Split exports and APEXlang need separate format support.
`p_split` defaults to false. `p_with_date=false`, no audit details and no
supporting objects avoid optional changing metadata and supporting-object
installation. Subscription references are retained when
`p_with_no_subscriptions=false`. Current component IDs are requested rather
than importing an offset/copy identity as an equivalent baseline.

[APEX_EXPORT.GET_APPLICATION, 24.2](https://docs.oracle.com/en/database/oracle/apex/24.2/aeapi/GET_APPLICATION_Function.html)
instead documents default `c_type_application_source` and type
`APPLICATION_SOURCE`, with `READABLE_YAML` among its alternatives. This is a
concrete release difference; it is not evidence of 24.2 runtime compatibility.
Do not replace a format name and declare a new release supported.

The generated SQL can contain internal Oracle import call names as data. The
lexer recognizes those known generated statements without executing them.
Project application code must invoke public APIs only; it must not call an
internal import package directly.

## UTF-8 archive transport

[APEX_EXPORT.ZIP](https://docs.oracle.com/en/database/oracle/apex/26.2/aeapi/ZIP-Function.html)
accepts `p_source_files` and optional `p_extra_files`, both
`APEX_T_EXPORT_FILES`, and returns a BLOB. It writes text as UTF-8 and requires
unique archive entry names.

[APEX_EXPORT.UNZIP](https://docs.oracle.com/en/database/oracle/apex/26.2/aeapi/UNZIP-Function.html)
accepts `p_source_zip IN BLOB` and returns `APEX_T_EXPORT_FILES`. Its text input
must be UTF-8; SQL entries have a `.sql` extension. ZIP is the storage/download
container, not a second semantic input format. Validate entry count/name and
the application identity before using content; compare source and archive hashes
separately.

## Inspect and install

[APEX_APPLICATION_INSTALL.GET_INFO](https://docs.oracle.com/en/database/oracle/apex/26.2/aeapi/GET_INFO-Function.html)
accepts `p_source IN APEX_T_EXPORT_FILES` and returns `T_FILE_INFO`. The public
result includes workspace, version, application ID, alias, owner and supporting
script information. Validate those fields against the configured target before
import. One application per source collection is the documented boundary.

[APEX_APPLICATION_INSTALL.INSTALL](https://docs.oracle.com/en/database/oracle/apex/26.2/aeapi/INSTALL-Procedure.html)
accepts `p_source IN APEX_T_EXPORT_FILES DEFAULT NULL` and
`p_overwrite_existing IN BOOLEAN DEFAULT FALSE`. If source is omitted it can
use the source previously supplied to `GET_INFO`; supply the intended source
explicitly in recovery code. Overwrite is an explicit opt-in, and must follow
freshness, identity, authorization, backup and locking checks.

Set and clear install context explicitly: workspace ID, application ID, schema
and offset must refer to the existing target during recovery. Generate a new
offset only for a new manager/sample installation. The
[SET_AUTO_INSTALL_SUP_OBJ procedure](https://docs.oracle.com/en/database/oracle/apex/26.2/aeapi/SET_AUTO_INSTALL_SUP_OBJ-Procedure.html)
takes a boolean and controls command-line supporting-object installation. Keep
that disabled; the export itself must also omit supporting objects.

Do not interpret `GET_INFO` as a sandbox or promise that `INSTALL` is atomic.
Treat source as executable application material. Persist a validated definition
backup and audit state before installation, then re-export and verify the result
independently. Caller-DML commit behavior requires an explicit experiment.

## Observed SQL client behavior

The clean APEX 26.2.0 laboratory separately verified client script handling.
SQLcl 26.3 ran `@installer/install.sql` twice successfully. However, running the
exact `@installer/configure.sql` with typed binds in a fresh direct owner session
printed `WHENEVER` help and returned exit status 0 without applying configuration.
SQL*Plus 23.26.3 executed the same exact configuration script successfully.

Removing `WHENEVER` lines only in an ignored diagnostic copy let SQLcl execute
the PL/SQL body. This isolates the observed failure to client error-handler
processing rather than invalid setup PL/SQL. Public scripts retain their error
handlers; use SQL*Plus for the verified bind-based administration quickstart and
SQLcl for APEXlang authoring. Do not infer success from the process exit code
alone. See the [client guidance](../installation/README.md#verified-sql-client-distinction).

Finish an import transaction in the connection that owns it, then use a fresh
owner session before configuration or recovery. That transaction/session rule
does not work around the SQLcl issue. The [transaction observations](transactions.md)
describe the separate metadata-lock behavior of the public install API.

## Public locking in 26.2

The [26.2 release notes](https://docs.oracle.com/en/database/oracle/apex/26.2/htmrn/new-features.html)
introduce public `APEX_APPLICATION_ADMIN.LOCK_APPLICATION` and
`UNLOCK_APPLICATION`. Their installed public signatures were checked in the
26.2.0 laboratory:

```text
LOCK_APPLICATION(p_application_id NUMBER, p_lock_as_user VARCHAR2,
                 p_lock_comment VARCHAR2)
UNLOCK_APPLICATION(p_application_id NUMBER, p_unlock_as_user VARCHAR2)
```

The lock owner must be an existing workspace developer or administrator. Use an
explicit unlock owner so cleanup does not indiscriminately unlock another
owner's work. Oracle's [application-lock guide](https://docs.oracle.com/en/database/oracle/apex/26.2/htmdb/locking-and-unlocking-an-application.html)
describes protection against other developers editing through App Builder.
It does not establish exclusion of the same owner, DBA sessions or independent
import scripts. Test the actual import path while holding the public lock;
never substitute an undocumented lock routine.

## Runtime authorization and release gates

[Runtime API Usage](https://docs.oracle.com/en/database/oracle/apex/26.2/htmdb/configuring-security-attributes.html)
includes **Modify Other Applications**, a workspace-wide capability. A dedicated
manager/schema and application-level allowlists narrow the intended use, while
the platform authority remains broader. Do not auto-enable it as a hidden
installation side effect.

Record exact versions, export options, SQL/ZIP hashes, Unicode round trips,
pending caller-DML behavior, fresh backups, import failure/commit behavior,
public lock behavior, stale/replay/concurrency rejection, and independent
unrelated-property checks. A successful export or package compile proves none
of the remaining gates by itself. APEX 24.2 has no integration claim here.
