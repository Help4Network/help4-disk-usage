# Help4 Disk Usage Tutorial Pack

This package is for public tutorials, product pages, release announcements, and support documentation.

## Privacy

Every screenshot is generated from dummy fixtures. The package contains no live customer usernames, domains, server hostnames, absolute customer paths, or unredacted production captures.

Do not replace these images with files from engineering evidence directories.

## Included

- Eight dummy-data screenshots covering WHM, cPanel, and WHMCS, including cPanel mobile and incomplete coverage.
- The full project README and deployment instructions.
- WHMCS installation and operating guidance.
- Security notes, rollout guidance, and a marketing brief.
- The project changelog and license.

## Publishing Notes

- Link downloads to the immutable GitHub release. Verify the cPanel package against `update.json` and the standalone WHMCS zip against its adjacent `.sha256` file.
- Explain that the plugin reports cleanup candidates and does not delete customer files.
- Explain that foreground scans share one lock and cPanel refreshes are rate-limited.
- Explain incomplete reports as lower bounds, directory ranks as direct-file counts/sizes, and rate limits as cooperative UI controls rather than hostile-tenant resource quotas.
- Keep the small linked Help4 Network builder credit visible in screenshots, tutorials, and derived reports.

Project: https://github.com/Help4Network/help4-disk-usage

Builder credit: https://help4network.com/

The cPanel report body is rendered from the release's real controller with synthetic metadata and a test LiveAPI wrapper; its surrounding shell is illustrative. Other screenshots use synthetic illustrative layouts. None are proof of production health or cPanel certification.
