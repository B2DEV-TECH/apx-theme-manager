# APEX Theme Manager implementation plan

> Execute with superpowers:executing-plans. The user's master prompt explicitly
> requests autonomous implementation; do not pause at ordinary design handoffs.

**Goal:** Deliver an independently installable APEX layout snapshot/comparison/
recovery application with reproducible safety evidence and community materials.

**Architecture:** Native APEX administrative UI, namespaced PL/SQL engine and
relational persistence. SQL export transforms are restricted to a tested subset.
Development tooling is optional and never a runtime service.

**Tech stack:** Oracle Database, Oracle APEX, PL/SQL, SQL*Plus, optional Node.

**Spec:** [design.md](design.md). User work packages WP0-WP10 define acceptance.

## Global constraints

- Only original code, public Oracle APIs/docs and synthetic applications.
- No direct undocumented internal API calls.
- Read-only default; server-side authorization and application allowlists.
- Freshness, immutable snapshots, verified backup and independent verification.
- No transactional rollback guarantee and no untested compatibility claims.
- Apache-2.0 original source; preserve generated assets' applicable notices.
- No credentials, private exports or intermediate recordings in Git.

## Review focus

- Comment/string contents that resemble export calls must never become patches.
- Duplicate IDs/names and changed application identity must fail closed.
- Import commits/partial failure must not erase the durable backup/audit.
- A selected repair must preserve all unrelated source and target-theme state.
- A later application edit or replayed request must invalidate recovery.

## Task 0: Discovery and laboratory

- [x] Verify public repository, tooling, installed APEX version and website.
- [x] Record design, limits and execution authority.
- [ ] Provision a dedicated schema/workspace and synthetic builder user.
- [ ] Establish database/browser tooling without recording credentials.
- [ ] Record official references and exact API signatures.

## Task 1: Export lexer and semantic model (WP1/WP2)

Files: `database/packages/apxtm_parse.pks`, `.pkb`; `tests/parser.sql`;
`tests/fixtures/`; `scripts/test.mjs`.

Interface: `parse(p_source clob) return json_array_t`,
`patch(p_source clob,p_changes json_array_t) return clob`.

- [ ] Write failing PL/SQL tests for escaped/q quotes, comments, nested calls,
  named parameters, Unicode, large CLOBs and malformed/duplicate constructs.
- [ ] Run RED, implement the lexer, run GREEN.
- [ ] Add supported page/region/item/button/theme/template property extraction.
- [ ] Write patch tests asserting exact unrelated-byte preservation and scalar
  allowlist enforcement; run RED/GREEN and commit.

## Task 2: Persistence, policy and immutable snapshots (WP1)

Files: `database/migrations/001_initial.sql`; `database/packages/apxtm_engine.*`;
`installer/install.sql`; `tests/snapshots.sql`, `tests/security.sql`.

Interfaces: engine authorization, `take_snapshot`, `validate_snapshot`,
`download_snapshot`, registry policy/permission checks.

- [ ] Write failing integrity, authorization, wrong-ID/workspace and immutable
  snapshot tests; compile/install foundation and run RED/GREEN.
- [ ] Capture an actual synthetic full application; verify ZIP round trip,
  source/archive hashes, GET_INFO identity and persisted bytes.
- [ ] Reproduce pending-DML export behavior; select and document boundaries.

## Task 3: Comparison and deterministic mapping (WP2)

Interfaces: `compare(baseline_id)`, persisted differences with separate observed
classification, eligibility and outcome.

- [ ] Write failing changed/added/dropped/conflict/template ambiguity tests.
- [ ] Implement structured comparisons including theme defaults and dictionaries.
- [ ] Bind comparisons to exact current fingerprint; validate expected versus
  actual differences after controlled synthetic changes; run suite and commit.

## Task 4: Controlled recovery (WP3/WP6)

Interfaces: `preview`, `apply`, `restore`, one-use operation token.

- [ ] Write failing selected/all/backup/stale/replay/unauthorized/concurrent and
  failed-import tests against disposable targets only.
- [ ] Implement validated span transforms, exact patch diagnostics, backup,
  import context, target locking and independently verified results.
- [ ] Validate target theme/subscriptions and unrelated properties after import.
- [ ] Exercise interrupted/failed recovery and document manual recovery.
- [ ] Run full integration suite and commit verified scope.

## Task 5: Native APEX UI and reproducible sample (WP4/WP5)

Files: `apex/`, `samples/`, `installer/`, `tests/browser/`.

- [ ] Create an original Universal Theme app using supported authoring/import.
- [ ] Dashboard/detail/snapshot/compare/review/audit/help and authorization.
- [ ] Export distributable manager and synthetic multi-page sample.
- [ ] Browser-test full workflow, mobile, keyboard and error states.
- [ ] Install into a second clean disposable schema/workspace and repeat demo.

## Task 6: Community, security and release (WP6/WP7)

- [ ] Add README, license, changelog, contribution/security policies, portable
  install/upgrade/uninstall guides and threat model.
- [ ] Record exact test/compatibility/performance evidence; document limits.
- [ ] Fresh independent review, address material findings and rerun checks.
- [ ] Audit tracked files/history/exports/screenshots for secrets/provenance.
- [ ] Publish only the version justified by evidence, verify public artifacts.

## Task 7: Video, article and final verification (WP8-WP10)

- [ ] Record real APEX workflow, captions, thumbnail and edited-segment labels;
  otherwise provide the full recording kit with an explicit blocker.
- [ ] Write substantial English article using the designated editorial examples,
  actual screenshots, selected original code and measured results.
- [ ] Integrate with existing B2DEV article/lab taxonomy and deployment workflow.
- [ ] Run site validation/build, desktop/mobile render checks and deploy only
  after factual/media/provenance gates pass; verify actual public URLs.
- [ ] Prepare manual ACE submission information and final release report with
  verified/completed/blocked/not-attempted statuses.
