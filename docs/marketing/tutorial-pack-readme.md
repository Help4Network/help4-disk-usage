# Help4 Disk Usage Tutorial Pack

This package is for public tutorials, product pages, release announcements, and support documentation.

## Privacy

Every screenshot is generated from dummy fixtures. The package contains no live customer usernames, domains, server hostnames, absolute customer paths, or unredacted production captures.

Do not replace these images with files from engineering evidence directories.

## Included

- Eight dummy-data screenshots covering WHM, cPanel, and WHMCS, including cPanel mobile and incomplete coverage.
- The full project README and deployment instructions.
- The 1.0.1 file workflow guide: native File Manager locations, search/sort/paging, clear filters, copy/export, account drill-downs, safe refresh navigation, and current-service navigation.
- WHMCS installation and operating guidance.
- Security notes, rollout guidance, and a marketing brief.
- The project changelog and license.

## Publishing Notes

- Link downloads to the immutable GitHub release. Verify the cPanel package against `update.json` and the standalone WHMCS zip against its adjacent `.sha256` file.
- Explain that the plugin reports cleanup candidates and does not delete customer files.
- Explain that foreground scans share one lock and cPanel refreshes are rate-limited.
- Explain incomplete reports as lower bounds, separate direct-file ranks from overlapping recursive tree ranks, and describe rate limits as cooperative UI controls rather than hostile-tenant resource quotas.
- File rows open the containing native File Manager directory, not an automatic edit/delete dialog. WHMCS service links are not direct file-jump or reusable SSO links.
- Keep the native WHM and Jupiter navigation visible. The plugin uses their supported page wrappers; it does not require a new cross-origin iframe or a replacement control-panel screen.
- Keep the small linked Help4 Network builder credit visible in screenshots, tutorials, and derived reports.

Project: https://github.com/Help4Network/help4-disk-usage

Builder credit: https://help4network.com/

The cPanel report body is rendered from the release's real controller with synthetic metadata and a test LiveAPI wrapper; its surrounding shell is illustrative. Other screenshots use synthetic illustrative layouts. None are proof of production health or cPanel certification.
