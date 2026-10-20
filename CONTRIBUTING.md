# Contributing

This is an independent, original B2DEV TECH community project. Contributions must
be work you have the right to share under [Apache-2.0](LICENSE). Do not submit
employer/client code, private implementation details, proprietary application
exports, credentials or customer data. Use public Oracle documentation and
synthetic fixtures that can be published and recreated.

Open an [issue](https://github.com/B2DEV-TECH/apx-theme-manager/issues) describing
the concrete problem and desired behavior, or send a focused pull request with
the problem, resulting behavior, tested versions and reproducible verification.
Send vulnerabilities through [SECURITY.md](SECURITY.md), not a public issue.

## Development

Use an isolated branch and a dedicated disposable Oracle/APEX laboratory. Read
the [design](docs/architecture/design.md),
[public API research](docs/architecture/public-api-research.md) and
[installation guide](docs/installation/README.md). Never run a destructive or
import test against an unrelated application. The runtime has no Node service.

Optional test tooling needs Node.js 22 or later. Run `npm ci`. The database test
runner reads an ignored `.local/lab.json`, or the path in `APXTM_LAB_CONFIG`, with
`user`, `password` and `connectString` keys. Create that configuration locally,
restrict access, and keep it out of Git and transcripts. Install the packages
with SQL*Plus/SQLcl first; the Node SQL splitter is deliberately not a general
SQL*Plus installer.

For example, run the real PL/SQL suites with:

```text
npm test -- tests/parser.sql tests/semantic.sql tests/security.sql
```

Describe which suites actually ran. An unavailable Oracle connection is a
blocked integration check, not a passing test. Browser tests need the separately
configured lab APEX web endpoint and test accounts. Record the exact version,
inputs and result for clean installs and full application workflows.

## Changes that need strong evidence

Parser changes need adversarial SQL syntax, quoting/comments, Unicode, malformed
or duplicate identities, and preservation of all unrelated source characters.
Recovery changes need authorization, target/workspace identity, stale/replay,
selection/token binding, concurrency, durable backup, partial import failure and
independent re-export checks. Detection-only template/options differences must
remain ineligible until a specific mapping is proven safe across the tested
source and target themes.

Use public Oracle APIs. Internal package names inside generated export fixtures
are data for parsing; do not invoke them directly from project application code.
New APEX releases require explicit export-format and integration evidence. Do
not expand the compatibility table from documentation or compilation alone.

Keep installation portable: no real schemas, workspace/application IDs, service
names, local absolute paths or secrets in installer logic. Keep recovery disabled
by default and privileged grants outside the installer. Update the installation,
threat model and release evidence when behavior or authority changes.

## Attribution and review

Preserve applicable copyright, license and attribution notices. The project's
Apache-2.0 license applies to its original source. Oracle APEX, generated
Universal Theme components and other third-party material retain their own
applicable terms and notices; do not represent them as newly Apache-licensed.
This project is not affiliated with or endorsed by Oracle. Do not add Oracle
branding that implies endorsement.

Before submitting, inspect all staged files and exports for secrets, private
names, business logic and unrelated application content. Include only synthetic
screenshots/recordings with permission to publish. A change is ready for review
when its scope, tested behavior and remaining limitations are clear; maintainers
may request narrower behavior or additional evidence before merging.
