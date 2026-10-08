# Help4 Disk Usage Marketing Brief

## 1.0.1 File Workflows

Customers can click an offender path or File Manager action to open its native cPanel location in a separate tab, then use native download, preview, move, permissions and trash controls. The plugin itself never deletes files or reads their contents. Search/sort/paging/copy/export operate on bounded retained metadata, not a complete filesystem index. Recursive tree rankings are separate from direct-file rankings; overlapping trees cannot be summed. WHM has scoped account drill-downs; WHMCS has detailed reports and current-service links, not embedded SSO credentials. Use `docs/file-workflows.md` for the tutorial sequence and safety notes. Do not describe partial coverage as complete or promise automatic cleanup.

Version 1.0.1 keeps the normal WHM navigation and Jupiter header/sidebar/footer. WHM account filters and sort survive drill-down and rescans; POST actions redirect to read-only pages, duplicate submissions are blocked, and browser Back/Forward restores controls. Report section links land on headings and controls, and each path filter has an accessible clear action. Do not suggest adding a replacement frame or suppressing the native navigation.

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
- WHMCS admin-home health widget.
- WHMCS Server Health tab for support/admin visibility across cPanel servers.
- Background scans with visible timestamps.
- Largest-file and inode-heavy directory detection.
- Cache/log/temp/backup/mail/upload/dependency hotspot detection.
- Stale large file detection.
- Growth hints between two complete scan caches.
- Customer-safe remediation hints.
- One-scan-at-a-time lock for foreground/cache-writing scans.
- WHM-editable cPanel refresh limits with package-specific overrides.
- Checksum-verified release updates from WHM and WHMCS; filesystem snapshots are opt-in.
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
- WHMCS admin-home health widget.
- WHMCS Server Health admin page.
- WHMCS customer report table.
- WHMCS client-area report page.

## Launch Notes

Genie is the canary target; dolce01 and gohoster02 are existing rollout targets. Publish version-specific deployment claims only from current verification evidence.

## Claims And Privacy

Use dummy accounts/domains for public screenshots, never live customer identifiers. The October review is an automated source audit plus regression coverage, not cPanel certification or independent penetration testing. Do not claim perfect security, hard tenant quotas, complete filesystem or quota totals, or market-leading speed. Recursive tree rankings are bounded observations, not full quota accounting. Safety-limited reports are lower-bound observations; growth requires two complete scans. See `docs/shared-hosting-security-2026-10.md` for details.
