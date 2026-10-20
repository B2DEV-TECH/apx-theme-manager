# APEX Theme Manager design

## Intent and authority

An independent B2DEV TECH community application for taking definition snapshots,
comparing layout semantics and recovering selected compatible attributes in an
explicitly authorized development workspace. The implementation is original;
only public Oracle documentation, generated synthetic applications and original
fixtures are inputs. No private implementation is an input.

The master implementation prompt authorizes autonomous engineering and public
publication after verification. The owner additionally authorized the local
Oracle/APEX installation as a disposable laboratory. Ordinary design decisions
do not need repeated approval. Other projects and applications remain outside
the scope of changes.

## Verified discovery

- Public repository exists, is empty, and has default branch `main`.
- Windows, Git 2.53.0, Node 22.16.0 and SQL*Plus 23.26.3 are installed.
- Local FREEPDB1 runs Oracle AI Database 26ai Free 23.26.3.0.0, APEX 26.2.0.
- No APEX 24.2 integration environment has been established.
- SQLcl on PATH fails with a missing Java class. SQL*Plus remains available.
- OBS, Chrome, Edge and Shutter Encoder's FFmpeg are installed.
- Existing B2DEV website: Next.js 16.2.6, Markdown content, Cloudflare Worker,
  static assets, R2 media. Existing editorial reference has been read.
- New project checkout is inside the writable working directory. No second
  repository and no copy of an unrelated application will be created.

## Architecture and alternatives

Use a native Universal Theme administration application over namespaced PL/SQL
packages and relational tables. A region plug-in would hide privileged behavior
inside another application and complicate deployment. An external recovery
server would introduce a permanent dependency without improving the trust model.
Node is optional development/test/recording tooling only.

Packages:

- `APXTM_PARSE`: bounded SQL-export lexer, supported component extraction,
  semantic values and source positions; never executes parsed expressions.
- `APXTM_DIFF`: semantic property comparison, template context and eligibility.
- `APXTM_ENGINE`: authorization, export, immutable snapshots, comparisons,
  preview, backup, import, independent verification and failure records.

Native report queries and page processes use engine entry points; output is
escaped and all modifying actions have server-side authorization. There is no
separate UI database package.

Tables cover configuration, principals, registered applications, deduplicated
export artifacts, snapshots, comparisons, differences, operations and audit.
Foreign keys enforce provenance. Immutable snapshot records reference a single
ZIP artifact, with both uncompressed source and archive SHA-256 hashes.

## Supported format and recovery boundary

Capture a complete single-file SQL export using `APEX_EXPORT.GET_APPLICATION`.
Omit changing export dates/audit identities and supporting-object execution;
preserve subscriptions and current component IDs. Single-file SQL avoids path
resolution and include-order ambiguity. ZIP is a transport/storage container,
not an alternative parser input. UTF-8 is explicit.

APEX 24.2 documents APPLICATION_SOURCE; 26.2 documents SQL and APEXLANG.
Do not assume the same type names or structures across releases. Initial runtime
support is gated by the exact format exercised by integration tests.

The lexer recognizes ordinary/escaped strings, q quoting, identifiers, comments,
nested parentheses and named parameters. Positions refer to CLOB characters.
Known component calls are recognized as generated artifacts; application code
never invokes internal APEX APIs. Arbitrary SQL, unknown expressions and malformed
or duplicated component identities are rejected for transformation.

Compare pages, regions, items, buttons and theme defaults. Preserve raw values
for diagnostics and canonicalize recognized scalar values for comparison.
Identity includes application/workspace, component type/ID, page and parent/name
context. Offset/copy/recreation conflicts are reported rather than guessed.

Template identity uses type, class, name and available reference information.
IDs alone and names alone never establish equivalence across themes. Duplicates
are AMBIGUOUS. Cross-theme template/options mapping is detection-only unless an
independently verified rule proves the particular mapping safe. Initially,
automatic recovery targets explicitly recognized grid spans/positions and row/
field booleans present in both exports. Absent parameters are detection-only.

Observed difference, eligibility and operation outcome are separate fields.
States include UNCHANGED, CHANGED, ADDED, DROPPED, NO_MATCH, AMBIGUOUS,
UNSUPPORTED, CONFLICT, FIXED and FAILED.

## Recovery protocol

Compare -> select -> preview -> explicit confirmation -> fresh export -> verified
backup -> validated import -> independent re-export verification.

Each comparison binds immutable baseline/current artifacts to the exact export
fingerprint. Preview is bound to an immutable selection and a one-use token.
Apply reauthorizes, checks workspace/application identity, checks development
policy, excludes the manager itself, acquires concurrency protection and checks
freshness again. All transformations are span replacements from the freshly
parsed current artifact; unrelated characters must remain identical.

Use public `APEX_APPLICATION_INSTALL.GET_INFO`, explicit workspace/application/
schema/offset context, no supporting-object installation, and INSTALL with
overwrite enabled only after all checks. Preserve target theme/subscriptions.
Re-export and verify selected semantics plus absence of unrelated semantic
changes. A successful API return alone is not success.

Investigate transaction behavior experimentally. Isolate exports from caller
DML with a deliberate autonomous boundary; never commit the caller's business
transaction. Persist backup and operation state before installation. Application
import may commit and may fail partially. Never promise atomic rollback. Keep a
verified definition backup and explicit restore operation with separate rights.

## Security and operations

Default registry is empty and modification policy is disabled. Principals have
READ, RECOVER or RESTORE authority, checked by the definer-rights service.
Actor comes from authenticated APEX session context; database owner tooling has
a distinct database actor. No caller-supplied username controls authorization.
Workspace and allowlist checks are repeated at use. UI session-state protection,
APEX Accounts authentication and authorization schemes complement engine checks.
Modify Other Applications must be enabled explicitly for runtime import; it is
workspace-wide authority and requires a dedicated trusted administration app.

No network calls, secrets, arbitrary code execution or grants to PUBLIC.
Audit action, actor, target, time, outcome and safe error code; do not log export
contents or credentials. Snapshot downloads require authorization. No automated
retention deletion. Uninstall requires explicit typed data-loss consent.

## Verification and release gates

Unit tests exercise real PL/SQL parser/patch behavior including hostile syntax,
Unicode, large CLOBs, duplicate identities and ambiguous mappings. Integration
tests run against newly created synthetic applications only: capture, change,
compare, selected/all recovery, backup, restore, stale/replayed/unauthorized and
failure/concurrency scenarios. Record exact versions and independently inspect
post-import properties. Clean-install tests are separate from compile checks.

Browser tests cover the authenticated end-to-end workflow, responsive tables,
empty/error states and accessible controls. Screenshots/video must come from
real APEX runtime. If recording cannot be completed, publish only an explicitly
labeled recording kit. No stable release before security and integration gates.

The article follows the website's native content format and uses measured
evidence. It may be published only after verified functionality exists. Record
all blocked deliverables explicitly. Release is a beta if any supported-scope
claims have not passed the stated gates.
