# Security policy

APEX Theme Manager is a development administration tool with application import
authority. The initial release is under development; no production security or
compatibility guarantee is made. Security work targets the latest published
beta, or `main` before the first release. There is no promised response SLA or
long-term support window.

Report vulnerabilities privately through
[GitHub private security advisories](https://github.com/B2DEV-TECH/apx-theme-manager/security/advisories/new).
Include the affected commit/release, exact Oracle Database/APEX versions, the
required role and configuration, expected/actual behavior, and a minimal
synthetic reproduction. Explain whether the issue allows unauthorized access,
cross-workspace actions, source disclosure, stale/replayed recovery, arbitrary
code execution, loss of backups or unrelated application changes.

Do not post credentials, tokens, real application exports, customer/employer
material or an exploit against another installation in a public issue. If
private reporting is unavailable, open a minimal issue requesting a private
channel without sensitive details. Coordinate disclosure through the private
report; do not assume a response or fix date.

When investigating a potentially affected installation, disable future recovery
requests, preserve relevant private audit/operation records and backups, and
inspect the target's actual definition. An interrupted import may have partially
committed; `ROLLBACK` is not a recovery guarantee.

Read the [threat model](docs/security/threat-model.md),
[access-control boundary](docs/security/access-control.md) and
[maintenance guide](docs/installation/maintenance.md) before granting import
authority. Database owners, DBAs and anyone who can alter the manager are outside
the application-level security boundary.
