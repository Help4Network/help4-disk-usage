# Changelog

## 1.0.2 Candidate

- Add `install.sh --check` and prerequisite validation before installation writes: OS/panel pairing, architecture, Jupiter, native registration commands, bundled Perl modules, cron/logrotate and required utilities.
- Parse OS metadata as data rather than sourcing it. Flag existing legacy installations separately from the vendor's current supported matrix.
- Add AlmaLinux 8/9/10 and Ubuntu 24.04 collector CI. CloudLinux classifications are tested, but AlmaLinux containers do not certify CloudLinux/CageFS behavior.
- The published update manifest remains on 1.0.1 until native installation/role/GUI validation promotes this candidate.

## 1.0.1

- Redirect WHM POST actions to a clean relative GET, preserving account drill-down and account-list search/sort without replaying scans, settings changes or updates on reload.
- Keep generic unavailable-account reports inside WHM's native navigation without disclosing unowned account data.
- Load shared interaction code through the WHM master template on both account lists and detail pages; keep Jupiter's LiveAPI lifecycle unchanged.
- Prevent duplicate action submissions, announce busy state and restore controls after browser Back/Forward cache navigation.
- Add an accessible clear-path-search control and make report section links land on headings and controls instead of the table body.
- Extend native-shell, refresh, scope and desktop/mobile interaction regressions. Preserve existing scan limits, lock, cache boundaries and root-only updater policy.
- Exclude reserved system identities and filesystem-root homes from cPanel account discovery and hide legacy system-home cache entries in WHM's account dashboard.

## 1.0.0

- Add account-safe cPanel File Manager jumps from large/stale files and directory rankings. Files open their containing directory; directories open themselves in a new tab, preserving the report and native session. Missing, invalid, or cross-home symlink locations fail closed.
- Add search, numeric/date/path sorting, paging, relative-path copying, filtered CSV exports, and account-scoped CSV/JSON downloads. Spreadsheet formula prefixes are neutralized and exports retain the Help4 Network credit.
- Add WHM account filtering and scoped account drill-downs with the same report tools. Reseller authorization is applied before detail/export selection.
- Add recursive directory-tree byte and entry rankings in addition to direct-file directory rankings. Retention remains bounded; unfinished trees are not promoted as complete observations.
- Display coverage, scan age, duration, errors, complete-scan growth, and report thresholds. Keep cPanel POST-Redirect-GET and disable repeat refresh submissions while a request is running.
- Add WHMCS admin account details and client large-file/directory-tree/hotspot reports, plus current-service navigation. Add an idempotent nullable report-storage column without dropping historical data.
- Preserve the 0.3.8 shared-hosting controls and 0.3.9 updater recovery checks; no cleanup endpoint, unrestricted path selector, embedded account credentials, or automatic filesystem backups are introduced.

## 0.3.9

- Detects scanner/completed-install version mismatches so a stopped installation is not reported as current merely because the new scanner was copied first.
- Allows reapplying the same verified release to repair such an installation without requiring `--force`.
- Verifies runtime and completed-install version readback after a successful installer exit.
- Added isolated updater tests for partial-install detection and repair.

## 0.3.8

- Replaced pathname-based recursive traversal with parent-held directory descriptors, no-follow opens, and inode/device checks to prevent directory replacement from escaping account scope.
- Changed the root-owned shared lock to mode 0644 and read-only opens, and retained it through scanning and cache publication.
- Standardized installed entry points on one fixed lock directory, including direct scanner invocations with the default global cache.
- Added bounded entry, directory, depth, retained-path, and streaming top-N budgets to prevent scan-memory growth proportional to all matching files.
- Marked safety-limited or erroring scans incomplete, suppressed growth based on partial snapshots, and added direct-file directory size rankings and coverage notices to cPanel.
- Restricted WHMCS service binding and client rendering to exactly one current Active/Suspended service; rejected reports predating service registration and ambiguous username reuse.
- Preserved configured update-channel precedence and propagated the manifest URL during installation.
- Suppressed full cron JSON logs, restricted the diagnostic log to root, and added rotation.
- Added deterministic filesystem-race, lock-lifetime, resource-cap, update-channel/checksum, and WHMCS lifecycle isolation regression tests.
- Documented the completed v0.3.7 source audit, patched controls, reporting limitations, and remaining shared-hosting trust assumptions.

## 0.3.7

- Changed the cPanel account refresh action to POST-Redirect-GET so browser reload and back navigation cannot resubmit a scan.
- Added explicit clean form targets and no-store response headers to prevent stale POST responses and nonce pages from being reused.
- Made refresh limiting fail closed when rate state cannot be persisted.
- Added regression coverage proving one POST runs one scan and subsequent cPanel reloads are read-only.

## 0.3.6

- Moved the cPanel entry from the Metrics group into the Files group.
- Replaced the generic disk glyph with the official Help4 Network H4 mark on cPanel and WHM plugin surfaces.
- Rebuilds the Jupiter application-icon sprite during installation so branding changes appear immediately after upgrades.
- Recorded the official logo source and checksum, and added packaging tests for the Files placement and branded assets.
- Updated the generated cPanel tutorial fixture to show the plugin in Files with the production icon.

## 0.3.5

- Embedded the cPanel account dashboard in the supported LiveAPI header/footer lifecycle so Jupiter navigation remains available.
- Moved cPanel page execution to cPanel's bundled Perl runtime, which provides `Cpanel::LiveAPI`.
- Reused the fully scoped plugin stylesheet in cPanel to prevent global styles from changing the surrounding Jupiter interface.
- Added cPanel-shell regression coverage for navigation, duplicate documents, LiveAPI lifecycle calls, request security, and refresh throttling.
- Replaced the standalone cPanel tutorial mock with a privacy-safe dummy Jupiter interface.

## 0.3.4

- Embedded the WHM dashboard in cPanel's native master template so the normal WHM navigation remains available.
- Moved production CGI execution to cPanel's bundled Perl runtime and installed a dedicated Template Toolkit interface file.
- Added WHM-shell regression coverage that rejects nested standalone documents and unscoped CSS selectors.
- Added installation and removal handling for the WHM template directory.
- Made deployment filesystem snapshots opt-in; immutable Git tags are the default rollback source.

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
