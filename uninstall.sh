#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Uninstall must run as root on a cPanel & WHM server." >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="/root/help4-disk-usage-uninstall-backups/${STAMP}"

APP_DIR="/usr/local/cpanel/3rdparty/help4-disk-usage"
WHM_CGI_DIR="/usr/local/cpanel/whostmgr/docroot/cgi/help4_disk_usage"
WHM_TEMPLATE_DIR="/usr/local/cpanel/whostmgr/docroot/templates/help4_disk_usage"
WHM_STATIC_DIR="/usr/local/cpanel/whostmgr/docroot/help4-disk-usage"
WHM_ICON="/usr/local/cpanel/whostmgr/docroot/addon_plugins/help4-disk-usage.png"
CPANEL_DIR="/usr/local/cpanel/base/frontend/jupiter/help4_disk_usage"
APP_CONF="/var/cpanel/apps/help4_disk_usage.conf"
CRON_FILE="/etc/cron.d/help4-disk-usage"

mkdir -p "$BACKUP_DIR"
for path in "$APP_DIR" "$WHM_CGI_DIR" "$WHM_TEMPLATE_DIR" "$WHM_STATIC_DIR" "$WHM_ICON" "$CPANEL_DIR" "$APP_CONF" "$CRON_FILE"; do
  if [ -e "$path" ]; then
    backup_name="$(printf '%s' "$path" | sed 's#^/##; s#[^A-Za-z0-9._-]#_#g')"
    cp -a "$path" "$BACKUP_DIR/$backup_name"
  fi
done

if [ -x /usr/local/cpanel/scripts/uninstall_plugin ]; then
  /usr/local/cpanel/scripts/uninstall_plugin "$ROOT_DIR/packaging" --theme=jupiter >/dev/null || true
fi

if [ -x /usr/local/cpanel/bin/unregister_appconfig ] && [ -e "$APP_CONF" ]; then
  /usr/local/cpanel/bin/unregister_appconfig "$APP_CONF" || true
fi

rm -rf "$APP_DIR" "$WHM_CGI_DIR" "$WHM_TEMPLATE_DIR" "$WHM_STATIC_DIR" "$CPANEL_DIR"
rm -f "$WHM_ICON" "$CRON_FILE"

echo "Help4 Disk Usage uninstalled."
echo "Backup/snapshot: $BACKUP_DIR"
echo "Scan cache remains at /var/cpanel/help4-disk-usage; remove it manually if desired."
