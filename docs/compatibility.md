# Compatibility and limits

The initial scope is `v0.1.0-beta`, pending final release verification. The
implementation gates capture/recovery on **exact APEX 26.2.0**. Documentation
availability or compilation on another version is not a compatibility result.

## Recorded environment

| Component | Scope of evidence |
| --- | --- |
| Oracle AI Database 26ai Free 23.26.3.0.0 | Local Windows laboratory database |
| Oracle APEX 26.2.0 | Only tested runtime/export format; final suite reconciliation in the verification report |
| APEX 24.2 | No environment available; no integration or compatibility claim |
| Other APEX/database releases or platforms | Untested |
| SQL*Plus 23.26.3 | Same guarded bind-based configuration script succeeded; recommended administration client |
| SQLcl 26.3 | Core install/reinstall and APEXlang authoring exercised; guarded configuration has the documented `WHENEVER`/status-0 limitation |
| Node.js 22+ / node-oracledb / Playwright | Optional development/test tooling, not runtime services |
| Native browser workflow | 16/16 checks, 162.316 seconds for one complete synthetic run; both sample pages captured at four states, zero JavaScript errors |

The native application runs through the environment's existing APEX web endpoint.
The browser helpers are specific to the original Windows/Chrome laboratory.
The portable installer accepts explicit destination workspace/application IDs
and uses the connected parsing-schema owner; it creates no schema/workspace.
See [installation/client guidance](installation/README.md#verified-sql-client-distinction)
and [test setup](testing/README.md).

## Export and identity boundary

- A complete **single-file SQL** export from the public APEX API is the semantic
  input. UTF-8 ZIP is the storage/download container.
- APEXlang is used to author the synthetic fixtures. It is not a supported input
  to the SQL lexer; split SQL exports are also outside this version's boundary.
- The application must be explicitly registered in the configured workspace,
  use the manager's parsing schema and match its recorded live identity.
  Recovery requires a main development application, not a working copy or the
  manager itself.
- New captures compare exported page/region/item/button identity sets with public
  live metadata before storage. Historical validation checks stored hashes and
  identity; it does not require today's component set to match an older snapshot.
- Actual APEX 26.2 exports use `p_item_plug_id` for item parents, verified against
  live public metadata. Button `p_button_template_id` and region
  `p_region_template_options` / `p_plug_item_display_point` are recognized for
  detection; they are not automatic template/options/display-point mappings.
  Legacy parameter aliases remain accepted.
- The same target/component identities must remain usable. Copies, imported
  offsets, recreations and ambiguous names are not evidence of equivalence.
- Capture preserves current IDs, subscriptions, ACL assignments, saved reports,
  notifications and translations while excluding supporting-object installation.
- The source fingerprint normalizes only the generated `Exported By` comment
  observed to vary across actors. Other source content is significant. The
  archive hash checks exact stored ZIP bytes.

## Recovery eligibility

| Difference | Automatic recovery |
| --- | --- |
| Recognized bounded numeric grid span/position, including region `p_plug_display_column`, explicitly present in both definitions | Eligible when identity, scalar validation, complete recognized grid plan and policy checks pass |
| Supported row/field boolean, explicitly present in both definitions | Eligible under the same checks |
| Parameter absent on either side, including an omitted default true row flag | Detection/manual review; no source-span synthesis |
| Template reference, template options or theme default | Detection-only |
| Missing inherited template definition | `NO_MATCH`; ineligible |
| Duplicate template type/name/class identity | `AMBIGUOUS`; ineligible |
| Shared/interleaved item and BODY-button rows, including safe coupled mixed rows | Manual; only known numeric trailing buttons with new-row/new-column behavior are supported |
| Added/dropped component, changed identity, arbitrary expression or unknown syntax | Ineligible; no reconstruction or guessed mapping |

Observed classification, eligibility and outcome are separate. An eligible
`CHANGED` property can later be `FIXED`; a visible difference can remain manual.
**Fix All Eligible does not promise baseline equality for every property.**
The sample's source edits are controlled and synthetic, not a reproduced
theme-switch defect.

The pure grid-plan check rejects recognized twelve-column overflow and
same-row/sibling overlap after applying a proposed selection. A position/span
can require a coupled change; eligibility of a scalar alone does not guarantee
an isolated selection is safe. It is not a general HTML/CSS or responsive-layout
proof. Real browser rendering caught overlap in the earlier fixture; its corrected
columns now produce 14 differences, with 12 eligible and two DROPPED flags.

Inherited Universal Theme template bodies were absent in the actual export probe
even with `p_with_no_subscriptions=>true`. Name/class equivalence is modeled by
pure unit fixtures; no live cross-theme mapping is certified.

Full definition restore is a separate RESTORE-authorized import. APEX 26.2.0
preserves current runtime ACL assignments during native full restore, so APXTM
requires identical snapshot/current assignment state and rejects divergence for
manual review. It does not silently reset assignments or promise their rollback.
The final release report must verify this guard after the last implementation
change.

## History availability

Authorized history reads use the registered workspace/identity and stored
provenance, independently of live application lookup. This keeps existing
snapshot/proposal/backup downloads accessible when the live app is absent or its
alias changes. Roles and workspace restrictions still apply. Capture, comparison,
preview/apply and other live operations continue to reject an absent or
identity-changed target. The independent history suite passed 20 checks; another
ten native browser checks verified six hash-matching downloads after alias change
and target removal, followed by exact explicit owner restoration.

## Operational limits

Oracle-generated SQL exports explicitly warn that modifying the file is
unsupported. APXTM's transformer is experimental original code with the
documented test boundary. Public export/import APIs do not establish an
Oracle support contract for its edited artifacts.

An export definition omits runtime table data, workspace users, credentials and
external dependencies. The complete normalized definition fingerprint is not a
database backup or a functional equivalence proof for external services.

Imports can commit internally and fail partially. A durable verified definition
backup precedes import; failure still requires inspecting the actual application
and audit. Restore is another import, not a transaction rollback. Complete any
parent import transaction and use a fresh session before engine recovery.

One deliberately invalid synthetic import raised native ORA-20987. Its operation
was recorded FAILED and its durable backup validated; the application remained
present, and an explicit owner reimport recovered it. This exercises a real error
path without establishing atomicity or every partial-import outcome.

On the tested APEX runtime, definition export disrupted the implicit HTTP submit
response. Native full POST plus explicit public redirect now returns 302 for
successful and rejected actions, followed by a fresh page with protected,
escaped notices. Browser tests also verify ZIP download hashes and same-session
two-tab preview binding. These findings are specific to the recorded environment.

The manager's **Modify Other Applications** setting is workspace-wide authority.
Application allowlists and roles depend on the manager and database owner
remaining trusted. Public application locks coordinate other developers' App
Builder activity, not DBAs, the lock owner or independent import scripts.

No multi-host availability, general performance ceiling, exhaustive theme
compatibility or production-wide safety claim is made. Consult the
[threat model](security/threat-model.md),
[transaction observations](architecture/transactions.md) and
[verification report](testing/verification.md) for the evidence and open gates.
