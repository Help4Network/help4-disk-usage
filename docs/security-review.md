# Security Review Notes

## Boundaries

- WHM root: all accounts.
- WHM reseller: accounts where `/var/cpanel/users/<account>` contains `OWNER=<reseller>`.
- cPanel user: authenticated account only, with relative paths rendered.
- WHMCS admin: synced summary data across mapped servers.
- WHMCS client: only synced rows where `client_id` matches the logged-in client.
- WHMCS client rendering also re-checks the current `tblhosting` service ID, server ID, username, and logged-in client before displaying a row.

## Data Locations

- Root/WHM cache: `/var/cpanel/help4-disk-usage/accounts/*.json`
- cPanel user cache: `$HOME/.cpanel/help4-disk-usage/accounts/<user>.json`
- cPanel user refresh throttle state: `$HOME/.cpanel/help4-disk-usage/rate.json`
- cPanel action nonce: `$HOME/.cpanel/help4-disk-usage/action-nonce.json`
- Shared scan config: `/var/cpanel/help4-disk-usage/config.json`
- Shared scan lock: `/var/cpanel/help4-disk-usage/locks/scan.lock`
- WHMCS tables: `mod_help4_disk_usage_servers`, `mod_help4_disk_usage_accounts`, `mod_help4_disk_usage_events`
- Runtime scanner: `/usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-scan`
- WHM UI: `/usr/local/cpanel/whostmgr/docroot/cgi/help4_disk_usage/index.cgi`
- cPanel UI: `/usr/local/cpanel/base/frontend/jupiter/help4_disk_usage/index.live.pl`

## Controls

- Scanner prunes `virtfs`, `.cagefs`, and `.trash`.
- Scanner does not follow symlinks.
- Scanner does not cross device boundaries from the account home.
- Scanner does not emit absolute file paths in large-file or hotspot item lists.
- Non-root scanner runs must use `--scope account`, must match the effective OS account, and must scan that account's home directory.
- WHM reseller authorization is based on live `/var/cpanel/users/<account>` ownership for the account username, not cached owner metadata.
- Result sets are capped by `HELP4_DU_TOP`.
- Whole-run runtime is capped by `HELP4_DU_MAX_SECONDS`; it is not multiplied by the account count.
- Bounded all/owner scans rotate missing or oldest caches first and report pending account counts.
- Cache writes are atomic.
- WHM, cPanel, cron, and WHMCS-triggered scanner runs can share one non-blocking lock file.
- The installer creates a root-owned lock directory and a writable lock file so users can lock but cannot create or delete lock-directory entries.
- cPanel user refreshes default to three per hour, with a five-minute minimum interval and a 60-second scan runtime cap.
- WHM root can edit cPanel refresh limits, cPanel scan caps, WHM scan caps, and package-specific overrides in the WHM UI.
- WHM and cPanel state-changing actions require POST plus a 30-minute server-side nonce.
- WHM fails closed when cPanel does not supply an authenticated `REMOTE_USER`.
- cPanel rejects authenticated/runtime identity mismatches and resolves home directories from the system password database.
- UI performs output escaping for rendered values.
- WHMCS one-click deploy/check/update/sync uses PHP `ssh2` or WHMCS-bundled phpseclib 2/3, and requires a verified SHA-256 host fingerprint before authentication, a bounded remote command, and a verified remote exit status.
- The WHMCS dashboard widget requires the `Perform Server Operations` administrator permission.
- WHM and WHMCS apply/deploy flows require HTTPS and a manifest SHA-256 match before extracting a package.
- The updater rejects archive traversal paths, multi-root archives, archive links, excessive entry counts, and package/manifest version mismatches.
- Updater install output is written only inside its root-owned private temporary directory.
- WHMCS sync ignores invalid account usernames, normalizes severity values, and strips unsupported fields from synced scan item arrays.
- WHMCS does not perform file deletion or cleanup actions.

## Known Review Items

- Confirm `REMOTE_USER` and cPanel `*.live.pl` identity behavior on every supported cPanel release family; Genie is the current live validation target.
- Decide whether the default six-hour cron cadence should be configurable during install.
- Consider a future UAPI module if cPanel review prefers API separation over a `live.pl` page.
- Verify every WHMCS SSH host-key pin against the target server console before enabling one-click deployment.
- Confirm customer report copy with support/marketing before exposing to all clients.

## Residual Risks

- A compromised cPanel account can hold the shared advisory scan lock and delay plugin scans. This blocks only Help4 Disk Usage collection; the account already has the ability to run its own filesystem traversal. Root can identify the lock holder and restart collection.
- The public update manifest is an online trust root. Operators that require stronger supply-chain control should mirror the manifest and immutable package into infrastructure they control.
- Scan results are observations and cleanup hints, not proof that a path is safe to delete. The plugin never deletes files.
