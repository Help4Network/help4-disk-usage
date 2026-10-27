# Advisory Applicability Review - 2026-10-27

This bounded review separates Help4 source, developer tooling and vendor host packages. It is not an exhaustive security audit, proof of a deployed vulnerability or native stable certification. No production package, permission, service or updater channel is changed by these notes.

## Test Dependency Update

The browser workflow previously pinned Playwright 1.54.1. It now pins 1.64.1, the npm stable version checked on this review date, and continues to install only Chromium on an isolated Ubuntu runner. [CVE-2025-59288](https://github.com/advisories/GHSA-7mvr-c777-76hp) is fixed from 1.55.1; the [upstream fix release](https://github.com/microsoft/playwright/releases/tag/v1.55.1) removes insecure certificate handling from certain macOS Chrome/Edge installation helpers. Those helpers are not invoked by this Ubuntu Chromium job. Updating the old affected package is dependency maintenance, not evidence that this CI path or the native Perl plugin was exploitable. Browser/runtime freshness still requires ongoing review.

## Separately Maintained Host Packages

[PHP's October 21 advisory](https://www.php.net/archive/2026.php#2026-10-21-5) fixes critical CVE-2026-109618/CVE-2026-109619 in PHP 8.2.35, 8.3.36, 8.4.27 and 8.5.12, with vendor backports possible. The Help4 native pages and scanner are Perl, not PHP, but that does not protect the surrounding cPanel services, hosted sites or a separate WHMCS installation. [cPanel's 138 changelog](https://docs.cpanel.net/changelogs/138-change-log/) records the cpanel-php84 fix in 138.0.18. That single package entry is not proof that every EasyApache/customer PHP handler is patched. The operator must verify each applicable package/build and supported branch independently before planning vendor updates.

The plugin neither bundles nor patches cPanel, Perl, OpenSSL, curl or their shared libraries. Review vendor advisories and backport status for the actual installed packages. Existing updater downloads retain HTTPS certificate verification and checksum/archive checks. Do not use curl --insecure, weaken SSH pins, infer a vendor directory mode or recursively chmod panel directories to clear a gate.

The standalone [WHMCS advisory review](https://github.com/Help4Network/help4-disk-usage-whmcs/blob/main/docs/security-advisories.md) covers its separate PHP/SSH dependencies and Plesk transport mitigation. Installing or updating this native plugin does not update that addon or its framework.

## Status

This maintenance changes developer tooling and guidance only, not installed native runtime, package version or the published 1.0.1 updater. Native reseller/disposable lifecycle/fleet tests and explicit candidate promotion remain required. CI and package hashes are not those acceptance receipts.

Built by [Help4 Network](https://help4network.com/).
