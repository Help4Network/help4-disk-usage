# WHMCS Integration

Help4 Disk Usage includes a WHMCS addon module at:

```text
integrations/whmcs/modules/addons/help4_disk_usage
```

Copy that directory to:

```text
<whmcs-root>/modules/addons/help4_disk_usage
```

Then activate **Help4 Disk Usage** in **System Settings > Addon Modules**.

## What WHMCS Gets

- Admin dashboard for disk/inode scan state across cPanel servers.
- WHMCS admin-home widget with health counts and prioritized cPanel server rows.
- Server Health tab for WHMCS admins and support leads.
- Server deployment/check/sync controls.
- Manual deployment command for hosts without PHP `ssh2`.
- Customer report table mapped to WHMCS services.
- Client-area page at `index.php?m=help4_disk_usage`.
- Client navbar link when client reports are enabled.
- Event log for deployment and sync attempts.

## Server Health View

The WHMCS admin home dashboard includes a **Help4 Disk Usage Health** widget. It shows health counts, the highest-priority server rows, and a direct link to the full health page.

Open **Addons > Help4 Disk Usage > Server Health** to see the operational state of every WHMCS cPanel/WHM server record.

The view highlights:

- Healthy, attention, stale, error, not checked, and not synced counts.
- Last scan timestamp and age.
- Scanned account coverage.
- Bad/check account counts.
- Last deploy/check/sync error.
- Recommended next step per server.
- Check, Deploy, and Sync actions for eligible cPanel/WHM server records.

The health view is for WHMCS administrators. Customer-facing output remains scoped to the logged-in client's currently mapped services.

## One-Click Deploy Requirements

One-click deploy/check/sync uses SSH from WHMCS to the cPanel server.

Required:

- PHP `ssh2` extension in the WHMCS PHP runtime.
- WHMCS server record with host/IP, SSH user, SSH port, and decryptable password.
- Network path from WHMCS to the cPanel server over SSH.
- Root or sufficiently privileged account on the cPanel server.

If any of these are missing, use the manual deployment command shown by the addon.

## Data Mapping

WHMCS sync maps scan records to hosting services with:

```text
tblhosting.server = tblservers.id
tblhosting.username = cPanel username from scan JSON
```

If a cPanel account is not mapped to a WHMCS service, it still appears in admin reporting but is not shown to any client.

## Tables

The addon creates:

```text
mod_help4_disk_usage_servers
mod_help4_disk_usage_accounts
mod_help4_disk_usage_events
```

Deactivation retains the tables so support history is preserved.

## Support Workflow

1. Deploy the WHM/cPanel plugin to a server.
2. Run **Sync** in WHMCS.
3. Review **Customer Reports** for bad/check accounts.
4. Use support hints to explain whether the problem is backups, logs, temp files, mail, cache, uploads, dependencies, disk size, or inode growth.
5. Send customers to `index.php?m=help4_disk_usage` when self-service reporting is enabled.

## Safety

- WHMCS does not delete files.
- WHMCS does not show unmapped account data to clients.
- Deploy/check/sync actions are limited to cPanel/WHM-like WHMCS server records.
- Disabled WHMCS server records are rejected before SSH actions run.
- Client reports use summarized findings and remediation hints.
- Admins should review server credentials and SSH trust boundaries before enabling one-click deployment.
