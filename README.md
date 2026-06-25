# Help4 Disk Usage

Fast WHM/cPanel disk and inode reporting, plus WHMCS deployment and customer-support reporting.

Help4 Disk Usage turns the original Help4 Network [`find_large_files_and_inodes`](https://github.com/Help4Network/find_large_files_and_inodes) scanner into a public, installable product for hosting providers:

- A WHM plugin for root and reseller disk/inode audits.
- A cPanel account plugin for customer self-service visibility.
- A WHMCS addon module for deployment, server sync, admin support reports, and customer-facing summaries.

The project is intentionally permissive. Hosts, agencies, cPanel, WHMCS operators, and other vendors can use it, modify it, and ship it. Keep the Help4 credit visible at the bottom.

## Why This Exists

Default WHM/cPanel disk usage tools are often slow, stale, cache-heavy, and hard to turn into a customer conversation. Hosts need to know:

- Which account is the real offender?
- Is it disk, inodes, logs, backups, cache, mail, uploads, or temp files?
- Is the data fresh?
- Can support explain the issue without asking root admins to manually dig?
- Can customers see a useful, scoped summary without seeing other account paths?

Help4 Disk Usage is designed around background scans, bounded runtime, visible timestamps, role scoping, and support-ready remediation hints.

## Repository Layout

```text
src/bin/help4-disk-usage-scan                         Scanner and JSON cache writer
src/whm/index.cgi                                     WHM root/reseller dashboard
src/cpanel/index.live.pl                              cPanel account page
src/static/                                           Shared UI assets
packaging/                                            cPanel/WHM plugin metadata
integrations/whmcs/modules/addons/help4_disk_usage/   WHMCS addon module
docs/                                                 Security, validation, and marketing notes
tests/                                                Local scanner smoke tests
scripts/package.sh                                    Release tarball builder
install.sh                                            cPanel/WHM installer
uninstall.sh                                          cPanel/WHM uninstaller
```

## Main Features

### WHM

- Root dashboard for all cPanel accounts.
- Reseller dashboard filtered to owned accounts.
- Manual refresh for all, reseller-owned, or one account.
- Actionable offender summaries:
  - largest files
  - stale large files
  - inode-heavy directories
  - size-heavy directories
  - cache, log, temp, backup, mail, dependency, and upload hotspots
  - growth deltas when previous cache exists
- Visible `scanned_at` timestamps and scan completeness.
- Root-editable scan limits for WHM and cPanel refreshes.
- Shared foreground scan lock so GUI refreshes do not stack.

### cPanel

- Account-scoped page in Jupiter.
- Scans only the authenticated account home directory.
- Renders relative paths only.
- Shows cleanup categories and plain remediation hints.
- Does not expose other accounts or server-wide paths.
- User-triggered refreshes are rate limited by default.
- cPanel refresh limits can be overridden by cPanel package name.

### WHMCS

- Addon module under `modules/addons/help4_disk_usage`.
- Admin dashboard for synced servers and offender accounts.
- cPanel server list from WHMCS `tblservers`.
- Deployment/check/sync actions for cPanel servers.
- Manual deployment command when one-click SSH deploy is unavailable.
- Per-account scan data mapped to `tblhosting` by server ID and cPanel username.
- Customer-area report at `index.php?m=help4_disk_usage`.
- Client navbar link when enabled.
- Event log for deploy/check/sync results.

## Public Usage Walkthrough

A public tutorial is available here:

https://fixitphill.com/whm-cpanel/help4-disk-usage-cpanel-whm-whmcs-disk-inode-reports/

The repository companion guide is in [`docs/usage-guide.md`](docs/usage-guide.md). Use the article for plain-language product and workflow explanation, and use this README for the current release version, install commands, and security notes.

## Requirements

### cPanel & WHM Plugin

- cPanel & WHM with the Jupiter theme.
- Root shell access for install.
- Perl with common core modules: `File::Find`, `File::Path`, `File::Spec`, `Fcntl`, `JSON::PP`, `POSIX`.
- `/usr/local/cpanel/bin/register_appconfig`
- `/usr/local/cpanel/scripts/install_plugin`
- `/usr/local/cpanel/scripts/uninstall_plugin`

### WHMCS Addon

- WHMCS with addon module support.
- PHP compatible with current WHMCS releases.
- WHMCS database access through `WHMCS\Database\Capsule`.
- Optional PHP `ssh2` extension for one-click deploy/check/sync actions.

If `ssh2` is not installed, the module still provides manual deployment commands and can store/report data after scans are synced by another trusted workflow.

## Build a Release

```bash
./scripts/package.sh
```

Output:

```text
outputs/help4-disk-usage-<version>.tar.gz
```

The tarball contains the WHM/cPanel plugin, WHMCS addon, docs, tests, and packaging metadata.

## Install on a cPanel Server

Upload the release tarball to the cPanel server and run:

```bash
tar -xzf help4-disk-usage-0.2.3.tar.gz
cd help4-disk-usage-0.2.3
sudo ./install.sh
```

The installer:

1. Verifies it is running as root on a cPanel server.
2. Creates a timestamped backup under `/root/help4-disk-usage-install-backups/`.
3. Installs the scanner under `/usr/local/cpanel/3rdparty/help4-disk-usage/`.
4. Installs the WHM CGI under `/usr/local/cpanel/whostmgr/docroot/cgi/help4_disk_usage/`.
5. Registers WHM AppConfig from `/var/cpanel/apps/help4_disk_usage.conf`.
6. Installs the cPanel Jupiter plugin icon from `packaging/install.json`.
7. Adds `/etc/cron.d/help4-disk-usage` for background refresh every six hours.
8. Creates `/var/cpanel/help4-disk-usage/config.json` for scan limits.
9. Creates `/var/cpanel/help4-disk-usage/locks/scan.lock` so foreground scans run one at a time.

## Uninstall from a cPanel Server

```bash
sudo ./uninstall.sh
```

The uninstaller snapshots installed files, calls cPanel `uninstall_plugin` when available, unregisters WHM AppConfig, and removes plugin runtime files. It intentionally leaves scan cache data in `/var/cpanel/help4-disk-usage` so operators can decide whether to retain or delete history.

## Install the WHMCS Addon

Copy this directory into your WHMCS install:

```text
integrations/whmcs/modules/addons/help4_disk_usage
```

Target path:

```text
<whmcs-root>/modules/addons/help4_disk_usage
```

Then in WHMCS admin:

1. Go to **System Settings > Addon Modules**.
2. Activate **Help4 Disk Usage**.
3. Configure:
   - Release Tarball URL
   - SSH Port
   - Sync Account Limit
   - Per-Account Scan Max Seconds
   - Client Area Reports
   - Footer Credit
4. Set administrator role access for the addon.
5. Open **Addons > Help4 Disk Usage**.

Activation creates:

```text
mod_help4_disk_usage_servers
mod_help4_disk_usage_accounts
mod_help4_disk_usage_events
```

Deactivation keeps these tables intentionally so support history is not lost.

## WHMCS Deployment Workflow

Open **Addons > Help4 Disk Usage > Servers & Deploy**.

For each cPanel server, WHMCS provides:

- **Check**: verifies expected plugin files exist.
- **Deploy**: downloads the configured release tarball on the cPanel server and runs `install.sh`.
- **Sync**: runs a bounded scanner command and imports JSON summaries into WHMCS.

One-click actions require:

- PHP `ssh2` extension installed in the WHMCS PHP runtime.
- A WHMCS server record with a decryptable root/admin SSH password.
- SSH access from WHMCS to the cPanel server.

If those are not available, use the manual command shown in the WHMCS module:

```bash
set -euo pipefail; tmp="$(mktemp -d /root/help4-disk-usage.XXXXXX)"; cd "$tmp"; curl -fsSL -o help4-disk-usage.tar.gz '<release-url>'; tar -xzf help4-disk-usage.tar.gz; cd help4-disk-usage-*; ./install.sh
```

## WHMCS Customer Reporting

When WHMCS syncs scan JSON, it maps cPanel accounts to WHMCS services by:

- `tblhosting.server` = WHMCS server ID
- `tblhosting.username` = cPanel username

Mapped rows become visible to logged-in customers at:

```text
index.php?m=help4_disk_usage
```

Customers see only their own mapped services and support-safe remediation hints.

## Scanner CLI

Examples:

```bash
/usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-scan --scope all --write-cache
/usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-scan --scope owner --owner reselleruser --write-cache
/usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-scan --scope account --account accountuser --write-cache
```

Useful environment overrides:

```bash
HELP4_DU_MAX_SECONDS=120
HELP4_DU_TOP=50
HELP4_DU_LARGE_MB=250
HELP4_DU_STALE_DAYS=365
HELP4_DU_CACHE_DIR=/var/cpanel/help4-disk-usage
HELP4_DU_LOCK_DIR=/var/cpanel/help4-disk-usage/locks
```

## Scan Limits and Anti-Spam Controls

Help4 Disk Usage is designed so refresh buttons cannot pile up expensive scans.

Defaults:

```json
{
  "whm_scan_max_seconds": 90,
  "cpanel_refreshes_per_hour": 3,
  "cpanel_min_interval_seconds": 300,
  "cpanel_scan_max_seconds": 60,
  "scan_lock_dir": "/var/cpanel/help4-disk-usage/locks",
  "package_overrides": {}
}
```

Root can edit these in WHM under **Help4 Disk Usage > Scan Limits**.

Controls:

- `scan_lock_dir`: shared lock directory. The installer creates a root-owned directory and a writable `scan.lock` file. WHM, cPanel, cron, and WHMCS-triggered installs should use the same lock so only one foreground/cache-writing scan runs at a time.
- `whm_scan_max_seconds`: runtime cap for WHM-triggered scans.
- `cpanel_refreshes_per_hour`: account-level hourly refresh cap for cPanel users.
- `cpanel_min_interval_seconds`: minimum time between cPanel user refreshes.
- `cpanel_scan_max_seconds`: runtime cap for cPanel user scans.
- `package_overrides`: optional per-package cPanel limits.

Package override example:

```json
{
  "premium-hosting": {
    "cpanel_refreshes_per_hour": 6,
    "cpanel_min_interval_seconds": 120,
    "cpanel_scan_max_seconds": 90
  },
  "starter-hosting": {
    "cpanel_refreshes_per_hour": 2,
    "cpanel_min_interval_seconds": 900,
    "cpanel_scan_max_seconds": 45
  }
}
```

cPanel user throttle state is stored under the account's own `.cpanel/help4-disk-usage/rate.json`. It does not grant cross-account visibility.

## Security Model

- Root WHM users see all accounts.
- WHM resellers see only owned accounts.
- cPanel users see only their own account.
- cPanel customer output renders relative paths only.
- Scanner does not follow symlinks.
- Scanner prunes `virtfs`, `.cagefs`, and `.trash`.
- Scanner does not cross filesystem device boundaries from account home.
- GUI-triggered scans use a shared non-blocking lock.
- cPanel user refreshes are throttled by account and can be package-specific.
- Cleanup is not automated.
- WHMCS stores summaries and hints, not destructive cleanup commands.
- WHMCS strips absolute scanner paths before storing support summary lists.
- WHMCS client reports re-check the current WHMCS service mapping for the logged-in client before rendering each row.
- JSON cache files should not be made web-accessible.

## Performance Model

Help4 Disk Usage avoids a slow, stale page-load scan pattern:

- background scans via cron
- bounded foreground refreshes
- shared scan locking
- per-account cPanel refresh throttles
- per-account JSON cache
- atomic cache writes
- explicit scan-complete flags
- visible timestamps
- top-N offender lists
- WHMCS sync limits for staged rollout

## Screenshots

Screenshot deliverables from Genie validation are stored in:

```text
outputs/screenshots/
```

Expected set:

- WHM root dashboard.
- cPanel account report.
- Marketing composite or annotated screenshots.

Live authenticated screenshots require a working browser/Computer Use session. The included screenshots are generated from verified Genie-rendered HTML evidence.

## Genie Validation

Genie was the first live target.

Verified on Genie:

- cPanel 136.0 build 24.
- WHM AppConfig registration.
- cPanel Jupiter dynamicUI registration.
- WHM root render.
- cPanel account render for `adpoveva`.
- cPanel output without raw JSON or absolute `/home/` path leakage.
- Bounded sample scans without timeout.
- Cron installed.

Do not deploy to gohoster or dolce01 until Genie review and WHMCS integration review are complete.

## Marketing Notes

Positioning:

> Help4 Disk Usage gives hosting teams fast, support-ready disk and inode reports for WHM, cPanel, and WHMCS.

Primary value:

- Fewer blind quota conversations.
- Faster support triage.
- Clear customer-facing cleanup hints.
- Better visibility into cache, logs, backups, mail, uploads, temp files, and inode-heavy trees.
- Fresh timestamps instead of mystery cached data.

Audience:

- Shared hosting providers.
- Managed WordPress hosts.
- WHMCS-based hosting companies.
- cPanel server operators.
- Agencies managing many cPanel accounts.

## Compatibility Notes

This package follows public cPanel and WHMCS module conventions:

- WHM registration uses AppConfig.
- cPanel interface registration uses `install.json`.
- cPanel Jupiter links target a `*.live.pl` page.
- WHM plugin files are installed below `whostmgr/docroot/cgi`.
- Runtime code is stored below `/usr/local/cpanel/3rdparty/help4-disk-usage`.
- WHMCS integration is an addon module under `modules/addons/help4_disk_usage`.
- WHMCS admin output uses the addon module `_output` function.
- WHMCS client output uses `_clientarea`.
- WHMCS hooks live in `hooks.php`.

References:

- [WHMCS Addon Modules](https://developers.whmcs.com/addon-modules/)
- [WHMCS Addon Configuration](https://developers.whmcs.com/addon-modules/configuration/)
- [WHMCS Addon Installation & Uninstallation](https://developers.whmcs.com/addon-modules/installation-uninstallation/)
- [WHMCS Admin Area Output](https://developers.whmcs.com/addon-modules/admin-area-output/)
- [WHMCS Client Area Output](https://developers.whmcs.com/addon-modules/client-area-output/)
- [WHMCS Addon Hooks](https://developers.whmcs.com/addon-modules/hooks/)
- [cPanel WHM AppConfig Configuration](https://api.docs.cpanel.net/guides/guide-to-whm-plugins/guide-to-whm-plugins-appconfig-configuration-file)
- [cPanel Plugin Installation](https://api.docs.cpanel.net/guides/guide-to-cpanel-plugins/guide-to-cpanel-plugins-add-plugins)

## Tests

Run scanner and security boundary smoke tests:

```bash
./tests/smoke_scanner.sh
./tests/security_boundaries.sh
```

Run syntax checks:

```bash
perl -c src/bin/help4-disk-usage-scan
perl -c src/whm/index.cgi
perl -c src/cpanel/index.live.pl
php -l integrations/whmcs/modules/addons/help4_disk_usage/help4_disk_usage.php
php -l integrations/whmcs/modules/addons/help4_disk_usage/hooks.php
```

## License

MIT License. Use it, modify it, ship it, include it in hosting stacks, and package it with commercial products. Keep the Help4 credit visible.
By default, the WHMCS module uses the public GitHub `main.tar.gz` archive. For production release management, publish a GitHub Release tarball and set **Release Tarball URL** to that immutable asset.
