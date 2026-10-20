# APEX Theme Manager

**Snapshot → Change → Compare → Review → Recover → Verify**

An original native Oracle APEX and PL/SQL application for definition snapshots,
semantic layout comparisons and controlled recovery of compatible attributes.
It applies selected values to the current application definition, with a preview,
validated backup and independent verification.

> **Development snapshot — beta release pending.** The database engine has
> laboratory results on exact APEX 26.2.0, and the native browser workflow passed
> all 16 checks. Release/media review and the release tag are pending. Wait for
> the tagged beta before evaluating installation. The public
> source is work in progress; no release, article or video is announced here.

[![Authenticated native APEX Theme Manager overview with synthetic laboratory history.](apex/screenshots/overview-desktop.png)](apex/screenshots/overview-desktop.png)

*Actual APEX 26.2.0 interface. Counts show synthetic test history; a new
installation starts with an empty registry and recovery disabled.*

| Compare the definition | Review the exact operation |
| --- | --- |
| [![Native comparison with eligible scalar differences.](apex/screenshots/comparison-desktop.png)](apex/screenshots/comparison-desktop.png) | [![Native preview with target, selected value and stored fingerprints.](apex/screenshots/preview-desktop.png)](apex/screenshots/preview-desktop.png) |

Click a capture to inspect it at full resolution. The
[runtime gallery](apex/screenshots/README.md) also shows both sample pages before
change, after change, after eligible recovery and after full-definition restore.

## What it does

| Capability | Supported boundary |
| --- | --- |
| Snapshot | Complete single-file SQL definitions, UTF-8 ZIP, provenance and source/archive integrity checks; new captures cross-check page/region/item/button identities against public metadata |
| Automatic repair | Selected/all-eligible bounded grid spans/positions, including region display column, and supported row/field flags **explicitly present in both definitions** |
| Review | Immutable selection, actor/target binding, expiring single-use token and repeated fresh-state checks |
| Apply | Validated durable backup, public APEX install/lock APIs and independent complete normalized source verification |
| Full restore | Separate permission/confirmation; identical snapshot/current exported ACL role/assignment state required |
| History | Authorized stored snapshot/proposal/backup downloads remain available if the live target is absent or its alias changes; live operations still reject it |
| Tested runtime | Exact APEX 26.2.0 on Oracle AI Database 26ai Free 23.26.3.0.0; other versions untested |

The bounded grid-plan check rejects recognized twelve-column overflow and
same-row/sibling overlap. A scalar can be valid by itself yet unsafe without a
coupled column/span change. Mixed item/BODY-button rows require manual review;
only known numeric trailing buttons with new-row/new-column behavior are
supported. Even a numerically safe coupled mixed row is rejected. This is not a
general proof of rendered layout:
verify both actual pages after repair.

Changed template references, template options and theme defaults are
**detection-only**. Missing inherited definitions become `NO_MATCH`; duplicate
template type/name/class identities become `AMBIGUOUS`. Absent parameters,
unsupported expressions and uncertain matches are not automatically repaired.
Inherited Universal Theme bodies were absent from actual exports even with
subscriptions suppressed. Name/class matching is unit-modeled; no live
cross-theme equivalence is certified.
When a default true row flag disappears from SQL export, it can be reported as
`DROPPED` and left for review. **Fix All Eligible does not mean every difference.**

Snapshots contain application definitions. They do not back up runtime table
data, workspace users, credentials or external dependencies. The supplied sample
uses controlled synthetic layout edits authored in APEXlang; it does not claim
to reproduce an Oracle theme-switch defect.

## Architecture

The manager has eight functional native APEX pages plus APEX Accounts login.
The runtime needs Oracle Database and APEX with their existing web endpoint;
**no Node.js or Python runtime service is required**.

```mermaid
flowchart LR
  S[Snapshot] --> C[Change]
  C --> D[Compare]
  D --> P[Review]
  P --> R[Recover]
  R --> V[Verify]
```

`APXTM_PARSE` reads and patches a bounded scalar subset; `APXTM_DIFF` separates
observed differences from eligibility; `APXTM_ENGINE` owns authorization,
artifacts, operations and audit. History reads use their own authorization
boundary instead of depending on a currently healthy live application.

Only the generated `Exported By` comment is normalized for the source
fingerprint, to permit comparison across authenticated actors. Other exported
source remains significant; the ZIP archive hash checks the exact stored bytes.
See the [design](docs/architecture/design.md),
[public API research](docs/architecture/public-api-research.md) and
[observed transaction boundaries](docs/architecture/transactions.md).

## Before installation

Oracle's generated SQL export warns that modifying it is unsupported. This
beta's bounded transformer is independently tested project code; using public
export/import APIs does not make an edited export an Oracle-supported recovery
contract. Evaluate it on disposable applications first.

