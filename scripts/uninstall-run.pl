#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use Cwd qw(abs_path);
use lib "$FindBin::Bin/../src/lib";
use Help4::DiskUsage::InstallSafety;

die "Removal runner requires Linux, root and no arguments\n" if @ARGV || $^O ne 'linux' || $> != 0;
my $root = abs_path("$FindBin::Bin/..") or die "Removal source unavailable\n";
my $paths = Help4::DiskUsage::InstallSafety::audit(Help4::DiskUsage::InstallSafety::removal_targets());
die "Removal paths are unsafe; inspect installation ownership and permissions\n" unless $paths->{ok};
my $status;
my $ok = eval {
    $status = Help4::DiskUsage::InstallSafety::with_removal_lock(sub {
        local $/;
        my $body = <DATA>;
        # The parent holds the mutex; native utilities must not inherit its handle.
        return system {'/bin/bash'} '/bin/bash', '-c', $body, 'help4-uninstall', $root;
    });
    1;
};
if (!$ok) { warn $@ || "Removal admission failed\n"; exit 2; }
die "Removal child could not start\n" if $status == -1;
exit(($status & 127) ? 128 + ($status & 127) : $status >> 8);

__DATA__
set -euo pipefail
ROOT_DIR="$1"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_ROOT="${HELP4_DU_BACKUP_DIR:-}"
BACKUP_DIR=""

APP_DIR="/usr/local/cpanel/3rdparty/help4-disk-usage"
WHM_CGI_DIR="/usr/local/cpanel/whostmgr/docroot/cgi/help4_disk_usage"
WHM_TEMPLATE_DIR="/usr/local/cpanel/whostmgr/docroot/templates/help4_disk_usage"
WHM_STATIC_DIR="/usr/local/cpanel/whostmgr/docroot/help4-disk-usage"
WHM_ICON="/usr/local/cpanel/whostmgr/docroot/addon_plugins/help4-disk-usage.png"
CPANEL_DIR="/usr/local/cpanel/base/frontend/jupiter/help4_disk_usage"
APP_CONF="/var/cpanel/apps/help4_disk_usage.conf"
CRON_FILE="/etc/cron.d/help4-disk-usage"
LOGROTATE_FILE="/etc/logrotate.d/help4-disk-usage"

if [ -n "$BACKUP_ROOT" ]; then
  BACKUP_DIR="${BACKUP_ROOT%/}/${STAMP}"
  mkdir -p "$BACKUP_DIR"
  chmod 0700 "$BACKUP_DIR"
  for path in "$APP_DIR" "$WHM_CGI_DIR" "$WHM_TEMPLATE_DIR" "$WHM_STATIC_DIR" "$WHM_ICON" "$CPANEL_DIR" "$APP_CONF" "$CRON_FILE" "$LOGROTATE_FILE"; do
    if [ -e "$path" ]; then
      backup_name="$(printf '%s' "$path" | sed 's#^/##; s#[^A-Za-z0-9._-]#_#g')"
      cp -a "$path" "$BACKUP_DIR/$backup_name"
    fi
  done
fi

if [ -x /usr/local/cpanel/scripts/uninstall_plugin ]; then
  /usr/local/cpanel/scripts/uninstall_plugin "$ROOT_DIR/packaging" --theme=jupiter >/dev/null
fi
if [ -x /usr/local/cpanel/bin/unregister_appconfig ] && [ -e "$APP_CONF" ]; then
  /usr/local/cpanel/bin/unregister_appconfig "$APP_CONF"
fi
rm -rf "$APP_DIR" "$WHM_CGI_DIR" "$WHM_TEMPLATE_DIR" "$WHM_STATIC_DIR" "$CPANEL_DIR"
rm -f "$WHM_ICON" "$CRON_FILE" "$LOGROTATE_FILE"
echo "Help4 Disk Usage uninstalled."
if [ -n "$BACKUP_DIR" ]; then
  echo "Backup/snapshot: $BACKUP_DIR"
fi
echo "Scan cache remains at /var/cpanel/help4-disk-usage; remove it manually if desired."
