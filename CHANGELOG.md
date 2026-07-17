# Changelog

## 0.3.3

- Moved WHMCS module backup examples outside the WHMCS document root with restrictive directory and archive permissions.
- Updated the public rollout status after Genie, gohoster02, and dolce01 validation.
- Rebuilt the standalone WHMCS package so its embedded installation guide contains the safer backup procedure.

## 0.3.2

- Added a standalone, checksummed WHMCS addon zip and package validation test.
- Added release automation that publishes both the cPanel/WHM and WHMCS packages on version tags.
- Expanded WHMCS installation, activation, host-key pinning, first-run, upgrade, removal, verification, and troubleshooting instructions.

## 0.3.1

- Added a host-pinned phpseclib 2/3 fallback for WHMCS installations whose PHP runtime does not provide the native `ssh2` extension.
- Kept fingerprint verification before password authentication across both SSH transports.
- Added unit coverage for SSH public-key parsing, fingerprint formats, remote exit markers, and pin-before-auth rejection.
- Added a reproducible dummy-data screenshot and tutorial-pack builder that rejects known live identifiers before packaging.

## 0.3.0

- Changed scanner runtime limits from per-account limits to a true whole-run budget.
- Added oldest-cache-first account rotation and explicit planned, remaining, batch-complete, and scope-complete report metadata.
- Changed WHM and cPanel scan/update/settings actions to POST requests protected by short-lived server-side nonces.
- Removed the WHM execution-context root fallback and now require cPanel's authenticated `REMOTE_USER`.
- Serialized cPanel rate-limit state updates to prevent concurrent refresh bypasses.
- Required HTTPS and SHA-256 package verification for updater apply and WHMCS bootstrap deployment flows.
- Added archive path/link validation and removed the predictable root-owned updater log in `/tmp`.
- Added fail-closed WHMCS SSH host-key pinning, remote exit-status verification, execution deadlines, and a 16 MiB output cap.
- Restricted the WHMCS health widget to administrators with `Perform Server Operations` permission.
- Added partial-sync health reporting and cumulative WHMCS account coverage.
- Added request-security and bounded-rotation regression tests.

## 0.2.9

- Reduced front-end branding with configurable display names and footer prefixes for WHM, cPanel, and WHMCS views.
- Enforced a small linked Help4 Network builder byline at the bottom of plugin pages and report surfaces.
- Added scanner report credit metadata for downstream report renderers.
- Added `update.json` manifest support and `--manifest-url` updater checks so installs can follow a release channel.
- Stored update manifest URLs in cPanel install metadata and WHMCS deploy/update commands.

## 0.2.8

- Fixed WHMCS SSH actions to use the addon SSH port setting instead of the WHMCS cPanel/WHM API port.
- Documented the WHMCS SSH port behavior for cPanel server records.

## 0.2.7

- Added backup-first update checks and apply flow from WHM and WHMCS.
- Added installed release metadata at `/var/cpanel/help4-disk-usage/install.json`.
- Added cPanel-side `help4-disk-usage-update` JSON updater.
- Added WHM Repository Updates panel.
- Added WHMCS Check/Update version reporting and update actions.
- Fixed WHM release URL validation warning.

## 0.2.6

- Added repository update detection plumbing for installed cPanel servers.
- Added WHMCS version summary and update-available health state.

## 0.2.5

- Added WHMCS admin-home health widget.

## 0.2.4

- Added WHMCS Server Health page.
- Added server health states for stale, error, attention, not checked, and not synced servers.

## 0.2.3

- Added scan limits, shared scan locking, and cPanel user refresh throttles.
- Added package-specific cPanel refresh override support.
- Tightened WHM/cPanel account-boundary checks.
