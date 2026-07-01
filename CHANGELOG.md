# Changelog

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
