# Changelog

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

