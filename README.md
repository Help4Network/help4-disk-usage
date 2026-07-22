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
src/bin/help4-disk-usage-update                       Backup-first release checker/updater
src/whm/index.cgi                                     WHM root/reseller dashboard
src/whm/templates/index.tmpl                          Native WHM master-template wrapper
src/cpanel/index.live.pl                              cPanel account page
src/static/                                           Shared UI assets
packaging/                                            cPanel/WHM plugin metadata
integrations/whmcs/modules/addons/help4_disk_usage/   WHMCS addon module
docs/                                                 Security, validation, and marketing notes
tests/                                                Local scanner smoke tests
scripts/package.sh                                    Release tarball builder
install.sh                                            cPanel/WHM installer
uninstall.sh                                          cPanel/WHM uninstaller
CHANGELOG.md                                          Release history
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
- Whole-run scan budgets with oldest-cache-first rotation for large fleets.
- POST-only scan, settings, and update actions protected by short-lived nonces.
- Root update panel for checking/applying configured repository or release tarball updates.

### cPanel

- Account-scoped page in Jupiter, listed under **Files** with the official H4 mark.
- Uses cPanel's LiveAPI lifecycle so the standard Jupiter navigation and authenticated session remain intact.
- Scans only the authenticated account home directory.
- Renders relative paths only.
- Shows cleanup categories and plain remediation hints.
- Does not expose other accounts or server-wide paths.
- User-triggered refreshes are rate limited by default.
- cPanel refresh limits can be overridden by cPanel package name.
- Refresh actions are POST-only and protected by an account-local nonce.

### WHMCS

- Addon module under `modules/addons/help4_disk_usage`.
- Admin dashboard for synced servers and offender accounts.
- WHMCS admin-home widget with health counts and prioritized server rows.
- Admin **Server Health** view across WHMCS cPanel server records.
- cPanel server list from WHMCS `tblservers`.
- Deployment/check/update/sync actions for cPanel servers.
- Fail-closed SSH host-key pinning for remote actions.
- Verified remote exit status, bounded execution time, and bounded output.
- Health states for missing, stale, erroring, disabled, attention-needed, and healthy servers.
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
- Perl with common core modules: `File::Find`, `File::Path`, `File::Spec`, `Fcntl`, `JSON::PP`, `POSIX`, `Sys::Hostname`.
- `/usr/local/cpanel/bin/register_appconfig`
- `/usr/local/cpanel/scripts/install_plugin`
- `/usr/local/cpanel/scripts/uninstall_plugin`

### WHMCS Addon

- WHMCS with addon module support.
- PHP compatible with current WHMCS releases.
- WHMCS database access through `WHMCS\Database\Capsule`.
- A supported SSH transport for one-click deploy/check/update/sync actions: PHP `ssh2`, bundled phpseclib 2, or bundled phpseclib 3.

The addon prefers PHP `ssh2` and falls back to WHMCS's bundled phpseclib. If neither transport is available, it still provides manual deployment commands and can store/report data after scans are synced by another trusted workflow.

## Build a Release

```bash
./scripts/package.sh
./scripts/package-whmcs.sh
```

Output:

```text
outputs/help4-disk-usage-<version>.tar.gz
outputs/help4-disk-usage-whmcs-<version>.zip
outputs/help4-disk-usage-whmcs-<version>.zip.sha256
```

The tarball contains the complete WHM/cPanel plugin, WHMCS addon, docs, tests, and packaging metadata. The zip is a standalone WHMCS addon package that extracts directly below `modules/addons/`.

CI runs shell syntax checks, Perl syntax checks, PHP syntax checks, scanner smoke tests, security-boundary smoke tests, standalone WHMCS package validation, and release packaging on pushes and pull requests. Version-tag pushes publish both install packages and their checksums to GitHub Releases.

## Install on a cPanel Server

Upload the release tarball to the cPanel server and run:

