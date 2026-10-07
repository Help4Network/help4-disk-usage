# Security Policy

## Supported Release

Use the latest tagged release and verify its archive against the configured update manifest before installation. Version 0.3.8 addresses the shared-server findings documented in [the October 2026 review](docs/shared-hosting-security-2026-10.md). Older releases do not contain these controls.

## Reporting

Please report suspected cross-account exposure, privileged filesystem races, authentication bypass, command execution, update integrity failures, or unsafe resource consumption privately to Help4 Network through [the project maintainer](https://help4network.com/). Use GitHub's private vulnerability reporting option when it is available for this repository. Do not post credentials, live account names, private paths, customer data, or production exploit output in public issues.

Include the affected tag, cPanel/WHM or WHMCS version, actor privilege, synthetic reproduction, expected boundary, and sanitized observations. Use a disposable test environment for race/resource tests, not a busy production server. Acknowledge uncertainty instead of treating a static candidate as a demonstrated production exploit.

## Review Boundaries

- Root may see all accounts; resellers may see currently owned accounts; cPanel users may see their own account only.
- WHMCS clients require a current, unique Active/Suspended service mapping. Old or ambiguous mappings must fail closed.
- The scanner reads metadata, never file contents, never follows directory symlinks, and never performs cleanup.
- File Manager navigation selects only a row in the authenticated account cache, resolves its directory beneath the passwd home, and uses a session-relative native route. It does not accept arbitrary absolute paths, stored SSO credentials, or cross-account selectors. Native cPanel permissions remain authoritative at navigation time.
- Downloads apply the same account/reseller scope as HTML. Structured exports allowlist fields, omit server home paths, and neutralize spreadsheet formulas in CSV text. Public tutorial assets must use synthetic data.
- Cache-writing scans must retain one shared lock until publication and bound retained filesystem data.
- WHM/cPanel mutations require authenticated identity, POST, and a short-lived nonce. WHMCS actions depend on the host application's dispatcher, admin permissions, and CSRF checks.
- Root installation/update requires HTTPS and a trusted manifest digest. The online manifest and its publisher remain trusted; the digest is not an independent release signature.

## Assumptions And Limits

Root, WHMCS administrators with server-operation authority, root-owned cPanel configuration, and the release publisher are trusted. Native cPanel authentication, WHMCS authorization, filesystem permissions, and the operating system remain part of the deployment boundary. Same-UID cPanel users can edit their local throttle/cache state; hard CPU, memory, process, and I/O enforcement belongs to the host. A tenant can hold the readable advisory scan lock to delay collection. Keep the lock on a local filesystem and monitor long-held locks.

Reports are bounded observations of live metadata, not filesystem snapshots, quota accounting, malware verdicts, or deletion approvals. The project does not claim cPanel certification, external penetration testing, or immunity from vulnerabilities.
