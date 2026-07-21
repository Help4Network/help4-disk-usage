# Rollout Guide

Use this guide when pushing Help4 Disk Usage from the public repo to managed cPanel servers.

## Targets

- Genie is the first validated live target.
- Enabled WHMCS cPanel server records can be checked and updated after credentials and SSH access are verified.
- Disabled WHMCS server records should be skipped.

## Recommended Flow

1. Commit and push the release code.
2. Let CI pass.
3. Tag the immutable release, for example `v0.3.5`, and push the tag.
4. Download the exact tag archive, calculate its SHA-256, and publish that digest in `update.json` on the release channel.
5. Confirm `update.json` uses the tag archive URL, not a moving branch archive.
6. On each target server, run:

   ```bash
   /usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-update --check
   /usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-update --apply
   ```

7. Confirm:
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
curl -fsSL -o update.json "https://raw.githubusercontent.com/Help4Network/help4-disk-usage/main/update.json"
package_url="$(perl -MJSON::PP -0777 -e 'my $d=decode_json(<>); print $d->{package_url}' update.json)"
curl -fsSL -o help4-disk-usage.tar.gz "$package_url"
expected="$(perl -MJSON::PP -0777 -e 'my $d=decode_json(<>); print $d->{sha256}' update.json)"
printf '%s  %s\n' "$expected" help4-disk-usage.tar.gz | sha256sum -c -
tar -xzf help4-disk-usage.tar.gz
cd help4-disk-usage-*
HELP4_DU_RELEASE_URL="https://github.com/Help4Network/help4-disk-usage/archive/refs/tags/v0.3.5.tar.gz" \
HELP4_DU_UPDATE_MANIFEST_URL="https://raw.githubusercontent.com/Help4Network/help4-disk-usage/main/update.json" \
./install.sh
```

The installer does not create a filesystem snapshot by default. Prior immutable Git tags are the rollback source. Set `HELP4_DU_BACKUP_DIR` only when an operator explicitly requires a snapshot.

## Production Update Channel

The default update manifest points to repository `update.json`. Its `package_url` must be an immutable tag/release archive and its `sha256` must match the downloaded bytes. The updater refuses apply operations when the digest is missing or mismatched.

## Skips

Skip any server record that is disabled, missing SSH access, missing a decryptable root/admin credential, or not confirmed as a cPanel/WHM server.
