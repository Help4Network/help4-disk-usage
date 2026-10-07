# File Workflows In 1.0.0

## Customer: cPanel

1. Open **Files > Help4 Disk Usage** in Jupiter.
2. Check the scan timestamp and coverage before making cleanup decisions. Refresh obeys the host's per-account/package policy and one shared scan lock. Reloading a completed result does not repeat the scan.
3. Inspect **Large files**, **Stale large files**, **Largest directory trees**, or **Directory trees with most entries**. Direct-file rankings remain separately labeled.
4. Search retained paths, select size/count/date/path sorting, and change the page size. Search is literal and does not run a new filesystem traversal.
5. Click **File Manager** beside a file to open its containing directory, or beside a directory to open that directory. A separate tab keeps the report available. It does not automatically select, edit, delete, move, or download the file.
6. Use cPanel's native controls for preview, download, archive, move, permissions, trash, and deletion. Review application ownership/retention and recovery requirements first. Refresh the report after a change; previous observations are not a live filesystem snapshot.
7. Use **Copy path**, **Export results** (all filtered retained rows, not just the visible page), or account **Download CSV/JSON** for support. Exports contain private account paths: treat them as customer data. Every exported report carries the Help4 Network byline.

File Manager availability still depends on the host's cPanel feature list and account permissions. The plugin does not bypass either. Broken, removed, traversal, control-character, absolute, or out-of-home symlink locations produce a location-unavailable notice. Names with spaces, `+`, `&`, `%`, and `#` are encoded as URL data, not query syntax. No session URLs or account credentials are saved in reports.

## Provider: WHM

Filter the account list by username/owner or sort by status, disk, inodes, or account. Click an account for its detailed report, retained-entry controls and downloads. A reseller's current ownership allowlist is applied before selecting detail or export data; inaccessible reports return a generic not-found response. Native WHM navigation remains present. WHM does not silently mint customer sessions or expose another account's File Manager URL.

## Support And Customers: WHMCS

In **Addons > Help4 Disk Usage > Customer Account Reports**, click an account to inspect its synced file/tree report. A current unambiguous mapping can link support to the native hosting-service record. The customer addon page expands each entitled service's detailed report and links to that customer's service page, where the native WHMCS cPanel login controls apply. Direct file jumps intentionally occur in the authenticated cPanel plugin, not through reusable SSO links stored in WHMCS.

Upgrade adds a nullable `report_json` column idempotently. Existing rows and customer associations are retained; legacy reports show unknown coverage until synced. No invoices, payments, domains, tickets, or hosting-service lifecycle states are modified. Upload both addon PHP files and templates from the same release, then open the addon so WHMCS runs its upgrade hook before syncing. The WHMCS distribution includes these instructions.

## Reading Rankings

- File bytes are logical regular-file sizes, not allocated blocks or quota accounting. Hard links are not deduplicated.
- Direct rankings count only regular files immediately inside a directory.
- Tree rankings include regular-file bytes recursively and indexed entries (directory itself, descendant directories, files, and non-followed links). Ancestor and descendant rows overlap; never add them together.
- Trees are retained only after their traversal returns. A partial scan may omit the interrupted branch and its ancestors. Visible trees do not prove the whole account was traversed.
- Rank lists are bounded top-N observations. Searching them is not a complete file search; File Manager is the native file browsing/editing surface.
- Stale means modification age, not safe-to-delete. Growth requires two complete scans. A limit-hit report is a lower bound, not a clean bill of health.

## Release Gates

The shared-hosting race/lock/cap regressions, current WHMCS entitlement tests, native shell/refresh tests, file navigation/encoding/export tests, and recursive-ranking fixtures must pass before a release. Browser checks cover search/sort/paging/copy/download, desktop/mobile overflow, console errors, and authenticated cPanel File Manager destination. Screenshots for public tutorials use synthetic customer information only. The original October security audit was for 0.3.7; these are remediation and feature-regression tests, not a new independent certification.

CI and tagged releases also run `tests/browser_workflows.js` against synthetic controller output with pinned Playwright 1.54.1; the dependency is test-only, not installed on cPanel or WHMCS servers. To run locally with an existing Playwright runtime, set `NODE_PATH` to its `node_modules` and optionally `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH` to the browser executable. Live native shell and File Manager navigation still require authenticated server QA; the synthetic browser test is not a substitute for that.
