# WHMCS Integration

Both WHMCS adapters are maintained in the standalone [Help4Network/help4-disk-usage-whmcs](https://github.com/Help4Network/help4-disk-usage-whmcs) repository. This native cPanel/WHM repository no longer contains addon runtime sources, addon-only tests or a WHMCS ZIP builder.

Use the canonical [installation guide](https://github.com/Help4Network/help4-disk-usage-whmcs/blob/main/docs/install.md), [upgrade guide](https://github.com/Help4Network/help4-disk-usage-whmcs/blob/main/docs/upgrade.md) and [cPanel integration guide](https://github.com/Help4Network/help4-disk-usage-whmcs/blob/main/docs/cpanel.md). They own current requirements, archive layout, checksums, role configuration, bounded syncs and removal. The new ZIPs contain paths below `modules/addons/`; do not apply a historical command that extracts the whole ZIP inside that directory. Stage privately and copy only the intended addon directory as documented in the canonical guide.

## Existing Installations

- Keep addon ID `help4_disk_usage`, path `modules/addons/help4_disk_usage` and client route `index.php?m=help4_disk_usage` unchanged.
- Preserve settings, administrator role access, report history and the existing `mod_help4_disk_usage_servers`, `mod_help4_disk_usage_accounts` and `mod_help4_disk_usage_events` tables. Do not rename or drop them when changing package source.
- Upgrade the existing addon in place. Do not deactivate/reactivate it, create a second identity or reinstall the native plugin merely for this extraction. Native runtime versions, installers and `update.json` remain unchanged.
- A Git pull updates source only, not installed WHMCS or panel files. Select a reviewed immutable addon distribution and verify its checksums before an authorized deployment. Source publication does not establish a stable release or installed acceptance.
- Retain the previous immutable addon ZIP/checksum as the rollback source; no routine filesystem snapshot is needed for this source split.

## Native Dependencies And Boundaries

The native cPanel/WHM plugin remains required on each managed cPanel server. The addon runs on the WHMCS host and uses separately verified per-server SSH pins for its bounded Check, Deploy, Update and Sync operations. Keep Allow Unpinned SSH off. Native package/manifest URLs must continue to reference this native project's release tarballs and `update.json`, never a WHMCS ZIP or Plesk package.

Plesk uses its own native extension and the standalone repository's separately named `help4_disk_usage_plesk` adapter. WHMCS provisioning support alone does not install the extension or approve subscription mappings. Never deploy this cPanel installer to Plesk Windows Server.

Customer reports retain current service ownership checks. Native File Manager jumps occur only after authentication in cPanel; WHMCS stores no reusable customer session URL. No invoices, payments, domains, tickets or hosting-service lifecycle states are changed by this extraction.

## Validation Ownership

Run `perl tests/native_separation.pl` here to check native source/build/workflow separation. Addon entitlement, SSH, Plesk bridge-contract, coexistence and package regressions belong to the standalone repository. Its [validation guide](https://github.com/Help4Network/help4-disk-usage-whmcs/blob/main/docs/validation.md) distinguishes source fixtures from native WHMCS framework/MySQL/TLS/role tests and native cPanel/Plesk acceptance. CI success is not installed-platform certification or approval to promote a stable channel.

Help4 software and addons remain free without keys, activation services or per-server fees. Retain the included permission notice and small linked Help4 Network byline; third-party platform requirements remain separate.