```bash
tar -xzf help4-disk-usage-0.3.7.tar.gz
cd help4-disk-usage-0.3.7
sudo ./install.sh
```

The installer:

1. Verifies it is running as root on a cPanel server.
2. Installs the scanner under `/usr/local/cpanel/3rdparty/help4-disk-usage/`.
3. Installs the WHM CGI under `/usr/local/cpanel/whostmgr/docroot/cgi/help4_disk_usage/`.
4. Installs the WHM Template Toolkit wrapper under `/usr/local/cpanel/whostmgr/docroot/templates/help4_disk_usage/` so the dashboard stays inside WHM's normal navigation shell.
5. Registers WHM AppConfig from `/var/cpanel/apps/help4_disk_usage.conf`.
6. Installs the cPanel Jupiter plugin icon from `packaging/install.json`.
7. Adds `/etc/cron.d/help4-disk-usage` for background refresh every six hours.
8. Creates `/var/cpanel/help4-disk-usage/config.json` for scan limits, display-name override, footer prefix, release URL, and update manifest URL.
9. Creates `/var/cpanel/help4-disk-usage/locks/scan.lock` so foreground scans run one at a time.
10. Writes `/var/cpanel/help4-disk-usage/install.json` with the installed version and release channel.

Git tags and checksummed release archives are the default rollback source. The installer does not create filesystem snapshots unless `HELP4_DU_BACKUP_DIR` is explicitly set.

## Updates

Installed cPanel servers include:

```text
/usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-update
```

The updater reads the configured update manifest, compares the published version with the installed scanner, and avoids downloading the package when a check already proves the server is current. Apply operations require the manifest's SHA-256 digest to match the downloaded package before extraction. Roll back by reinstalling a prior immutable tag; automatic filesystem snapshots are disabled by default.

Manual check:

```bash
sudo /usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-update --check
```

Manual update:

```bash
sudo /usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-update --apply
```

WHM root users can use **Help4 Disk Usage > Repository Updates** to check or apply the configured release. The update manifest URL and fallback release URL are stored in `/var/cpanel/help4-disk-usage/config.json`.

The default update manifest is:

```text
https://raw.githubusercontent.com/Help4Network/help4-disk-usage/main/update.json
```

The manifest publishes `version`, immutable `package_url`, required `sha256`, and optional `release_notes_url`. Update URLs must use HTTPS and may not contain embedded credentials. A check reads only the small manifest when it already contains a version; it downloads the package only when an apply or fallback inspection is needed.

Multi-server rollout notes are in [`docs/rollout.md`](docs/rollout.md).

## Uninstall from a cPanel Server

```bash
sudo ./uninstall.sh
```

The uninstaller calls cPanel `uninstall_plugin` when available, unregisters WHM AppConfig, and removes plugin runtime files. It intentionally leaves scan cache data in `/var/cpanel/help4-disk-usage` so operators can decide whether to retain or delete history. Set `HELP4_DU_BACKUP_DIR` only when an explicit filesystem snapshot is required.

## Install the WHMCS Addon

