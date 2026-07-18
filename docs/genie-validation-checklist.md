# Genie Validation Checklist

Genie is the first live target. Do not deploy this plugin to gohoster or dolce01 until Genie validation is complete.

## Preflight

- Confirm current server identity.
- Confirm cPanel commands exist:
  - `/usr/local/cpanel/bin/register_appconfig`
  - `/usr/local/cpanel/scripts/install_plugin`
  - `/usr/local/cpanel/scripts/uninstall_plugin`
- Record the currently installed version and immutable release tag before install.
- Confirm whether a previous `help4_disk_usage` AppConfig registration exists.

## Install

```bash
tar -xzf help4-disk-usage-0.1.0.tar.gz
cd help4-disk-usage-0.1.0
./install.sh
```

Record:

- install output
- previous release tag
- AppConfig registration status
- cPanel plugin install status
- cron file content

## Runtime Checks

```bash
/usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-scan --scope all --account-limit 3 --write-cache
find /var/cpanel/help4-disk-usage -maxdepth 2 -type f -ls
```

Verify:

- scan exits without timeout
- account JSON exists
- `scan_complete`, `scanned_at`, `disk_bytes`, `inode_count`, and offender arrays are present
- cache/log/temp/backup hints appear where applicable

## UI Checks

- WHM root surface loads.
- WHM root can refresh all or one account.
- WHM reseller surface loads and does not display unowned accounts.
- cPanel account surface loads.
- cPanel account refresh scans only that account.
- cPanel account page renders relative paths, not other account paths.

## Evidence

Save under `outputs/genie-validation-<timestamp>/`:

- `preflight.txt`
- `install.txt`
- `scan-sample.json`
- `cache-list.txt`
- `whm-root.html` or screenshot
- `whm-reseller.html` or screenshot
- `cpanel-account.html` or screenshot
- `permissions.txt`

## Rollback

```bash
/usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-update --check
# Reinstall the required prior immutable release tag if rollback is needed.
```
