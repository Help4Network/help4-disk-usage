# Rollout Guide

Use this guide when pushing Help4 Disk Usage from the public repo to managed cPanel servers.

## Targets

- Genie is the first validated live target.
- Enabled WHMCS cPanel server records can be checked and updated after the exact endpoint, existing SSH host-key trust, credentials and native compatibility are verified.
- Disabled WHMCS server records should be skipped.

## Recommended Flow

1. Commit and push the release code.
2. Let exact-commit CI pass, then complete version-matched native installation/upgrade, WHM root/reseller, cPanel account isolation, refresh/File Manager and applicable WHMCS verification. CI and container tests alone are not native release approval.
3. Obtain explicit stable release approval before tagging the immutable release, for example `v1.0.0`, and pushing the tag. Keep candidates off the stable channel until these gates pass.
4. Download the exact tag archive, calculate its SHA-256, and publish that digest in `update.json` on the release channel.
5. Confirm `update.json` uses the tag archive URL, not a moving branch archive.
6. On each authorized target, verify host identity as described below and run the native preflight from the reviewed release checkout (`./install.sh --check`). Resolve failures before applying. Then run:

   ```bash
   /usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-update --check
   /usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-update --apply
   ```

7. Confirm:
   - scanner and completed-install metadata match the approved version; updater reports `current`
   - WHM page renders
   - cPanel account page renders
   - WHMCS server health row shows the installed version and fresh observations, if that integration is installed

## SSH Host Identity Gate

Treat an unexpected SSH host key as an unverified target, not a routine retry. Stop that target's Check, Deploy, Update and Sync actions before password authentication or remote commands. Preserve the existing trusted pin/known-host entry and leave **Allow Unpinned SSH** off; do not remove the pin, accept an observed key on first use, or disable verification to make a rollout proceed.

Use the provider's authenticated console or an independently trusted management channel to verify the exact server record, endpoint, SSH port and current host-key fingerprint. Confirm authorized rotation/rebuild provenance before changing trust. A provider inventory entry, public TLS certificate, failed connection, or result obtained from a different server does not establish the SSH identity of this target. Record the verified old/new binding and update only that target's pin after accountable approval. Other independently verified targets can proceed through their own gates.

From that trusted server console, a SHA-256 fingerprint can be read with:

```bash
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub -E sha256
```

Compare the same host-key algorithm used by the connection; an Ed25519 fingerprint cannot stand in for an RSA host key. See the official [ssh-keygen manual](https://man.openbsd.org/ssh-keygen) and the [WHMCS integration guide](whmcs-integration.md). Host-key agreement alone does not clear unrelated integrity findings or authorize a production update.

## First Install on a New cPanel Server

For servers that do not have the updater yet:

```bash
set -euo pipefail
tmp="$(mktemp -d /root/help4-disk-usage.XXXXXX)"
cd "$tmp"
curl -fsSL --connect-timeout 10 --max-time 60 -o update.json "https://raw.githubusercontent.com/Help4Network/help4-disk-usage/main/update.json"
package_url="$(perl -MJSON::PP -0777 -e '
  my $d = decode_json(<>);
  die "Invalid approved release manifest\n" unless ref($d) eq "HASH"
    && defined($d->{version}) && !ref($d->{version})
    && $d->{version} =~ /\A(?:0|[1-9][0-9]{0,3})\.(?:0|[1-9][0-9]{0,3})\.(?:0|[1-9][0-9]{0,3})\z/
    && defined($d->{package_url}) && !ref($d->{package_url})
    && $d->{package_url} eq "https://github.com/Help4Network/help4-disk-usage/archive/refs/tags/v" . $d->{version} . ".tar.gz"
    && defined($d->{sha256}) && !ref($d->{sha256}) && $d->{sha256} =~ /\A[0-9a-fA-F]{64}\z/;
  print $d->{package_url};
' update.json)"
curl -fsSL --connect-timeout 10 --max-time 60 -o help4-disk-usage.tar.gz "$package_url"
expected="$(perl -MJSON::PP -0777 -e 'my $d=decode_json(<>); print $d->{sha256}' update.json)"
printf '%s  %s\n' "$expected" help4-disk-usage.tar.gz | sha256sum -c -
tar -xzf help4-disk-usage.tar.gz
cd help4-disk-usage-*
./install.sh --check
HELP4_DU_RELEASE_URL="$package_url" \
HELP4_DU_UPDATE_MANIFEST_URL="https://raw.githubusercontent.com/Help4Network/help4-disk-usage/main/update.json" \
./install.sh
```

This example intentionally permits only the default repository's version-matched immutable tag archive. For an operator-controlled mirror, use its separately approved immutable URL and digest with equivalent validation; do not weaken the default example to accept arbitrary or moving sources. A checksum proves byte integrity, not native compatibility, host identity or stable approval.

The installer does not create a filesystem snapshot by default. Prior immutable Git tags are the rollback source. Set `HELP4_DU_BACKUP_DIR` only when an operator explicitly requires a snapshot.

## Production Update Channel

The default update manifest points to repository `update.json`. Its `package_url` must be an immutable tag/release archive and its `sha256` must match the downloaded bytes. The updater refuses apply operations when the digest is missing or mismatched.

## Skips

Skip any server record that is disabled, missing SSH access, missing a decryptable root/admin credential, has unverified or mismatched host-key/endpoint binding, fails native preflight, or is not confirmed as an authorized cPanel/WHM target. Do not treat a skipped target as deployed or verified.
