# Help4 Disk Usage Marketing Brief

## One-Line Positioning

Help4 Disk Usage gives hosting teams fast, support-ready disk and inode reports for WHM, cPanel, and WHMCS.

## Short Description

Help4 Disk Usage replaces slow, stale disk-usage guesswork with fresh scan timestamps, account attribution, cleanup categories, and customer-safe remediation hints. It helps hosts identify backup, cache, log, mail, temp, upload, dependency, disk, and inode offenders from WHM, cPanel, and WHMCS.

Public walkthrough:

https://fixitphill.com/whm-cpanel/help4-disk-usage-cpanel-whm-whmcs-disk-inode-reports/

## Who It Helps

- Shared hosting providers.
- Managed WordPress hosts.
- WHMCS-based hosting companies.
- cPanel server operators.
- Agencies managing many hosting accounts.

## Primary Benefits

- Faster support triage.
- Clear customer conversations around quota and inode issues.
- Self-service cPanel visibility for account users.
- WHMCS reports that map scan results to customers and services.
- Less reliance on stale/default disk usage screens.
- Safer cleanup because it reports and hints instead of deleting files.
- Refresh buttons are guarded by shared scan locking and cPanel user rate limits.

## Feature Bullets

- WHM root and reseller dashboards.
- cPanel customer account dashboard.
- WHMCS addon module for deployment and reporting.
- WHMCS Server Health tab for support/admin visibility across cPanel servers.
- Background scans with visible timestamps.
- Largest-file and inode-heavy directory detection.
- Cache/log/temp/backup/mail/upload/dependency hotspot detection.
- Stale large file detection.
- Growth hints when prior scan cache exists.
- Customer-safe remediation hints.
- One-scan-at-a-time lock for foreground/cache-writing scans.
- WHM-editable cPanel refresh limits with package-specific overrides.
- Permissive MIT licensing with visible Help4 credit.

## Customer-Facing Copy

Your hosting account can grow for reasons that are hard to see: backups, logs, cache files, mailboxes, temporary files, old uploads, or inode-heavy application folders. Help4 Disk Usage shows the most likely causes with clear timestamps and practical next steps.

## Support-Team Copy

Stop guessing from quota totals. Help4 Disk Usage shows what changed, where the weight is, whether the issue is disk or inodes, and what category of cleanup to discuss with the customer.

## Operations Copy

Help4 Disk Usage is built for busy shared-hosting servers. GUI-triggered scans use a shared lock so scan jobs do not stack, cPanel account users are rate-limited by default, and root can tune refresh limits or override them by hosting package.

## Screenshot Checklist

- WHM root dashboard showing visible accounts and offenders.
- cPanel account dashboard showing relative-path cleanup hints.
- WHMCS server deployment page.
- WHMCS Server Health admin page.
- WHMCS customer report table.
- WHMCS client-area report page.

## Launch Notes

Genie is the first live validation target. gohoster and dolce01 should remain future rollout targets until WHMCS integration has been reviewed on a WHMCS staging/live admin environment.
