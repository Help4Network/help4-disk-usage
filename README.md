# Help4 Disk Usage

Help4 Disk Usage is a cPanel & WHM plugin for fast, actionable disk and inode audits on shared hosting servers.

It is based on the Help4 Network script [`find_large_files_and_inodes`](https://github.com/Help4Network/find_large_files_and_inodes), but reshaped into an installable WHM/cPanel plugin with cached background scans, role-scoped views, and cleanup hints for real hosting operations.

## What It Does

- WHM dashboard for root and resellers.
- cPanel account view for the authenticated account only.
- Per-account disk and inode scan cache with visible last-scanned timestamps.
- Background scan cron so the UI does not depend on a slow foreground walk.
- Manual refresh for all accounts, reseller-owned accounts, or one account.
- Action-first offenders:
  - largest files
  - stale large files
  - inode-heavy directories
  - byte-heavy directories
  - cache, log, temp, backup, mail, dependency, and uploads hotspots
  - growth since the previous scan where cache history exists
- Remediation hints that point hosts toward safe next steps instead of a static file dump.

## Current Status

This is an initial public-review build. It is ready for local review, packaging, and first live validation on Genie only.

Do not roll this to gohoster or dolce01 yet. Those are future rollout targets after Genie validation and cPanel review feedback.

## Requirements

- cPanel & WHM with the Jupiter theme.
- Root shell access for install, WHM AppConfig registration, cPanel plugin registration, and background scanning.
- Perl with core modules used by cPanel-era systems: `File::Find`, `File::Path`, `File::Spec`, `Fcntl`, `JSON::PP`, and `POSIX`.
- `/usr/local/cpanel/bin/register_appconfig`
- `/usr/local/cpanel/scripts/install_plugin`

## Install

From an unpacked release tarball on the cPanel server:

```bash
sudo ./install.sh
```

The installer:

1. Verifies it is running as root on a cPanel server.
2. Creates a timestamped backup under `/root/help4-disk-usage-install-backups/`.
3. Installs the scanner under `/usr/local/cpanel/3rdparty/help4-disk-usage/`.
4. Installs the WHM CGI under `/usr/local/cpanel/whostmgr/docroot/cgi/help4_disk_usage/`.
5. Registers WHM AppConfig from `/var/cpanel/apps/help4_disk_usage.conf`.
6. Installs the cPanel Jupiter plugin icon using `packaging/install.json`.
7. Adds `/etc/cron.d/help4-disk-usage` for background refresh every six hours.

## Uninstall

```bash
sudo ./uninstall.sh
```

The uninstaller snapshots installed files, calls cPanel `uninstall_plugin` when available, unregisters WHM AppConfig, and removes plugin runtime files. It leaves scan cache data in `/var/cpanel/help4-disk-usage` for manual retention or deletion.

## Packaging

Build a release tarball:

```bash
./scripts/package.sh
```

The tarball is written to `outputs/help4-disk-usage-<version>.tar.gz`.

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
```

## Privilege Model

- Root WHM users can see all cached account records and trigger all-account scans.
- Resellers can see and refresh only accounts whose `/var/cpanel/users/<account>` file has `OWNER=<reseller>`.
- cPanel users get a separate account page that scans only the authenticated user home directory and renders relative paths.
- The cPanel account page stores its own cache under `$HOME/.cpanel/help4-disk-usage`.
- The scanner does not follow symlinks and prunes `virtfs`, `.cagefs`, and `.trash`.
- The scanner does not cross filesystem device boundaries from the account home.

## Performance Model

The default cPanel/WHM disk usage path can feel stale because it is cache-heavy and does not highlight cleanup targets. Help4 Disk Usage is designed around:

- background scans via cron
- bounded foreground scan runtime
- per-account JSON caches
- explicit scan-complete flags
- visible `scanned_at` timestamps
- manual refresh from WHM or cPanel
- small top-N result sets instead of unbounded file listings

The initial collector uses a safe filesystem walk. Future versions can add incremental indexes, filesystem event hints, and cPanel quota metadata without changing the UI contract.

## Security Notes

- Install and WHM scans require root because cross-account filesystem audit requires root on typical shared hosting systems.
- The WHM CGI runs as root through WHM AppConfig and must filter account records before rendering reseller views.
- Do not expose the WHM CGI outside authenticated WHM.
- Do not make `/var/cpanel/help4-disk-usage` web-accessible.
- The cPanel user page renders only relative paths.
- Cleanup is not automated. The plugin reports offenders and hints; a human or separate host policy performs deletions.
- JSON cache files are data, not executable code. Keep permissions restrictive.

## cPanel & WHM Compatibility Notes

This package follows current cPanel public plugin guidance:

- WHM registration uses AppConfig.
- cPanel interface registration uses `install.json`.
- cPanel Jupiter links target a `*.live.pl` file.
- WHM plugin files are installed below `whostmgr/docroot/cgi`.
- Shared runtime code is stored below `/usr/local/cpanel/3rdparty/help4-disk-usage`.

References:

- [Guide to WHM Plugins - AppConfig Configuration File](https://api.docs.cpanel.net/guides/guide-to-whm-plugins/guide-to-whm-plugins-appconfig-configuration-file)
- [Guide to WHM Plugins - Installation Scripts](https://api.docs.cpanel.net/guides/guide-to-whm-plugins/guide-to-whm-plugins-installation-scripts)
- [Guide to cPanel Plugins - Add Plugins](https://api.docs.cpanel.net/guides/guide-to-cpanel-plugins/guide-to-cpanel-plugins-add-plugins)
- [Guide to cPanel Plugins - Uninstall Plugins](https://api.docs.cpanel.net/guides/guide-to-cpanel-plugins/guide-to-cpanel-plugins-uninstall-plugins)

## Tests

Run the local scanner smoke test:

```bash
./tests/smoke_scanner.sh
```

Run Perl syntax checks:

```bash
perl -c src/bin/help4-disk-usage-scan
perl -c src/whm/index.cgi
perl -c src/cpanel/index.live.pl
```

## Screenshot Plan

Capture these after the Genie install:

1. WHM root dashboard after all-account refresh.
2. WHM reseller dashboard proving only owned accounts appear.
3. cPanel account dashboard after own-account refresh.
4. A cache/log/temp/backup hotspot example with remediation hints visible.
5. Evidence that `scanned_at`, scan completeness, and refresh behavior are visible.

Save screenshots and command evidence under `outputs/genie-validation-<timestamp>/`.

## License and Credit

GPLv3. Derived from Help4 Network `find_large_files_and_inodes` and preserving Help4 / Phillip Ley credit.
