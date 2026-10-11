# Genie Validation Checklist

Genie is the first live canary for each new candidate. Gate the existing gohoster02 and dolce01 installations separately after Genie validation; a successful collector CI job does not certify a native panel installation or CloudLinux/CageFS behavior.

The source currently packages 1.0.2 as a candidate; the stable updater remains on immutable 1.0.1 until release approval. Do not assume that a candidate version, passing CI or one successful server install closes the remaining native role/lifecycle gates.

## Preflight

- Confirm current server identity.
- Confirm cPanel commands exist:
  - `/usr/local/cpanel/bin/register_appconfig`
  - `/usr/local/cpanel/scripts/install_plugin`
  - `/usr/local/cpanel/scripts/uninstall_plugin`
- Record the currently installed version and immutable release tag before install.
- Confirm whether a previous `help4_disk_usage` AppConfig registration exists.
- Run `bash install.sh --check` from the exact reviewed source; require exit zero before writing. Resolve any flagged path under administrator control without a broad permission rewrite or disabling the audit.
- Record panel version, boot identity, configuration, cron and logrotate hashes. Do not update the panel/OS or reboot as part of plugin validation.
- Verify the candidate archive checksum and source identity, and verify that the prior immutable release archive remains available for rollback. Do not create routine snapshots.

## Install

For an explicitly approved 1.0.2 candidate canary, verify the locally packaged archive against its reviewed checksum before extraction, then run:

```bash
tar -xzf help4-disk-usage-1.0.2.tar.gz
cd help4-disk-usage-1.0.2
bash install.sh --check
HELP4_DU_BACKUP_DIR='' bash install.sh
```

This is not a command to download an unapproved stable tag. Use the matching package instructions in the README and retain the exact commit/archive identity privately.

Record:

- install output
- previous release tag
- AppConfig registration status
- cPanel plugin install status
- cron file content
- exact installed runtime file hashes and permissions
- preserved policy/configuration and cron/logrotate hashes

cPanel registration adds `name=help4_disk_usage` to AppConfig and stores the registered file as `0600`. Compare the complete normalized key/value set and safe ownership, not byte equality with the unregistered source file. Unexpected keys, changed values or duplicate keys must fail verification.

## Runtime Checks

```bash
: "${APPROVED_ACCOUNT:?Set one explicitly authorized test account}"
/usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-scan \
  --scope account --account "$APPROVED_ACCOUNT" --max-seconds 20 --top 5 --write-cache
```

Verify:

- scan exits without timeout
- account JSON exists
- `scan_complete`, `scanned_at`, `disk_bytes`, `inode_count`, and offender arrays are present
- cache/log/temp/backup hints appear where applicable
- the actual unprivileged account cannot scan a foreign identity or read another account's root-owned cache
- busy scans are rejected rather than queued without bounds; keep the shared lock and account/package limits enabled

## UI Checks

- WHM root surface loads.
- WHM root can refresh all or one account.
- WHM reseller surface loads and does not display unowned accounts.
- cPanel account surface loads.
- cPanel account refresh scans only that account.
- cPanel account page renders relative paths, not other account paths.
- Check native WHM navigation and Jupiter header/footer, with no nested standalone page or LiveAPI/parse error.
- Check positive reseller ownership and negative foreign detail/export/action routes with a real authenticated reseller session; trusted CLI rendering alone is not that session proof.
- Click a file and a directory into their correct native File Manager destinations; preserve the report and account session. Reject unavailable or foreign locations without path disclosure.
- Check search, sort, paging and scoped exports. Reload after one POST and leave the page idle for at least five minutes; the scan timestamp and refresh attempt count must not change without another authorized action.
- Stop the affected browser checks at a login, security or extension-confirmation prompt. Record the gate rather than bypass it or relabel CLI/fixture results as GUI proof.

## Lifecycle Gates

Test populated-cache upgrade and idempotent reinstall while preserving settings. Fresh installation and uninstall belong in an explicitly authorized disposable, licensed cPanel lab, not on a production canary to satisfy a checklist. Record any unavailable lifecycle or OS-specific lanes as unverified. Do not infer native WHMCS framework, roles, transport or database locking from addon fixtures.

## Evidence

Save private evidence under an ignored, administrator-owned `0700` directory such as `outputs/genie-validation-<timestamp>/`; use `0600` for reports and captures:

- `preflight.txt`
- `install.txt`
- `scan-sample.json`
- `cache-list.txt`
- `whm-root.html` or screenshot
- `whm-reseller.html` or screenshot
- `cpanel-account.html` or screenshot
- `permissions.txt`

Retain exact source/package hashes and distinguish passed, failed and unmeasured gates. Customer identities, paths, IPs, sessions and native screenshots stay private. Public tutorials use version-matched synthetic screenshots and a sanitized summary, never the private capture directory.

## Rollback

```bash
/usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-update --check
# Reinstall the required prior immutable release tag if rollback is needed.
```

Verify the prior archive checksum and current destination safety before rollback. A permission-only prerequisite repair needs a separate exact path/owner/inode/mode rollback receipt; do not restore unrelated vendor directories, caches or customer files.