Download these files from [GitHub Releases](https://github.com/Help4Network/help4-disk-usage/releases/latest):

```text
help4-disk-usage-whmcs-<version>.zip
help4-disk-usage-whmcs-<version>.zip.sha256
```

Verify the package:

```bash
sha256sum -c help4-disk-usage-whmcs-<version>.zip.sha256
```

Set the WHMCS root and extract the package. A prior immutable release ZIP is the rollback source:

```bash
export WHMCS_ROOT=/path/to/whmcs
test -f "$WHMCS_ROOT/init.php"
unzip -qo help4-disk-usage-whmcs-<version>.zip -d "$WHMCS_ROOT/modules/addons"
chown -R --reference="$WHMCS_ROOT/modules/addons" \
  "$WHMCS_ROOT/modules/addons/help4_disk_usage"
php -l "$WHMCS_ROOT/modules/addons/help4_disk_usage/help4_disk_usage.php"
php -l "$WHMCS_ROOT/modules/addons/help4_disk_usage/hooks.php"
```

The final entry point must be:

```text
<whmcs-root>/modules/addons/help4_disk_usage/help4_disk_usage.php
```

Then in WHMCS admin:

1. Go to **System Settings > Addon Modules**.
2. Activate **Help4 Disk Usage**.
3. Configure:
   - Release Tarball URL
   - Update Manifest URL
   - SSH Port
   - SSH Host Fingerprints
   - Allow Unpinned SSH (leave off)
   - Sync Account Limit
   - Whole Sync Scan Max Seconds
   - Client Area Reports
   - Display Name
   - Footer Credit Prefix
4. Set administrator role access for the addon.
5. Open **Addons > Help4 Disk Usage**.

Use conservative first-run limits such as **Sync Account Limit = 2** and **Whole Sync Scan Max Seconds = 15**. Verify each server's SSH host key from its console and leave **Allow Unpinned SSH** off.

Activation creates:

```text
mod_help4_disk_usage_servers
mod_help4_disk_usage_accounts
mod_help4_disk_usage_events
```

Deactivation keeps these tables intentionally so support history is not lost.

The detailed operator guide, including server-record preparation, fingerprint pinning, first-run verification, upgrades, removal, troubleshooting, and rollback notes, is in [`docs/whmcs-integration.md`](docs/whmcs-integration.md).

## Upgrade the WHMCS Addon

Do not deactivate the addon for a normal upgrade. Verify the new ZIP and extract it over `modules/addons/`. Then save the addon settings and open the addon so WHMCS detects the changed configuration version and runs the module upgrade function. Roll back by reinstalling the previous immutable release ZIP.

```bash
export WHMCS_ROOT=/path/to/whmcs
unzip -qo help4-disk-usage-whmcs-<version>.zip -d "$WHMCS_ROOT/modules/addons"
chown -R --reference="$WHMCS_ROOT/modules/addons" \
  "$WHMCS_ROOT/modules/addons/help4_disk_usage"
```

Confirm the module version, Server Health page, admin-home widget, and a mapped client report after upgrading.

## WHMCS Deployment Workflow

WHMCS admins also get a **Help4 Disk Usage Health** widget on the WHMCS admin home dashboard. It shows health counts, the highest-priority cPanel server rows, and a direct link to the full health page.

Open **Addons > Help4 Disk Usage > Server Health** for the full support/admin operations view.

Server Health shows:

- Healthy, attention, stale, error, not checked, not synced, and disabled server counts.
- Last scan age and scanned account coverage.
- Bad/check finding counts per server.
- Last error text from deploy/check/sync.
- Next-step guidance for each server.
- Check, Deploy, and Sync actions for eligible cPanel/WHM server records.

Open **Addons > Help4 Disk Usage > Servers & Deploy** for the install/sync workflow.

For each cPanel server, WHMCS provides:

- **Check**: verifies expected plugin files exist and compares installed/available versions from the configured update manifest.
- **Deploy**: downloads the package named by the update manifest, verifies its SHA-256 digest, and runs `install.sh`.
- **Update**: runs the cPanel-side updater when present, or falls back to the checksummed installer for older installs.
- **Sync**: runs a bounded scanner command and imports JSON summaries into WHMCS.

One-click actions require:

- PHP `ssh2` or WHMCS-bundled phpseclib 2/3 in the WHMCS PHP runtime.
- A WHMCS server record with a decryptable root/admin SSH password.
- SSH access from WHMCS to the cPanel server.
- A verified SSH host fingerprint mapped by server ID, hostname, or IP.

The addon uses its **Default SSH Port** setting for SSH. It does not use the WHMCS server record port, because cPanel server records commonly store the WHM/API port such as `2087`. Remote actions fail closed when no matching host fingerprint exists unless an administrator deliberately enables the unsafe compatibility override.

The first blocked connection reports the negotiated fingerprint without authenticating. Verify it against the server console, for example with `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub -E sha256`, then enter JSON such as:

```json
{
  "6": "SHA256:verified-fingerprint-from-server-console"
}
```

If SSH automation is unavailable, upload a verified release tarball and use the normal cPanel-server install steps.

## WHMCS Customer Reporting

When WHMCS syncs scan JSON, it maps cPanel accounts to WHMCS services by:

- `tblhosting.server` = WHMCS server ID
- `tblhosting.username` = cPanel username

Mapped rows become visible to logged-in customers at:

```text
index.php?m=help4_disk_usage
```

Customers see only their own mapped services and support-safe remediation hints.

## Remove the WHMCS Addon

Deactivate **Help4 Disk Usage** under **System Settings > Addon Modules**, and then remove `modules/addons/help4_disk_usage`.

Deactivation intentionally retains the `mod_help4_disk_usage_*` tables so support history is not silently destroyed. Removing the WHMCS addon does not uninstall the cPanel/WHM plugin from managed servers.

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
  "display_name": "Disk Usage Audit",
  "credit_prefix": "Built by",
  "scan_lock_dir": "/var/cpanel/help4-disk-usage/locks",
  "update_manifest_url": "https://raw.githubusercontent.com/Help4Network/help4-disk-usage/main/update.json",
  "package_overrides": {}
}
```

Root can edit these in WHM under **Help4 Disk Usage > Scan Limits**. The display name and footer prefix are intentionally customizable so hosts can match their support portal, but every page keeps the small linked `Help4 Network` builder byline.

Controls:

- `scan_lock_dir`: shared lock directory below `/var/cpanel/help4-disk-usage`. The installer creates a root-owned directory and a writable advisory `scan.lock` file. WHM, cPanel, cron, and WHMCS-triggered scans use the same lock so only one cache-writing scan runs at a time.
- `whm_scan_max_seconds`: whole-run runtime cap for WHM-triggered scans.
- `cpanel_refreshes_per_hour`: account-level hourly refresh cap for cPanel users.
- `cpanel_min_interval_seconds`: minimum time between cPanel user refreshes.
- `cpanel_scan_max_seconds`: whole-run runtime cap for cPanel user scans.
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

When a whole-server scan reaches its budget, the scanner writes the completed account caches, reports `accounts_remaining`, and rotates the oldest or missing cache to the front on the next run. This prevents the first accounts alphabetically from monopolizing every bounded scan.

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
- WHM and cPanel state-changing actions require POST plus a short-lived nonce.
- Cleanup is not automated.
- WHMCS stores summaries and hints, not destructive cleanup commands.
- WHMCS deploy/check/update/sync POST actions are restricted to WHMCS server records whose module type is cPanel/WHM-like.
- WHMCS SSH actions verify a configured SHA-256 host fingerprint before password authentication unless the explicit unsafe override is enabled.
- WHMCS remote commands require a verified exit marker, have a bounded execution timeout, and cap captured output at 16 MiB.
- Update apply and bootstrap deployment require HTTPS plus a manifest SHA-256 match before extraction.
- WHMCS strips absolute scanner paths before storing support summary lists.
- WHMCS client reports re-check the current WHMCS service mapping for the logged-in client before rendering each row.
- JSON cache files should not be made web-accessible.

## Performance Model

Help4 Disk Usage avoids a slow, stale page-load scan pattern:

- background scans via cron
- bounded foreground refreshes
- oldest-cache-first incremental rotation
- shared scan locking
- per-account cPanel refresh throttles
- per-account JSON cache
- atomic cache writes
- explicit scan-complete flags
- explicit remaining-account and full-scope-complete metadata
- visible timestamps
- top-N offender lists
- WHMCS sync limits for staged rollout
- checksum-verified update checks before release pulls

## Screenshots

Screenshot deliverables from Genie validation are stored in:

```text
outputs/screenshots/
```

Expected set:

- WHM root dashboard.
- cPanel account report.
- WHMCS deployment and reporting.
- WHMCS admin-home health widget.
- WHMCS server health.
- WHMCS client report.

Public screenshots are generated entirely from dummy fixtures. Live authenticated screenshots and raw live HTML are engineering evidence only and must not be placed in public tutorial packages.

With Node.js, Playwright, `zip`, and `rg` available, rebuild the privacy-checked tutorial bundle with:

```bash
./scripts/build-tutorial-pack.sh
```

## Genie Validation

Genie was the first live target.

Verified on Genie:

- cPanel 136.0 build 24.
- WHM AppConfig registration.
- cPanel Jupiter dynamicUI registration.
- WHM root render.
- cPanel account render for a real account identity, omitted from public artifacts.
- cPanel output without raw JSON or absolute `/home/` path leakage.
- Bounded sample scans without timeout.
- Cron installed.

The live rollout used Genie as the first validation target, followed by gohoster02 and dolce01 after the Genie and WHMCS review gates passed. Operators should still use the immutable-release, staged-limit, and verification gates in [`docs/rollout.md`](docs/rollout.md) for every environment.

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
- WHM output uses cPanel's bundled Perl and `master_templates/master.tmpl`, preserving the normal left navigation and right-side content area.
- Runtime code is stored below `/usr/local/cpanel/3rdparty/help4-disk-usage`.
- WHMCS integration is an addon module under `modules/addons/help4_disk_usage`.
- WHMCS admin output uses the addon module `_output` function.
- WHMCS client output uses `_clientarea`.
- WHMCS hooks live in `hooks.php`.

References:

- [WHMCS Addon Modules](https://developers.whmcs.com/addon-modules/)
- [WHMCS Addon Configuration](https://developers.whmcs.com/addon-modules/configuration/)
- [WHMCS Addon Installation & Uninstallation](https://developers.whmcs.com/addon-modules/installation-uninstallation/)
- [WHMCS Addon Upgrades](https://developers.whmcs.com/addon-modules/upgrades/)
- [WHMCS Admin Area Output](https://developers.whmcs.com/addon-modules/admin-area-output/)
- [WHMCS Client Area Output](https://developers.whmcs.com/addon-modules/client-area-output/)
- [WHMCS Module Hooks](https://developers.whmcs.com/hooks/module-hooks/)
- [cPanel WHM AppConfig Configuration](https://api.docs.cpanel.net/guides/guide-to-whm-plugins/guide-to-whm-plugins-appconfig-configuration-file)
- [cPanel WHM Plugin Interfaces](https://api.docs.cpanel.net/guides/guide-to-whm-plugins/guide-to-whm-plugins-plugin-files/guide-to-whm-plugins-interfaces/)
- [cPanel WHM Plugin Files](https://api.docs.cpanel.net/guides/guide-to-whm-plugins/guide-to-whm-plugins-plugin-files/)
- [cPanel Plugin Installation](https://api.docs.cpanel.net/guides/guide-to-cpanel-plugins/guide-to-cpanel-plugins-add-plugins)

## Tests

Run scanner, security boundary, and branding/update contract smoke tests:

```bash
./tests/smoke_scanner.sh
./tests/security_boundaries.sh
./tests/branding_update_contract.sh
./tests/request_security.sh
./tests/whmcs_package.sh
```

Run syntax checks:

```bash
perl -c src/bin/help4-disk-usage-scan
perl -c src/whm/index.cgi
PERL5LIB=tests/lib perl -c src/cpanel/index.live.pl
php -l integrations/whmcs/modules/addons/help4_disk_usage/help4_disk_usage.php
php -l integrations/whmcs/modules/addons/help4_disk_usage/hooks.php
bash -n scripts/package-whmcs.sh
```

## License

MIT License. Use it, modify it, ship it, include it in hosting stacks, and package it with commercial products. Keep the Help4 credit visible.
