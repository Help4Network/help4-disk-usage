# Security Review Notes

## Boundaries

- WHM root: all accounts.
- WHM reseller: accounts where `/var/cpanel/users/<account>` contains `OWNER=<reseller>`.
- cPanel user: authenticated account only, with relative paths rendered.
- WHMCS admin: synced summary data across mapped servers.
- WHMCS client: only synced rows where `client_id` matches the logged-in client.

## Data Locations

- Root/WHM cache: `/var/cpanel/help4-disk-usage/accounts/*.json`
- cPanel user cache: `$HOME/.cpanel/help4-disk-usage/accounts/<user>.json`
- cPanel user refresh throttle state: `$HOME/.cpanel/help4-disk-usage/rate.json`
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
- Result sets are capped by `HELP4_DU_TOP`.
- Runtime is capped by `HELP4_DU_MAX_SECONDS`.
- Cache writes are atomic.
- WHM, cPanel, cron, and WHMCS-triggered scanner runs can share one non-blocking lock file.
- The installer creates a root-owned lock directory and a writable lock file so users can lock but cannot create or delete lock-directory entries.
- cPanel user refreshes default to three per hour, with a five-minute minimum interval and a 60-second scan runtime cap.
- WHM root can edit cPanel refresh limits, cPanel scan caps, WHM scan caps, and package-specific overrides in the WHM UI.
- UI performs output escaping for rendered values.
- WHMCS one-click deploy/check/sync requires PHP `ssh2`; otherwise admins use the manual deployment command.
- WHMCS does not perform file deletion or cleanup actions.

## Known Review Items

- Confirm AppConfig execution context on target cPanel versions.
- Confirm cPanel `*.live.pl` authenticated environment variables across target versions.
- Decide whether the default six-hour cron cadence should be configurable during install.
- Consider a future UAPI module if cPanel review prefers API separation over a `live.pl` page.
- Review WHMCS SSH credential handling on a staging WHMCS instance before enabling one-click deployment broadly.
- Confirm customer report copy with support/marketing before exposing to all clients.
