# Rollout Guide

Use this guide when pushing Help4 Disk Usage from the public repo to managed cPanel servers.

## Targets

- Genie is the first validated live target.
- Enabled WHMCS cPanel server records can be checked and updated after credentials and SSH access are verified.
- Disabled WHMCS server records should be skipped.

## Recommended Flow

1. Push code to GitHub.
2. Let CI pass.
3. Build the release tarball with `./scripts/package.sh`.
4. On each target server, run:

   ```bash
   /usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-update --check
   /usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-update --apply
   ```

5. Confirm:
   - updater reports `current`
   - WHM page renders
   - cPanel account page renders
   - WHMCS server health row shows the installed version

## First Install on a New cPanel Server

For servers that do not have the updater yet:

```bash
set -euo pipefail
tmp="$(mktemp -d /root/help4-disk-usage.XXXXXX)"
cd "$tmp"
curl -fsSL -o help4-disk-usage.tar.gz "https://github.com/Help4Network/help4-disk-usage/archive/refs/heads/main.tar.gz"
tar -xzf help4-disk-usage.tar.gz
cd help4-disk-usage-*
HELP4_DU_RELEASE_URL="https://github.com/Help4Network/help4-disk-usage/archive/refs/heads/main.tar.gz" ./install.sh
```

The installer snapshots existing plugin files before replacing them.

## Production Release URL

The default release URL points to GitHub `main.tar.gz`, which is useful during active development. For production, set the WHM/WHMCS release URL to an immutable GitHub Release tarball so every target receives the same reviewed artifact.

## Skips

Skip any server record that is disabled, missing SSH access, missing a decryptable root/admin credential, or not confirmed as a cPanel/WHM server.

