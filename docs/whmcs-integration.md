# WHMCS Integration

Help4 Disk Usage includes a standalone WHMCS addon for deployment, server health, support reporting, and customer-facing disk and inode summaries.

## Availability

Download the latest standalone package from the project [GitHub Releases](https://github.com/Help4Network/help4-disk-usage/releases/latest):

```text
help4-disk-usage-whmcs-<version>.zip
help4-disk-usage-whmcs-<version>.zip.sha256
```

The complete source release also contains the addon at:

```text
integrations/whmcs/modules/addons/help4_disk_usage
```

The standalone zip extracts as one WHMCS addon directory:

```text
help4_disk_usage/
  help4_disk_usage.php
  hooks.php
  templates/clientarea.tpl
  README.md
  LICENSE
  VERSION
```

Install this package on the server that runs WHMCS. The cPanel/WHM component is installed separately on each managed cPanel server, either manually or with the addon's **Deploy** action.

## Requirements

- WHMCS with addon module support.
- Filesystem access to the WHMCS installation.
- A PHP version supported by the installed WHMCS release.
- WHMCS cPanel server records for the servers that will be managed.
- PHP `ssh2`, WHMCS-bundled phpseclib 2, or WHMCS-bundled phpseclib 3 for remote Check, Deploy, Update, and Sync actions.
- SSH network access from WHMCS to each enabled cPanel server.
- A decryptable SSH password in each participating WHMCS server record.
- An independently verified SSH host-key fingerprint for each participating server.

Manual cPanel installation remains available when the WHMCS PHP runtime has no supported SSH transport.

## Verify the Download

Run this from the directory containing the zip and checksum file:

```bash
sha256sum -c help4-disk-usage-whmcs-<version>.zip.sha256
```

On systems without `sha256sum`:

```bash
expected="$(awk '{print $1}' help4-disk-usage-whmcs-<version>.zip.sha256)"
actual="$(shasum -a 256 help4-disk-usage-whmcs-<version>.zip | awk '{print $1}')"
test "$actual" = "$expected"
```

## Install

Set `WHMCS_ROOT` to the real WHMCS document root. The directory should contain `init.php`, `configuration.php`, and `modules/`.

```bash
export WHMCS_ROOT=/path/to/whmcs
export BACKUP_DIR=/var/backups/help4-disk-usage
test -f "$WHMCS_ROOT/init.php"
test -d "$WHMCS_ROOT/modules/addons"
install -d -m 0700 "$BACKUP_DIR"
```

Back up an existing copy before replacing it:

```bash
if [ -d "$WHMCS_ROOT/modules/addons/help4_disk_usage" ]; then
  backup="$BACKUP_DIR/whmcs-addon-$(date -u +%Y%m%dT%H%M%SZ).tar.gz"
  tar -czf "$backup" -C "$WHMCS_ROOT/modules/addons" help4_disk_usage
  chmod 0600 "$backup"
fi
```

Extract the standalone package:

```bash
unzip -q help4-disk-usage-whmcs-<version>.zip -d "$WHMCS_ROOT/modules/addons"
```

Match the addon ownership to the WHMCS addon directory and apply normal PHP file permissions:

```bash
chown -R --reference="$WHMCS_ROOT/modules/addons" \
  "$WHMCS_ROOT/modules/addons/help4_disk_usage"
find "$WHMCS_ROOT/modules/addons/help4_disk_usage" -type d -exec chmod 0755 {} +
find "$WHMCS_ROOT/modules/addons/help4_disk_usage" -type f -exec chmod 0644 {} +
```

Validate the PHP entry points with the same PHP CLI used by WHMCS:

```bash
php -l "$WHMCS_ROOT/modules/addons/help4_disk_usage/help4_disk_usage.php"
php -l "$WHMCS_ROOT/modules/addons/help4_disk_usage/hooks.php"
```

Do not continue to activation if either syntax check fails.

## Activate and Configure

1. Sign in to WHMCS as a full administrator.
2. Open **System Settings > Addon Modules**.
3. Find **Help4 Disk Usage** and select **Activate**.
4. Configure administrator role access.
5. Save the addon settings.
6. Open **Addons > Help4 Disk Usage**.

Activation creates these tables:

```text
mod_help4_disk_usage_servers
mod_help4_disk_usage_accounts
mod_help4_disk_usage_events
```

Recommended initial settings:

| Setting | Initial value | Notes |
| --- | --- | --- |
| Release Tarball URL | Published immutable release URL | Fallback package URL. |
| Update Manifest URL | `https://raw.githubusercontent.com/Help4Network/help4-disk-usage/main/update.json` | Must publish `version`, `package_url`, and `sha256`. |
| Default SSH Port | `22` | This is intentionally separate from the WHM/API port in a cPanel server record. |
| SSH Host Fingerprints | One verified pin per enabled server | Required for remote actions. |
| Allow Unpinned SSH | Off | Leave off in production. |
| Sync Account Limit | `2` | Small first batch to verify load and mapping. |
| Whole Sync Scan Max Seconds | `15` | Small first-run budget; raise deliberately after observation. |
| Client Area Reports | On or off by policy | When on, clients see only currently mapped services. |
| Display Name | `Disk Usage Audit` | Operator-overridable title. |
| Footer Credit Prefix | `Built by` | Prefix before the Help4 Network byline. |

After the first bounded syncs succeed, increase the account and runtime limits to match server size. A value of `0` for **Sync Account Limit** means all accounts, still constrained by the whole-run time budget and shared scan lock.

## Prepare WHMCS Server Records

For every enabled cPanel server that the addon will manage:

1. Confirm the WHMCS server type is cPanel/WHM-like.
2. Confirm the hostname or IP reaches the intended server.
3. Store an SSH-capable root or administrative username and password in the WHMCS server record.
4. Confirm WHMCS can reach the addon's **Default SSH Port**.
5. Verify the SSH host fingerprint independently before adding it to the addon.

The addon does not use the server record's cPanel API port for SSH because that field commonly contains `2087`.

From the target server console, obtain fingerprints with:

```bash
for key in /etc/ssh/ssh_host_*_key.pub; do
  ssh-keygen -lf "$key" -E sha256
done
```

Enter the verified negotiated fingerprint as JSON keyed by WHMCS server ID, hostname, or IP:

```json
{
  "6": "SHA256:verified-fingerprint-from-server-console",
  "cpanel-a.example.net": "SHA256:another-verified-fingerprint"
}
```

When a pin is missing, the first remote action stops before password authentication and reports the negotiated fingerprint. Compare that value to the target server console before saving it. Never enable **Allow Unpinned SSH** merely to bypass a mismatch.

## First Run

Open **Addons > Help4 Disk Usage > Servers & Deploy**.

For a server where the cPanel plugin is already installed:

1. Select **Check** and confirm the installed version is current.
2. Select **Sync** with the initial small limits.
3. Repeat **Sync** while the health state is partial and accounts remain.

For a server where the cPanel plugin is not installed:

1. Select **Check** to confirm it is missing.
2. Select **Deploy**.
3. Confirm the deployment package passed manifest SHA-256 verification.
4. Select **Check** again.
5. Select **Sync** with the initial small limits.

Remote actions are serialized by the cPanel plugin's shared non-blocking scan lock. The whole-run time budget and optional account limit prevent one WHMCS action from scanning indefinitely.

## Server Health Dashboard

The WHMCS admin home dashboard includes a **Help4 Disk Usage Health** widget for administrators with the **Perform Server Operations** permission.

Open **Addons > Help4 Disk Usage > Server Health** for:

- Plugin deployment and version state.
- Last-seen and last-scan timestamps.
- Bounded scan coverage and partial-sync state.
- Bad/check account counts.
- Stale or failed servers.
- Next-step guidance and Check, Deploy, Update, or Sync actions.

A partial state means the bounded scan has accounts remaining. Run Sync again; it is not an SSH or installation failure.

## Customer Reports

WHMCS maps scan records to hosting services with:

```text
tblhosting.server = tblservers.id
tblhosting.username = cPanel username from scan JSON
```

Mapped reports are available to authenticated customers at:

```text
index.php?m=help4_disk_usage
```

The client navigation link is added below **Services** when **Client Area Reports** is enabled. Every rendered row is rechecked against the logged-in client's current service ID, server ID, and cPanel username. Unmapped cPanel accounts remain admin-only.

## Upgrade

Do not deactivate the addon for a normal upgrade. WHMCS detects a new addon version from the module configuration and calls the addon upgrade function the first time the updated module is accessed.

1. Verify the new zip checksum.
2. Back up the current module directory.
3. Extract the new zip over `modules/addons/`.
4. Restore the expected WHMCS ownership and permissions.
5. Open **System Settings > Addon Modules**, save the Help4 Disk Usage settings, and then open the addon.
6. Confirm the displayed module version, Server Health page, and client scope.

Example:

```bash
export WHMCS_ROOT=/path/to/whmcs
export BACKUP_DIR=/var/backups/help4-disk-usage
install -d -m 0700 "$BACKUP_DIR"
backup="$BACKUP_DIR/whmcs-addon-$(date -u +%Y%m%dT%H%M%SZ).tar.gz"
tar -czf "$backup" -C "$WHMCS_ROOT/modules/addons" help4_disk_usage
chmod 0600 "$backup"
unzip -qo help4-disk-usage-whmcs-<version>.zip -d "$WHMCS_ROOT/modules/addons"
chown -R --reference="$WHMCS_ROOT/modules/addons" \
  "$WHMCS_ROOT/modules/addons/help4_disk_usage"
```

If a release adds `hooks.php` to an older installation, re-save the addon settings so WHMCS rediscovers the module hook file.

## Remove the Addon

1. Back up the WHMCS database and `modules/addons/help4_disk_usage`.
2. Open **System Settings > Addon Modules**.
3. Deactivate **Help4 Disk Usage**.
4. Remove or archive `modules/addons/help4_disk_usage`.

Deactivation intentionally retains the three `mod_help4_disk_usage_*` tables so support history is not silently destroyed. Remove those tables only through a separately reviewed database change after confirming no history is required.

Removing the WHMCS addon does not uninstall the cPanel/WHM plugin from managed servers. Run the cPanel package's `uninstall.sh` separately on each server if that is also intended.

## Troubleshooting

**The addon is not listed:** Confirm the exact path is `modules/addons/help4_disk_usage/help4_disk_usage.php`, validate PHP syntax, and verify WHMCS can read the files.

**The health widget is missing:** Confirm the addon is active, the administrator has **Perform Server Operations**, and re-save the addon settings so WHMCS reloads `hooks.php`.

**Remote actions say no SSH transport is available:** Confirm the WHMCS PHP runtime has `ssh2` or can load its bundled phpseclib classes. Browser PHP and CLI PHP may use different configurations.

**Authentication fails:** Verify the WHMCS server record has a current decryptable SSH credential. Do not place credentials in the fingerprint JSON or module files.

**Fingerprint validation fails:** Recheck the key on the target server console. Treat an unexpected key change as a security event until independently explained.

**Health remains partial:** Run another bounded Sync. The scanner rotates oldest cache entries first and records remaining account coverage.

**Clients see no rows:** Confirm Client Area Reports is enabled and that the current WHMCS hosting service has the same server ID and cPanel username as the synced scan record.

## Build the Standalone Package

From the repository root:

```bash
./scripts/package-whmcs.sh
./tests/whmcs_package.sh
```

Release tag pushes automatically publish the standalone zip, its SHA-256 file, the complete cPanel/WHM package, and package checksums to GitHub Releases.

## Safety Boundaries

- WHMCS stores summarized scan findings and remediation hints; it does not delete customer files.
- Disabled or non-cPanel WHMCS server records are rejected before SSH actions.
- Host-key verification occurs before password authentication.
- Remote commands use bounded deadlines, verified exit markers, and a 16 MiB output cap.
- Deployment packages must match the HTTPS update manifest's SHA-256 digest.
- Client reports are limited to current service mappings for the authenticated client.
- The health widget requires **Perform Server Operations** permission.
- Deactivation retains reporting history by default.

## WHMCS References

- [Addon Modules](https://developers.whmcs.com/addon-modules/)
- [Configuration](https://developers.whmcs.com/addon-modules/configuration/)
- [Installation and Uninstallation](https://developers.whmcs.com/addon-modules/installation-uninstallation/)
- [Upgrades](https://developers.whmcs.com/addon-modules/upgrades/)
- [Module Hooks](https://developers.whmcs.com/hooks/module-hooks/)
