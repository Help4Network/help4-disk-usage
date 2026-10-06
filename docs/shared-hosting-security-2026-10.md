# October 2026 Shared-Hosting Review

## Scope

A Codex Security repository scan reviewed all 45 tracked files of v0.3.7 (commit `142532a22049a84315a30f198b77e58cb426a4d1`), using independent repository, architecture, and focused filesystem passes. The reviewed surfaces included the scanner, WHM/cPanel entry points, WHMCS client/admin integration, installer, updater, packaging, tests, and documentation. Findings were validated and deduplicated before the report was finalized. Live checks were read-only; no production exploitation or stress testing was performed.

This is an automated, source-backed assessment, not independent certification. The original report covers v0.3.7. Version 0.3.8 remediation is supported by targeted regression tests and deployment checks, not by pretending the original audit reviewed later code.

## Findings And Changes

| v0.3.7 finding | Calibrated severity | v0.3.8 control | Regression |
| --- | --- | --- | --- |
| Replaced directory pathname can escape a privileged traversal and disclose private metadata through a reseller report | Low | Hold parent descriptors; open each child with no-follow and inode/device comparison | Deterministic check/open and ancestor-replacement tests |
| Tenant-writable root-owned scan lock permits storage allocation outside ordinary per-UID quota | Medium | Root mode 0644; all scanner lock opens read-only | Lock mode and deployed write-denial checks |
| Lock handle closes before traversal, allowing overlapping privileged scans | Medium | Retain the handle through cache publication | Held traversal plus rejected concurrent scanner |
| Retained file/path data grows with account contents before output truncation | Medium | Streaming readdir, bounded top-N candidates, entry/directory/depth/path budgets | Top-N, entry, directory, depth, and path-budget tests |
| Reused server/username selects a retained historical WHMCS service | Low | Unique current eligible service; revalidate client entitlement and registration date | Historical, ambiguous, suspended, cancelled, unrelated, and anonymous cases |

The metadata race requires account-controlled directory changes and an observation route; it is not file-content theft or code execution. The WHMCS finding is a lifecycle binding problem involving retained service records, not a generic unauthenticated client-area bypass.

## Reporting And Operational Improvements

- Partial/erroring scans explicitly report incomplete coverage and lower-bound totals.
- Growth requires two complete snapshots; partial scans cannot manufacture a growth baseline.
- cPanel now shows largest directories by directly contained file bytes, without calling these recursive subtree totals.
- Installed WHM, cPanel, cron, WHMCS, and default global-cache CLI scans share one fixed lock inode.
- Current update settings take precedence over old install metadata and the manifest URL survives an update.
- Cron stops emitting full reports into logs; its diagnostic log is root-only and rotated.
- Native WHM navigation, Jupiter LiveAPI lifecycle, and the cPanel POST-Redirect-GET refresh behavior remain unchanged.

## Reproduction

Run the normal smoke suite plus:

```bash
perl tests/scanner_hardening.pl
php tests/whmcs_tenant_isolation.php
bash tests/updater_channel.sh
```

Filesystem tests use temporary synthetic trees and subprocess-only scheduling hooks. WHMCS lifecycle tests use a query stub, not a claim to have proven the host application's SQL/authorization stack. Update tests use isolated paths and network stubs, never root installation on the developer machine. The CI and tag-release workflows run these tests.

## Remaining Work And Trust Assumptions

- cPanel's account-local rate file is a cooperative UX limiter. A hostile same-UID process can modify it or start its own scan. Use LVE/cgroups or a future privileged job broker for hard tenant resource limits.
- A tenant can hold the readable advisory lock and delay this plugin's collection. Mode 0644 removes the storage sink, not advisory-lock denial of service.
- WHMCS core dispatcher, admin role, and CSRF behavior are external dependencies and must be verified on the deployed WHMCS version.
- The online update manifest is the release trust root; SHA-256 detects archive mismatch, not malicious authorized publishing. Independent signatures are future work.
- Totals are logical file bytes and observed entry counts. They exclude external database/system storage, prune documented trees, are not hard-link deduplicated, and are not consistent snapshots.
- Traversal has an alarm plus work caps; bounded postprocessing follows. Blocked kernel I/O is not a strict real-time guarantee.
- No comparative benchmark supports a claim of being the fastest or best product in the market.

Keep operational evidence and real screenshots private. Public tutorial screenshots must use dummy accounts and domains.

## Deployed Validation On 2026-10-06

Version 0.3.9 retains the five 0.3.8 remediations and adds completed-install version checks after a stopped installer exposed a recovery gap. A synthetic updater test proves same-release repair without `--force` and rejects inconsistent post-install readback. The original failed production install log was not retained; the cause of that first stop is not attributed. Verified reapplication and subsequent complete installation checks passed.

- All three existing rollout nodes passed immutable-archive checks, v0.3.9 runtime/completed-install readback, tenant lock-write denial, global-cache read denial, Linux race/resource-cap tests, and private log-rotation checks.
- cPanel remained at 11.138.0.12 and boot IDs did not change; no automatic filesystem snapshots were created.
- Authenticated Genie browser checks passed for the native WHM root shell and Jupiter account view. One refresh POST returned a partial report; two reloads submitted no new scans and preserved its timestamp. Desktop and 390-pixel mobile checks found no relevant console errors or page-level overflow. The native cPanel 138 controls use shadow DOM, which the test explicitly inspects.
- Live reseller render/ownership filtering passed on the node with reseller ownership present. No reseller ownership was present on the other two nodes, so those are not claimed as positive reseller-browser tests.
- The WHMCS addon upgraded to 0.3.9. Five admin views and its health widget rendered in the deployed PHP runtime; current entitlement checks exercised the real database for seven clients and nine visible reports, with zero anonymous rows.
- Host-pinned Check/Sync succeeded for all three allowed server records. Sync used two-account, 15-second smoke batches; saved health rows correctly report partial coverage and no errors, not complete fleet health.
- Local validation and the GitHub main/tag workflows passed. Public tutorial material contains eight synthetic screenshots; it is not raw production evidence.

These are dated scoped observations, not a promise that every account or external WHMCS role/CSRF configuration has been exhaustively tested.
