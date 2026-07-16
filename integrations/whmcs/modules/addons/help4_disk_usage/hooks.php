<?php

if (!defined('WHMCS')) {
    die('This file cannot be accessed directly');
}

use WHMCS\Database\Capsule;
use WHMCS\View\Menu\Item as MenuItem;

if (class_exists('\WHMCS\Module\AbstractWidget') && !class_exists('Help4DiskUsageHealthWidget')) {
    class Help4DiskUsageHealthWidget extends \WHMCS\Module\AbstractWidget
    {
        protected $title = 'Help4 Disk Usage Health';
        protected $description = 'cPanel server scan health from Help4 Disk Usage.';
        protected $weight = 40;
        protected $cache = false;
        protected $requiredPermission = 'Perform Server Operations';

        public function getData()
        {
            try {
                if (!Capsule::schema()->hasTable('mod_help4_disk_usage_servers')) {
                    return ['available' => false, 'message' => 'Activate Help4 Disk Usage to create reporting tables.'];
                }

                $servers = Capsule::table('tblservers')
                    ->select('id', 'name', 'hostname', 'ipaddress', 'type', 'disabled')
                    ->where(function ($query) {
                        $query->whereIn('type', ['cpanel', 'cpanelExtended', 'whm'])
                            ->orWhere('type', 'like', '%cpanel%');
                    })
                    ->orderBy('name')
                    ->get();

                $rows = [];
                $counts = [
                    'healthy' => 0,
                    'attention' => 0,
                    'stale' => 0,
                    'error' => 0,
                    'not_checked' => 0,
                    'not_synced' => 0,
                    'update_available' => 0,
                    'disabled' => 0,
                ];

                foreach ($servers as $server) {
                    $state = Capsule::table('mod_help4_disk_usage_servers')
                        ->where('whmcs_server_id', $server->id)
                        ->first();
                    $health = $this->healthForServer($server, $state);
                    $counts[$health['status']]++;
                    $rows[] = [
                        'server' => $server,
                        'state' => $state ?: (object)[],
                        'health' => $health,
                    ];
                }

                usort($rows, function ($a, $b) {
                    return $a['health']['sort'] <=> $b['health']['sort'];
                });

                return [
                    'available' => true,
                    'counts' => $counts,
                    'serverCount' => count($rows),
                    'rows' => array_slice($rows, 0, 5),
                ];
            } catch (Throwable $e) {
                return ['available' => false, 'message' => 'Unable to load Help4 Disk Usage health: ' . $e->getMessage()];
            }
        }

        public function generateOutput($data)
        {
            $link = 'addonmodules.php?module=help4_disk_usage&view=health';
            if (empty($data['available'])) {
                return '<p>' . $this->escape($data['message'] ?? 'Help4 Disk Usage health is not available yet.') . '</p>'
                    . '<p><a class="btn btn-default btn-sm" href="' . $link . '">Open Help4 Disk Usage</a></p>';
            }

            $counts = $data['counts'];
            $html = '<div class="row text-center" style="margin-bottom:10px">';
            $html .= $this->metric('Healthy', $counts['healthy'], 'success');
            $html .= $this->metric('Attention', $counts['attention'], 'warning');
            $html .= $this->metric('Updates', $counts['update_available'], 'warning');
            $html .= $this->metric('Stale', $counts['stale'], 'warning');
            $html .= $this->metric('Errors', $counts['error'], 'danger');
            $html .= '</div>';

            $html .= '<table class="table table-condensed" style="margin-bottom:10px"><thead><tr><th>Server</th><th>Health</th><th>Last Scan</th><th>Next Step</th></tr></thead><tbody>';
            foreach ($data['rows'] as $row) {
                $server = $row['server'];
                $state = $row['state'];
                $health = $row['health'];
                $host = $server->hostname ?: $server->ipaddress ?: 'no host';
                $html .= '<tr>';
                $html .= '<td><strong>' . $this->escape($server->name ?: ('Server #' . $server->id)) . '</strong><br><small class="text-muted">' . $this->escape($host) . '</small></td>';
                $html .= '<td>' . $this->badge($health['status']) . '</td>';
                $html .= '<td>' . $this->escape($state->last_scan_at ?? 'never') . '<br><small class="text-muted">' . $this->escape($health['scan_age']) . '</small></td>';
                $html .= '<td>' . $this->escape($health['next_step']) . '</td>';
                $html .= '</tr>';
            }
            if (empty($data['rows'])) {
                $html .= '<tr><td colspan="4">No cPanel/WHM server records were found.</td></tr>';
            }
            $html .= '</tbody></table>';
            $html .= '<p><a class="btn btn-primary btn-sm" href="' . $link . '">Open Server Health</a></p>';

            return $html;
        }

        private function healthForServer($server, $state)
        {
            if ((int)($server->disabled ?? 0) === 1) {
                return ['status' => 'disabled', 'next_step' => 'Server is disabled in WHMCS.', 'scan_age' => 'disabled', 'sort' => 90];
            }
            if (!$state) {
                return ['status' => 'not_checked', 'next_step' => 'Run Check, then Deploy if missing.', 'scan_age' => 'never', 'sort' => 50];
            }
            if (($state->status ?? '') === 'error' || (string)($state->last_error ?? '') !== '') {
                return ['status' => 'error', 'next_step' => 'Review the last error, then run Check.', 'scan_age' => $this->age($state->last_scan_at ?? null), 'sort' => 10];
            }
            if (($state->status ?? '') === 'update_available') {
                return ['status' => 'update_available', 'next_step' => 'Run Update to pull the configured release.', 'scan_age' => $this->age($state->last_scan_at ?? null), 'sort' => 25];
            }
            if (($state->status ?? '') === 'partial') {
                return ['status' => 'attention', 'next_step' => 'Run Sync again; accounts are still pending.', 'scan_age' => $this->age($state->last_scan_at ?? null), 'sort' => 28];
            }
            if (!$state->last_scan_at) {
                return ['status' => 'not_synced', 'next_step' => 'Run Sync to collect the first scan.', 'scan_age' => 'never', 'sort' => 40];
            }

            $ageSeconds = time() - strtotime((string)$state->last_scan_at);
            if ($ageSeconds > 86400) {
                return ['status' => 'stale', 'next_step' => 'Run Sync; scan is older than 24 hours.', 'scan_age' => $this->age($state->last_scan_at), 'sort' => 20];
            }
            if ((int)($state->bad_count ?? 0) > 0 || (int)($state->check_count ?? 0) > 0) {
                return ['status' => 'attention', 'next_step' => 'Review Customer Reports.', 'scan_age' => $this->age($state->last_scan_at), 'sort' => 30];
            }
            return ['status' => 'healthy', 'next_step' => 'No immediate action needed.', 'scan_age' => $this->age($state->last_scan_at), 'sort' => 80];
        }

        private function age($datetime)
        {
            if (!$datetime) {
                return 'never';
            }
            $ts = strtotime((string)$datetime);
            if (!$ts) {
                return 'unknown age';
            }
            $seconds = max(0, time() - $ts);
            if ($seconds < 3600) {
                return floor($seconds / 60) . ' minutes ago';
            }
            if ($seconds < 86400) {
                return floor($seconds / 3600) . ' hours ago';
            }
            return floor($seconds / 86400) . ' days ago';
        }

        private function metric($label, $value, $context)
        {
            return '<div class="col-sm-3"><span class="label label-' . $context . '" style="font-size:13px">' . (int)$value . '</span><br><small>' . $this->escape($label) . '</small></div>';
        }

        private function badge($status)
        {
            $contexts = [
                'healthy' => 'success',
                'attention' => 'warning',
                'stale' => 'warning',
                'error' => 'danger',
                'update_available' => 'warning',
                'not_checked' => 'default',
                'not_synced' => 'default',
                'disabled' => 'default',
            ];
            $context = $contexts[$status] ?? 'default';
            return '<span class="label label-' . $context . '">' . $this->escape(str_replace('_', ' ', $status)) . '</span>';
        }

        private function escape($value)
        {
            return htmlspecialchars((string)$value, ENT_QUOTES, 'UTF-8');
        }
    }

    add_hook('AdminHomeWidgets', 1, function () {
        return new Help4DiskUsageHealthWidget();
    });
}

add_hook('ClientAreaPrimaryNavbar', 1, function (MenuItem $primaryNavbar) {
    try {
        $enabled = Capsule::table('tbladdonmodules')
            ->where('module', 'help4_disk_usage')
            ->where('setting', 'clientArea')
            ->value('value');
        if ($enabled !== 'on') {
            return;
        }
    } catch (Throwable $e) {
        return;
    }

    if (!$primaryNavbar->getChild('Services')) {
        return;
    }

    $primaryNavbar->getChild('Services')->addChild('Help4 Disk Usage', [
        'label' => 'Disk Usage Reports',
        'uri' => 'index.php?m=help4_disk_usage',
        'order' => 80,
    ]);
});
