# Usage Guide

This project has a public walkthrough on Fix I.T. Phill:

https://fixitphill.com/whm-cpanel/help4-disk-usage-cpanel-whm-whmcs-disk-inode-reports/

Use that article when you need a plain-language explanation for hosting teams, support teams, and customers. Use this repository README for the latest install commands, release package version, and security notes.

## What the Article Covers

- What Help4 Disk Usage is for.
- Who it helps: shared hosts, managed WordPress hosts, WHMCS-based hosting companies, agencies, and cPanel server operators.
- Why it is different from a raw shell script.
- How WHM root and reseller views support account triage.
- How cPanel users get a customer-safe account view.
- How WHMCS fits into deployment, sync, admin reporting, and customer summaries.
- Why screenshots use generated dummy data.
- Why the tool reports cleanup candidates instead of deleting files.

## Recommended Support Workflow

1. Deploy the WHM/cPanel plugin on a cPanel server.
2. Let the scheduled scan run, or refresh a bounded scan manually.
3. Review WHM for bad/check accounts by disk and inode pressure.
4. Look at the top issue category before opening a customer ticket.
5. Sync to WHMCS when support staff need service/customer mapping.
6. Use the WHMCS Server Health tab to watch stale scans, scan errors, bad/check counts, and server coverage.
7. Send customers to the WHMCS client report or cPanel account page when self-service reporting is appropriate.
8. Use remediation hints as discussion points, not as automatic cleanup instructions.

## Safety Notes for Tutorial Writers

- Do not publish screenshots from live server evidence folders.
- Use the generated tutorial screenshots from `outputs/help4-disk-usage-tutorial-pack.zip`.
- Keep the visible footer credit: `Help4 Disk Usage by Help4 Network`.
- Mention that cleanup is not automated.
- Mention that foreground scans use a shared lock.
- Mention that cPanel user refreshes are rate-limited.
- Mention that root can tune scan limits and package-specific overrides in WHM.
- Mention that WHMCS Server Health is the admin/support view for server coverage, scan freshness, and failures.
- Mention that WHMCS client rows are scoped to the logged-in client's current mapped hosting services.

## Version Note

The external article may reference the version that was current when it was written. The current repository release and README are authoritative for install commands and package names.