The distributed manager export declares **Modify Other Applications** (`O`).
That is workspace-wide APEX authority, broader than the manager's target
registry. Use a dedicated trusted development workspace and parsing schema.
Targets must belong to the configured workspace and use that parsing schema.

APXTM starts with `modification_policy=DISABLED`, no principals and no registered
targets. The direct database owner explicitly configures the manager, grants
named `DB:<OWNER>` / `APEX:<USER>` roles, registers targets, and separately enables
development recovery for a particular application. Runtime users cannot register
targets or grant themselves access. The manager excludes itself as a target.

READER, RECOVERER and RESTORER permissions complement APEX authentication and
server-side checks. Database owners, DBAs and anyone able to alter the manager
remain outside this application-level boundary. Read the
[threat model](docs/security/threat-model.md) and
[access-control guide](docs/security/access-control.md) before accepting import
authority.

An application import can commit and fail partially. **There is no atomic
rollback guarantee.** Keep independent trusted backups and coordinate a quiet
maintenance window. Public application locks constrain other users' App Builder
edits; they cannot exclude the lock owner, DBAs or external import scripts.

## Install and try the synthetic workflow

Follow the [complete installation guide](docs/installation/README.md). It covers
the existing workspace/schema, tablespace quota and ordinary schema privileges.
A DBA must separately review the required direct `DBMS_CRYPTO` execute grant;
the installer does not issue privileged grants.

Use SQL*Plus 23.26.3 for the verified administration flow. SQLcl 26.3 installed
the core twice successfully, but its guarded `configure.sql` invocation printed
`WHENEVER` help and exited with status 0 without configuring the database.
Do not remove protective handlers; see the
[client distinction](docs/installation/README.md#verified-sql-client-distinction).
SQLcl remains the APEXlang authoring tool.

1. In a fresh direct owner connection, run `@installer/install.sql`.
2. Import the manager with `installer/install_apex.sql` and explicit destination
   workspace/application binds. Complete the import and reconnect in SQL*Plus,
   then invoke `installer/configure.sql` with the existing manager and admin.
3. Import the [original two-page sample](samples/layout-lab/README.md), register
   only that target through the owner script, and capture/compare while recovery
   remains disabled.
4. Explicitly enable that development target. Preview one eligible grid value,
   confirm its actual application ID, inspect the backup and verified result,
   then compare again before using all remaining eligible values.
5. Exercise the separate restore preview and confirmation only with compatible
   ACL assignment state. Inspect the application's actual resulting definition.

No schema, workspace, app ID, service name or password is built into the portable
installer's destination configuration. Default IDs in generated SQL filenames
identify source artifacts; the public import context chooses the destination.
Developer browser helpers have a narrower original-laboratory scope.

## Documentation and verification

- [Compatibility and limits](docs/compatibility.md)
- [Test setup, commands and evidence](docs/testing/README.md)
- [Native application and page map](apex/README.md)
- [Synthetic fixture and reproduction](samples/layout-lab/README.md)
- [Upgrades, failed imports, retention and uninstall](docs/installation/maintenance.md)
- [Changelog](CHANGELOG.md), [contributing](CONTRIBUTING.md) and [private security reporting](SECURITY.md)

The completed native browser run passed **16/16 checks in 162.316 seconds**,
including successful/rejected POST redirects, byte-identical source/proposal/
backup ZIP downloads, two-tab binding and zero JavaScript errors. Both sample
pages rendered at four stages. The SQL suites have **26 passing blocks**
(16 parser, nine semantic, one security). The corrected fixture has 14 layout
differences: 12 eligible and two DROPPED flags.

The latest engine integration run passed **20/20 checks**, including actual
exported item parents compared with live metadata. The final negative rerun is
**12/12 passing**. Independent history tests passed **20 checks**. Another **10 native
browser history checks** verified six ZIP
downloads after alias change and target removal, then exact owner restoration.
See the [verification report](docs/testing/verification.md) for the release
reconciliation. The browser duration
includes the whole automated scenario, not API-only timings. No APEX 24.2
environment was available; no other-version compatibility claim is made.

There is no automatic retention deletion. Snapshot retirement requires RESTORE
authority and typed confirmation; provenance foreign keys prevent deleting
referenced history. Uninstall defaults to refusal and requires exact typed
owner consent to remove only the fixed APXTM object set.

## License and provenance

An independent B2DEV TECH community project, developed from original source,
public Oracle documentation and synthetic applications. The original code is
[Apache-2.0](LICENSE). Oracle APEX, generated Universal Theme components and other
third-party material retain their applicable terms and notices. This project is
not affiliated with or endorsed by Oracle.
