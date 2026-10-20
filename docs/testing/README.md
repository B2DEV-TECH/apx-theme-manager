# Testing and evidence

Run database and browser tests only in a dedicated disposable laboratory with
the original synthetic fixtures. Some suites overwrite application definitions,
change principal/registry state and deliberately create invalid artifacts. A
`--disposable-lab` flag is an acknowledgement of that scope, not application
discovery or permission to test unrelated work.

Final release counts and outcomes belong in the
[verification report](verification.md). Its final reconciliation is pending;
this guide deliberately does not infer PASS from a source file or a prior run.
An unavailable dependency/environment is a blocked check, not a passing test.

## Setup

1. Review [installation](../installation/README.md),
   [compatibility](../compatibility.md) and the
   [threat model](../security/threat-model.md).
2. Install the packages, native manager and original sample in a dedicated
   workspace. Finish fixture imports in their owning connection and reconnect
   before autonomous engine operations.
3. Use Node.js 22 or later for optional development tooling, then run `npm ci`.
   The installed application itself needs no Node.js or Python service.
4. Create an ignored `.local/lab.json`, or set `APXTM_LAB_CONFIG` to a private
   configuration file. The database runner reads `user`, `password` and
   `connectString`; application/browser helpers additionally use the workspace
   and synthetic test-account settings documented in their source. Keep all
   values local, restrict file access and do not publish transcripts containing
   credentials or session tokens.

The checked-in browser helpers currently target the original Windows lab,
Chrome executable, endpoint and source manager/sample IDs. They are not generic
cross-platform runners for an arbitrary installation. Review those explicit
guards before adapting a private test copy. Portable installation has separate
workspace/schema/application-ID inputs.

## Entry points

Run commands from the repository root. Do not run mutating suites or manual
fixture edits concurrently.

```text
npm test -- tests/parser.sql tests/semantic.sql tests/security.sql
node tests/integration.mjs --disposable-lab
node tests/negative.mjs --disposable-lab
node scripts/apex-browser-smoke.mjs
node scripts/apex-browser-workflow.mjs --disposable-lab
```

Plain `npm test` runs all three SQL suites. The explicit filenames above can
also select individual suites during development. The SQL
runner executes this project's PL/SQL blocks; it is not a SQL*Plus interpreter
for `installer/` scripts.

| Group | Purpose |
| --- | --- |
| `parser.sql` | Quoting/comments, bounded syntax, component identity, unsupported expressions, Unicode/CLOB handling and exact unrelated-source preservation |
| `semantic.sql` | Semantic differences, explicit scalar eligibility, missing/default parameters and template ambiguity/missing definitions |
| `security.sql` | Permission and input rejection at the PL/SQL boundary |
| `integration.mjs` | Durable snapshots, deduplication, caller-DML isolation, controlled fixture differences, selected/all-eligible recovery, full restore, freshness/replay and preservation checks |
| `negative.mjs` | Denied principals/targets, corrupted fixtures, immutable metadata, claim/lock/failure and related adverse scenarios implemented in that suite |
| Browser smoke | Authenticated read-only navigation, mobile document width, scrollable tables and browser error capture |
| Browser workflow | Actual native capture/compare/preview/apply/restore/download journey on the guarded synthetic application |

This table describes test purpose, not completed coverage. Check the final report
for which cases ran after the last code/export changes, their exact versions and
any remaining gaps. Full restore must reject divergent ACL assignment state;
fresh cross-actor exports normalize only the generated `Exported By` comment.
Those preservation rules need their own positive and negative evidence.

## Clean installation and administration clients

Use a second clean schema/workspace with different destination application IDs
for installation evidence. Keep this separate from the original-ID development
runners above. Check initial deny-by-default state, repeat version 1 core
installation, configure existing workspace/manager identity, register and
capture read-only, then exercise removal refusal before any destructive consent.

SQLcl 26.3 ran core `install.sql` twice successfully in the clean lab. The exact
guarded `configure.sql` invocation with typed binds in a fresh owner session
printed `WHENEVER` help and returned status 0 without applying changes.
SQL*Plus 23.26.3 executed the same script successfully. Use SQL*Plus for the
administration flow and retain every protective error handler. Check database
postconditions; an exit status alone is not setup evidence.

## Evidence to retain

Record the commit, exact database/APEX/client/browser versions, target identity
guard, suite command, completed cases and failures. For import operations, retain
the normalized expected/actual source fingerprints, operation outcome and durable
backup reference. Verify independent public metadata as well as the engine's
status. A complete source fingerprint excludes only the generated actor comment;
it does not establish runtime data or external-service recovery.

Local runners write detailed evidence beneath ignored `.local/` directories.
Review and sanitize evidence before adding a public summary: omit credentials,
session/token values, private exports and unrelated application names. Never
manufacture PASS records to fill an unavailable scenario.

Real screenshots belong with their capture provenance in
[`apex/screenshots/`](../../apex/screenshots/). An automated browser recording is
not narration, a manual accessibility assessment or a performance benchmark.
Use the [recording script](../../media/recording-script.md) and disclose edits.
