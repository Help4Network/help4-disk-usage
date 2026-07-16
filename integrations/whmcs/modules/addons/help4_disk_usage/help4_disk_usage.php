<?php

if (!defined('WHMCS')) {
    die('This file cannot be accessed directly');
}

use WHMCS\Database\Capsule;

const H4DU_VERSION = '0.3.1';
const H4DU_DEFAULT_RELEASE_URL = 'https://github.com/Help4Network/help4-disk-usage/archive/refs/tags/v0.3.1.tar.gz';
const H4DU_DEFAULT_UPDATE_MANIFEST_URL = 'https://raw.githubusercontent.com/Help4Network/help4-disk-usage/main/update.json';

function help4_disk_usage_config()
{
    return [
        'name' => 'Help4 Disk Usage',
        'description' => 'Deploy and report Help4 Disk Usage scans across WHM/cPanel servers for admin, support, and customer workflows.',
        'version' => H4DU_VERSION,
        'author' => 'Help4 Network',
        'language' => 'english',
        'fields' => [
            'releaseUrl' => [
                'FriendlyName' => 'Release Tarball URL',
                'Type' => 'text',
                'Size' => '90',
                'Default' => H4DU_DEFAULT_RELEASE_URL,
                'Description' => 'Fallback package URL for update checks. Initial deployment uses the checksum-bearing update manifest.',
            ],
            'updateManifestUrl' => [
                'FriendlyName' => 'Update Manifest URL',
                'Type' => 'text',
                'Size' => '90',
                'Default' => H4DU_DEFAULT_UPDATE_MANIFEST_URL,
                'Description' => 'JSON manifest used by Check/Update. It must publish version, package_url, and sha256; release_notes_url is optional.',
            ],
            'sshPort' => [
                'FriendlyName' => 'Default SSH Port',
                'Type' => 'text',
                'Size' => '8',
                'Default' => '22',
            ],
            'sshHostFingerprints' => [
                'FriendlyName' => 'SSH Host Fingerprints',
                'Type' => 'textarea',
                'Rows' => '6',
                'Cols' => '90',
                'Description' => 'Required by default. JSON object keyed by WHMCS server ID, hostname, or IP. Values are OpenSSH SHA256 fingerprints or SHA-256 hex.',
            ],
            'allowUnpinnedSsh' => [
                'FriendlyName' => 'Allow Unpinned SSH',
                'Type' => 'yesno',
                'Description' => 'Unsafe compatibility override. Leave off so Check, Deploy, Update, and Sync fail closed when a server fingerprint is missing.',
            ],
            'syncAccountLimit' => [
                'FriendlyName' => 'Sync Account Limit',
                'Type' => 'text',
                'Size' => '8',
                'Default' => '0',
                'Description' => '0 means scan all accounts. Use a small number during first rollout.',
            ],
            'scanMaxSeconds' => [
                'FriendlyName' => 'Whole Sync Scan Max Seconds',
                'Type' => 'text',
                'Size' => '8',
                'Default' => '90',
            ],
            'clientArea' => [
                'FriendlyName' => 'Client Area Reports',
                'Type' => 'yesno',
                'Description' => 'Show latest disk/inode scan summaries to logged-in clients for their own services.',
                'Default' => 'on',
            ],
            'displayName' => [
                'FriendlyName' => 'Display Name',
                'Type' => 'text',
                'Size' => '90',
                'Default' => 'Disk Usage Audit',
            ],
            'creditPrefix' => [
                'FriendlyName' => 'Footer Credit Prefix',
                'Type' => 'text',
                'Size' => '40',
                'Default' => 'Built by',
                'Description' => 'Prefix text before the required Help4 Network builder credit link.',
            ],
        ],
    ];
}

function help4_disk_usage_activate()
{
    try {
        if (!Capsule::schema()->hasTable('mod_help4_disk_usage_servers')) {
            Capsule::schema()->create('mod_help4_disk_usage_servers', function ($table) {
                $table->increments('id');
                $table->integer('whmcs_server_id')->unsigned()->unique();
                $table->string('hostname', 255)->default('');
                $table->string('status', 32)->default('unknown');
                $table->string('plugin_version', 32)->default('');
                $table->dateTime('last_seen_at')->nullable();
                $table->dateTime('last_scan_at')->nullable();
                $table->integer('account_count')->unsigned()->default(0);
                $table->integer('bad_count')->unsigned()->default(0);
                $table->integer('check_count')->unsigned()->default(0);
                $table->text('raw_summary')->nullable();
                $table->text('last_error')->nullable();
                $table->timestamps();
            });
        }

        if (!Capsule::schema()->hasTable('mod_help4_disk_usage_accounts')) {
            Capsule::schema()->create('mod_help4_disk_usage_accounts', function ($table) {
                $table->increments('id');
                $table->integer('whmcs_server_id')->unsigned();
                $table->integer('service_id')->unsigned()->nullable();
                $table->integer('client_id')->unsigned()->nullable();
                $table->string('username', 128);
                $table->string('domain', 255)->default('');
                $table->string('owner', 128)->default('');
                $table->string('severity', 32)->default('unknown');
                $table->bigInteger('disk_bytes')->unsigned()->default(0);
                $table->integer('inode_count')->unsigned()->default(0);
                $table->dateTime('scanned_at')->nullable();
                $table->text('hints_json')->nullable();
                $table->text('large_files_json')->nullable();
                $table->text('hotspots_json')->nullable();
                $table->timestamps();
                $table->unique(['whmcs_server_id', 'username'], 'h4du_server_user_unique');
                $table->index(['client_id', 'service_id'], 'h4du_client_service_idx');
            });
        }

        if (!Capsule::schema()->hasTable('mod_help4_disk_usage_events')) {
            Capsule::schema()->create('mod_help4_disk_usage_events', function ($table) {
                $table->increments('id');
                $table->integer('whmcs_server_id')->unsigned()->nullable();
                $table->string('event_type', 64);
                $table->string('status', 32)->default('info');
                $table->text('message');
                $table->text('details')->nullable();
                $table->timestamps();
            });
        }

        return [
            'status' => 'success',
            'description' => 'Help4 Disk Usage tables were created. Open Addons > Help4 Disk Usage to deploy or sync cPanel servers.',
        ];
    } catch (Throwable $e) {
        return [
            'status' => 'error',
            'description' => 'Unable to activate Help4 Disk Usage: ' . $e->getMessage(),
        ];
    }
}

function help4_disk_usage_deactivate()
{
    return [
        'status' => 'success',
        'description' => 'Help4 Disk Usage was deactivated. Reporting tables are intentionally retained so historical support data is not lost.',
    ];
}

function help4_disk_usage_upgrade($vars)
{
    if (!Capsule::schema()->hasTable('mod_help4_disk_usage_events')) {
        Capsule::schema()->create('mod_help4_disk_usage_events', function ($table) {
            $table->increments('id');
            $table->integer('whmcs_server_id')->unsigned()->nullable();
            $table->string('event_type', 64);
            $table->string('status', 32)->default('info');
            $table->text('message');
            $table->text('details')->nullable();
            $table->timestamps();
        });
    }
}

function help4_disk_usage_output($vars)
{
    $moduleLink = $vars['modulelink'];
    $view = $_GET['view'] ?? 'dashboard';
    $postAction = $_POST['h4du_action'] ?? '';
    $message = null;

    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST') {
        if (!help4_disk_usage_check_token()) {
            $message = ['status' => 'error', 'message' => 'WHMCS CSRF validation is unavailable; remote actions are disabled.'];
            $postAction = '';
        }
        $serverId = (int)($_POST['server_id'] ?? 0);
        if ($postAction === 'check_server') {
            $message = help4_disk_usage_check_server($serverId, $vars);
        } elseif ($postAction === 'deploy_server') {
            $message = help4_disk_usage_deploy_server($serverId, $vars);
        } elseif ($postAction === 'update_server') {
            $message = help4_disk_usage_update_server($serverId, $vars);
        } elseif ($postAction === 'sync_server') {
            $message = help4_disk_usage_sync_server($serverId, $vars);
        }
    }

    echo help4_disk_usage_admin_css();
    echo '<div class="h4du-wrap">';
    echo '<h1>' . help4_disk_usage_e(help4_disk_usage_display_name($vars)) . '</h1>';
    echo '<p class="h4du-muted">WHMCS deployment and support reporting for cPanel/WHM disk and inode scans.</p>';
    echo help4_disk_usage_tabs($moduleLink, $view);
    if ($message) {
        echo help4_disk_usage_notice($message['status'], $message['message']);
    }

    if ($view === 'health') {
        echo help4_disk_usage_health_page($moduleLink, $vars);
    } elseif ($view === 'servers') {
        echo help4_disk_usage_servers_page($moduleLink, $vars);
    } elseif ($view === 'accounts') {
        echo help4_disk_usage_accounts_page($moduleLink);
    } elseif ($view === 'events') {
        echo help4_disk_usage_events_page();
    } else {
        echo help4_disk_usage_dashboard_page($moduleLink, $vars);
    }

    echo help4_disk_usage_credit_html($vars);
    echo '</div>';
}

function help4_disk_usage_clientarea($vars)
{
    if (($vars['clientArea'] ?? '') !== 'on') {
        return [
            'pagetitle' => 'Help4 Disk Usage',
            'breadcrumb' => ['index.php?m=help4_disk_usage' => 'Help4 Disk Usage'],
            'templatefile' => 'clientarea',
            'requirelogin' => true,
            'vars' => ['accounts' => [], 'disabled' => true, 'displayName' => help4_disk_usage_display_name($vars), 'creditPrefix' => help4_disk_usage_credit_prefix($vars)],
        ];
    }

    $clientId = (int)($_SESSION['uid'] ?? 0);
    if ($clientId <= 0) {
        $accounts = [];
    } else {
        $accounts = Capsule::table('mod_help4_disk_usage_accounts as a')
            ->join('tblhosting as h', function ($join) {
                $join->on('a.service_id', '=', 'h.id')
                    ->on('a.whmcs_server_id', '=', 'h.server')
                    ->on('a.username', '=', 'h.username');
            })
            ->where('h.userid', $clientId)
            ->select('a.*', 'h.domain as current_domain')
            ->orderBy('severity', 'asc')
            ->orderBy('disk_bytes', 'desc')
            ->get();
    }
    $accountRows = json_decode(json_encode($accounts), true);
    foreach ($accountRows as &$accountRow) {
        $accountRow['domain'] = $accountRow['current_domain'] ?: $accountRow['domain'];
        $hints = json_decode($accountRow['hints_json'] ?? '[]', true) ?: [];
        $accountRow['first_hint'] = $hints[0] ?? 'Review the latest scan before making cleanup decisions.';
    }

    return [
        'pagetitle' => 'Help4 Disk Usage',
        'breadcrumb' => ['index.php?m=help4_disk_usage' => 'Help4 Disk Usage'],
        'templatefile' => 'clientarea',
        'requirelogin' => true,
        'forcessl' => true,
        'vars' => [
            'accounts' => $accountRows,
            'disabled' => false,
            'displayName' => help4_disk_usage_display_name($vars),
            'creditPrefix' => help4_disk_usage_credit_prefix($vars),
        ],
    ];
}

function help4_disk_usage_dashboard_page($moduleLink, $vars)
{
    $serverCount = Capsule::table('mod_help4_disk_usage_servers')->count();
    $accountCount = Capsule::table('mod_help4_disk_usage_accounts')->count();
    $badCount = Capsule::table('mod_help4_disk_usage_accounts')->where('severity', 'bad')->count();
    $checkCount = Capsule::table('mod_help4_disk_usage_accounts')->where('severity', 'check')->count();
    $top = Capsule::table('mod_help4_disk_usage_accounts')
        ->orderBy('disk_bytes', 'desc')
        ->limit(10)
        ->get();

    $html = '<div class="h4du-metrics">';
    $html .= help4_disk_usage_metric('Tracked servers', $serverCount);
    $html .= help4_disk_usage_metric('Synced accounts', $accountCount);
    $html .= help4_disk_usage_metric('Bad accounts', $badCount);
    $html .= help4_disk_usage_metric('Needs review', $checkCount);
    $html .= '</div>';

    $html .= help4_disk_usage_health_summary($moduleLink, $vars);
    $html .= '<h2>Top Disk Offenders</h2>';
    $html .= help4_disk_usage_accounts_table($top, false);
    $html .= '<p><a class="btn btn-primary" href="' . help4_disk_usage_e($moduleLink) . '&view=health">View server health</a> '
        . '<a class="btn btn-default" href="' . help4_disk_usage_e($moduleLink) . '&view=servers">Deploy or sync servers</a></p>';

    return $html;
}

function help4_disk_usage_health_page($moduleLink, $vars)
{
    $rows = help4_disk_usage_server_health_rows();
    $counts = help4_disk_usage_health_counts($rows);

    $html = '<h2>Server Health</h2>';
    $html .= '<p class="h4du-muted">Operational health across WHMCS cPanel server records. Health combines plugin deployment state, last scan freshness, scan errors, and bad/check account counts.</p>';
    $html .= '<div class="h4du-metrics">';
    $html .= help4_disk_usage_metric('Healthy', $counts['healthy']);
    $html .= help4_disk_usage_metric('Attention', $counts['attention']);
    $html .= help4_disk_usage_metric('Updates', $counts['update_available']);
    $html .= help4_disk_usage_metric('Stale', $counts['stale']);
    $html .= help4_disk_usage_metric('Errors', $counts['error']);
    $html .= help4_disk_usage_metric('Not Checked', $counts['not_checked']);
    $html .= '</div>';
    $html .= '<table class="datatable h4du-table"><thead><tr><th>Server</th><th>Health</th><th>Last Scan</th><th>Coverage</th><th>Findings</th><th>Last Error</th><th>Next Step</th><th>Actions</th></tr></thead><tbody>';

    foreach ($rows as $row) {
        $server = $row['server'];
        $state = $row['state'];
        $html .= '<tr>';
        $html .= '<td><strong>' . help4_disk_usage_e($server->name ?: ('Server #' . $server->id)) . '</strong><br><span class="h4du-muted">' . help4_disk_usage_e($server->hostname ?: $server->ipaddress ?: 'no host') . '</span></td>';
        $html .= '<td>' . help4_disk_usage_badge($row['health']) . '<br><span class="h4du-muted">' . help4_disk_usage_e($state->status ?? 'not checked') . '</span></td>';
        $html .= '<td>' . help4_disk_usage_e($state->last_scan_at ?? 'never') . '<br><span class="h4du-muted">' . help4_disk_usage_e($row['scan_age']) . '</span></td>';
        $html .= '<td>' . (int)($state->account_count ?? 0) . ' scanned accounts</td>';
        $html .= '<td>' . (int)($state->bad_count ?? 0) . ' bad<br>' . (int)($state->check_count ?? 0) . ' check</td>';
        $html .= '<td>' . help4_disk_usage_e($state->last_error ?? '') . '</td>';
        $html .= '<td>' . help4_disk_usage_e($row['next_step']) . '</td>';
        $html .= '<td>' . help4_disk_usage_server_action_form($moduleLink, $server->id, 'check_server', 'Check', 'health') . ' '
            . help4_disk_usage_server_action_form($moduleLink, $server->id, 'deploy_server', 'Deploy', 'health') . ' '
            . help4_disk_usage_server_action_form($moduleLink, $server->id, 'update_server', 'Update', 'health') . ' '
            . help4_disk_usage_server_action_form($moduleLink, $server->id, 'sync_server', 'Sync', 'health') . '</td>';
        $html .= '</tr>';
    }

    if (!$rows) {
        $html .= '<tr><td colspan="8">No cPanel/WHM server records were found in WHMCS.</td></tr>';
    }

    return $html . '</tbody></table>';
}

function help4_disk_usage_health_summary($moduleLink, $vars)
{
    $rows = help4_disk_usage_server_health_rows();
    $counts = help4_disk_usage_health_counts($rows);
    $html = '<h2>Server Health</h2>';
    $html .= '<div class="h4du-metrics compact">';
    $html .= help4_disk_usage_metric('Healthy', $counts['healthy']);
    $html .= help4_disk_usage_metric('Attention', $counts['attention']);
    $html .= help4_disk_usage_metric('Updates', $counts['update_available']);
    $html .= help4_disk_usage_metric('Stale', $counts['stale']);
    $html .= help4_disk_usage_metric('Errors', $counts['error']);
    $html .= '</div>';
    $html .= '<p><a class="btn btn-default" href="' . help4_disk_usage_e($moduleLink) . '&view=health">Open server health</a></p>';
    return $html;
}

function help4_disk_usage_servers_page($moduleLink, $vars)
{
    $servers = help4_disk_usage_cpanel_servers();

    $html = '<h2>cPanel/WHM Servers</h2>';
    $html .= '<p class="h4du-muted">Check verifies installed files and compares against the configured release tarball. Deploy installs the plugin over SSH. Update pulls the configured release when the installed version is behind. Sync runs a bounded scan and stores customer-facing summaries.</p>';
    $html .= '<table class="datatable h4du-table"><thead><tr><th>Server</th><th>Host</th><th>Module</th><th>Status</th><th>Version</th><th>Last Scan</th><th>Counts</th><th>Actions</th></tr></thead><tbody>';

    foreach ($servers as $server) {
        $state = Capsule::table('mod_help4_disk_usage_servers')->where('whmcs_server_id', $server->id)->first();
        $html .= '<tr>';
        $html .= '<td><strong>' . help4_disk_usage_e($server->name) . '</strong><br><span class="h4du-muted">ID ' . (int)$server->id . '</span></td>';
        $html .= '<td>' . help4_disk_usage_e($server->hostname ?: $server->ipaddress) . '</td>';
        $html .= '<td>' . help4_disk_usage_e($server->type) . '</td>';
        $html .= '<td>' . help4_disk_usage_badge($state->status ?? 'unknown') . '</td>';
        $html .= '<td>' . help4_disk_usage_version_summary($state) . '</td>';
        $html .= '<td>' . help4_disk_usage_e($state->last_scan_at ?? 'never') . '</td>';
        $html .= '<td>' . (int)($state->account_count ?? 0) . ' accounts<br>' . (int)($state->bad_count ?? 0) . ' bad / ' . (int)($state->check_count ?? 0) . ' check</td>';
        $html .= '<td>' . help4_disk_usage_server_action_form($moduleLink, $server->id, 'check_server', 'Check', 'servers') . ' '
            . help4_disk_usage_server_action_form($moduleLink, $server->id, 'deploy_server', 'Deploy', 'servers') . ' '
            . help4_disk_usage_server_action_form($moduleLink, $server->id, 'update_server', 'Update', 'servers') . ' '
            . help4_disk_usage_server_action_form($moduleLink, $server->id, 'sync_server', 'Sync', 'servers') . '</td>';
        $html .= '</tr>';
    }

    $html .= '</tbody></table>';
    $html .= '<h3>Manual Deployment Command</h3>';
    $html .= '<pre class="h4du-pre">' . help4_disk_usage_e(help4_disk_usage_install_command($vars['releaseUrl'] ?? H4DU_DEFAULT_RELEASE_URL, $vars['updateManifestUrl'] ?? H4DU_DEFAULT_UPDATE_MANIFEST_URL)) . '</pre>';
    return $html;
}

function help4_disk_usage_cpanel_servers()
{
    return Capsule::table('tblservers')
        ->select('id', 'name', 'hostname', 'ipaddress', 'type', 'username', 'disabled')
        ->where(function ($query) {
            $query->whereIn('type', ['cpanel', 'cpanelExtended', 'whm'])
                ->orWhere('type', 'like', '%cpanel%');
        })
        ->orderBy('name')
        ->get();
}

function help4_disk_usage_cpanel_server($serverId)
{
    return Capsule::table('tblservers')
        ->select('id', 'name', 'hostname', 'ipaddress', 'type', 'username', 'password', 'port', 'disabled')
        ->where('id', (int)$serverId)
        ->where(function ($query) {
            $query->whereIn('type', ['cpanel', 'cpanelExtended', 'whm'])
                ->orWhere('type', 'like', '%cpanel%');
        })
        ->first();
}

function help4_disk_usage_server_health_rows()
{
    $rows = [];
    foreach (help4_disk_usage_cpanel_servers() as $server) {
        $state = Capsule::table('mod_help4_disk_usage_servers')->where('whmcs_server_id', $server->id)->first();
        $health = help4_disk_usage_server_health($server, $state);
        $rows[] = [
            'server' => $server,
            'state' => $state ?: (object)[],
            'health' => $health['status'],
            'next_step' => $health['next_step'],
            'scan_age' => $health['scan_age'],
            'sort' => $health['sort'],
        ];
    }
    usort($rows, function ($a, $b) {
        return $a['sort'] <=> $b['sort'];
    });
    return $rows;
}

function help4_disk_usage_server_health($server, $state)
{
    if ((int)($server->disabled ?? 0) === 1) {
        return ['status' => 'disabled', 'next_step' => 'Server is disabled in WHMCS.', 'scan_age' => 'disabled', 'sort' => 90];
    }
    if (!$state) {
        return ['status' => 'not_checked', 'next_step' => 'Run Check, then Deploy if the plugin is missing.', 'scan_age' => 'never', 'sort' => 50];
    }
    if (($state->status ?? '') === 'error' || (string)($state->last_error ?? '') !== '') {
        return ['status' => 'error', 'next_step' => 'Review the last error, then run Check after fixing access or server state.', 'scan_age' => help4_disk_usage_age($state->last_scan_at ?? null), 'sort' => 10];
    }
    if (($state->status ?? '') === 'update_available') {
        return ['status' => 'update_available', 'next_step' => 'Run Update to pull the configured release tarball.', 'scan_age' => help4_disk_usage_age($state->last_scan_at ?? null), 'sort' => 25];
    }
    if (($state->status ?? '') === 'partial') {
        return ['status' => 'attention', 'next_step' => 'Run Sync again; the bounded scan still has accounts pending.', 'scan_age' => help4_disk_usage_age($state->last_scan_at ?? null), 'sort' => 28];
    }
    if (!$state->last_scan_at) {
        return ['status' => 'not_synced', 'next_step' => 'Run Sync to collect the first server scan.', 'scan_age' => 'never', 'sort' => 40];
    }

    $ageSeconds = time() - strtotime((string)$state->last_scan_at);
    if ($ageSeconds > 86400) {
        return ['status' => 'stale', 'next_step' => 'Run Sync; last scan is older than 24 hours.', 'scan_age' => help4_disk_usage_age($state->last_scan_at), 'sort' => 20];
    }
    if ((int)($state->bad_count ?? 0) > 0 || (int)($state->check_count ?? 0) > 0) {
        return ['status' => 'attention', 'next_step' => 'Review Customer Reports for bad/check accounts.', 'scan_age' => help4_disk_usage_age($state->last_scan_at), 'sort' => 30];
    }
    return ['status' => 'healthy', 'next_step' => 'No immediate action needed.', 'scan_age' => help4_disk_usage_age($state->last_scan_at), 'sort' => 80];
}

function help4_disk_usage_health_counts($rows)
{
    $counts = ['healthy' => 0, 'attention' => 0, 'stale' => 0, 'error' => 0, 'not_checked' => 0, 'not_synced' => 0, 'update_available' => 0, 'disabled' => 0];
    foreach ($rows as $row) {
        $key = $row['health'];
        if (!isset($counts[$key])) {
            $counts[$key] = 0;
        }
        $counts[$key]++;
    }
    return $counts;
}

function help4_disk_usage_age($datetime)
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

function help4_disk_usage_version_summary($state)
{
    if (!$state) {
        return '<span class="h4du-muted">not checked</span>';
    }
    $summary = json_decode($state->raw_summary ?? '{}', true) ?: [];
    $installed = $state->plugin_version ?: ($summary['installed_version'] ?? $summary['version'] ?? '');
    $available = $summary['available_version'] ?? '';
    $html = $installed ? 'Installed ' . help4_disk_usage_e($installed) : '<span class="h4du-muted">unknown</span>';
    if ($available) {
        $html .= '<br><span class="h4du-muted">Available ' . help4_disk_usage_e($available) . '</span>';
    }
    if (!empty($summary['release_url'])) {
        $html .= '<br><span class="h4du-muted">repo configured</span>';
    }
    return $html;
}

function help4_disk_usage_accounts_page($moduleLink)
{
    $query = Capsule::table('mod_help4_disk_usage_accounts')
        ->orderByRaw("FIELD(severity, 'bad', 'incomplete', 'check', 'good', 'unknown')")
        ->orderBy('disk_bytes', 'desc')
        ->limit(200)
        ->get();

    return '<h2>Customer Account Reports</h2>'
        . '<p class="h4du-muted">These rows are safe for support workflows and map scan findings back to WHMCS services when the cPanel username matches a hosting service.</p>'
        . help4_disk_usage_accounts_table($query, true);
}

function help4_disk_usage_events_page()
{
    $events = Capsule::table('mod_help4_disk_usage_events')
        ->orderBy('id', 'desc')
        ->limit(100)
        ->get();
    $html = '<h2>Deployment and Sync Events</h2><table class="datatable h4du-table"><thead><tr><th>Time</th><th>Server</th><th>Type</th><th>Status</th><th>Message</th></tr></thead><tbody>';
    foreach ($events as $event) {
        $html .= '<tr><td>' . help4_disk_usage_e($event->created_at) . '</td><td>' . (int)$event->whmcs_server_id . '</td><td>' . help4_disk_usage_e($event->event_type) . '</td><td>' . help4_disk_usage_badge($event->status) . '</td><td>' . help4_disk_usage_e($event->message) . '</td></tr>';
    }
    return $html . '</tbody></table>';
}

function help4_disk_usage_check_server($serverId, $vars)
{
    return help4_disk_usage_server_ssh_action($serverId, 'check', $vars);
}

function help4_disk_usage_deploy_server($serverId, $vars)
{
    return help4_disk_usage_server_ssh_action($serverId, 'deploy', $vars);
}

function help4_disk_usage_update_server($serverId, $vars)
{
    return help4_disk_usage_server_ssh_action($serverId, 'update', $vars);
}

function help4_disk_usage_sync_server($serverId, $vars)
{
    return help4_disk_usage_server_ssh_action($serverId, 'sync', $vars);
}

function help4_disk_usage_server_ssh_action($serverId, $action, $vars)
{
    $server = help4_disk_usage_cpanel_server($serverId);
    if (!$server) {
        return ['status' => 'error', 'message' => 'cPanel/WHM server not found or not eligible for Help4 Disk Usage actions.'];
    }
    if ((int)($server->disabled ?? 0) === 1) {
        return ['status' => 'error', 'message' => 'Server is disabled in WHMCS. Enable it before running Help4 Disk Usage actions.'];
    }

    $command = help4_disk_usage_command_for_action($action, $vars);
    $scanMaxSeconds = min(600, max(15, (int)($vars['scanMaxSeconds'] ?? 90)));
    $timeout = $action === 'sync' ? $scanMaxSeconds + 60 : 300;
    $fingerprint = help4_disk_usage_expected_fingerprint($server, $vars['sshHostFingerprints'] ?? '');
    $allowUnpinned = ($vars['allowUnpinnedSsh'] ?? '') === 'on';
    $result = help4_disk_usage_ssh_exec(
        $server,
        $command,
        (int)($vars['sshPort'] ?? 22),
        $fingerprint,
        $allowUnpinned,
        $timeout
    );

    if (!$result['ok']) {
        help4_disk_usage_record_server_state($server, 'error', null, $result['error']);
        help4_disk_usage_event($serverId, $action, 'error', $result['error'], $result['output'] ?? '');
        return ['status' => 'error', 'message' => $result['error']];
    }

    if ($action === 'sync') {
        try {
            $saved = help4_disk_usage_save_scan_json($server, $result['output']);
        } catch (Throwable $e) {
            $error = 'Sync output was rejected: ' . $e->getMessage();
            help4_disk_usage_record_server_state($server, 'error', null, $error);
            help4_disk_usage_event($serverId, $action, 'error', $error, '');
            return ['status' => 'error', 'message' => $error];
        }
        $message = 'Synced ' . $saved['accounts'] . ' account scan records from ' . ($server->name ?: $server->hostname)
            . '; ' . $saved['tracked'] . ' accounts are now tracked.'
            . ($saved['partial'] ? ' The bounded scan has accounts pending, so run Sync again.' : '');
        help4_disk_usage_event($serverId, $action, 'success', $message, '');
        return ['status' => 'success', 'message' => $message];
    }

    if ($action === 'check') {
        $check = help4_disk_usage_parse_update_json($result['output']);
        if (empty($check['ok'])) {
            $error = 'Check output was rejected: ' . ($check['error'] ?? 'invalid updater response');
            help4_disk_usage_record_server_state($server, 'error', null, $error);
            help4_disk_usage_event($serverId, $action, 'error', $error, '');
            return ['status' => 'error', 'message' => $error];
        }
        $status = $check['status'] ?? 'installed';
        help4_disk_usage_record_server_state($server, $status, [
            'plugin_version' => (string)($check['installed_version'] ?? ''),
            'raw_summary' => json_encode($check),
        ], null);
        $message = help4_disk_usage_check_message($server, $check);
        help4_disk_usage_event($serverId, $action, 'success', $message, $result['output']);
        return ['status' => 'success', 'message' => $message];
    }

    if ($action === 'update') {
        $update = help4_disk_usage_parse_update_json($result['output']);
        if (empty($update['ok'])) {
            $error = 'Update output was rejected: ' . ($update['error'] ?? 'invalid updater response');
            help4_disk_usage_record_server_state($server, 'error', null, $error);
            help4_disk_usage_event($serverId, $action, 'error', $error, '');
            return ['status' => 'error', 'message' => $error];
        }
        $status = (($update['status'] ?? '') === 'updated' || ($update['status'] ?? '') === 'current') ? 'installed' : ($update['status'] ?? 'installed');
        help4_disk_usage_record_server_state($server, $status, [
            'plugin_version' => (string)($update['installed_version'] ?? $update['available_version'] ?? ''),
            'raw_summary' => json_encode($update),
        ], null);
        $message = help4_disk_usage_update_message($server, $update);
        help4_disk_usage_event($serverId, $action, 'success', $message, $result['output']);
        return ['status' => 'success', 'message' => $message];
    }

    help4_disk_usage_record_server_state($server, 'installed', null, null);
    help4_disk_usage_event($serverId, $action, 'success', ucfirst($action) . ' completed.', $result['output']);
    return ['status' => 'success', 'message' => ucfirst($action) . ' completed for ' . ($server->name ?: $server->hostname) . '.'];
}

function help4_disk_usage_command_for_action($action, $vars)
{
    $releaseUrl = $vars['releaseUrl'] ?? H4DU_DEFAULT_RELEASE_URL;
    $manifestUrl = $vars['updateManifestUrl'] ?? H4DU_DEFAULT_UPDATE_MANIFEST_URL;
    if ($action === 'deploy') {
        return help4_disk_usage_install_command($releaseUrl, $manifestUrl);
    }

    if ($action === 'update') {
        return help4_disk_usage_update_command($releaseUrl, $manifestUrl, true);
    }

    if ($action === 'sync') {
        $limit = max(0, (int)($vars['syncAccountLimit'] ?? 0));
        $maxSeconds = min(600, max(15, (int)($vars['scanMaxSeconds'] ?? 90)));
        $limitArg = $limit > 0 ? ' --account-limit ' . $limit : '';
        return '/usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-scan --scope all --max-seconds ' . $maxSeconds . ' --top 25 --write-cache --lock-dir /var/cpanel/help4-disk-usage/locks' . $limitArg;
    }

    return help4_disk_usage_update_command($releaseUrl, $manifestUrl, false);
}

function help4_disk_usage_install_command($releaseUrl, $manifestUrl = H4DU_DEFAULT_UPDATE_MANIFEST_URL)
{
    $safeManifestUrl = escapeshellarg($manifestUrl ?: H4DU_DEFAULT_UPDATE_MANIFEST_URL);
    return 'set -euo pipefail; tmp="$(mktemp -d /root/help4-disk-usage.XXXXXX)"; trap \'rm -rf "$tmp"\' EXIT; '
        . 'manifest_url=' . $safeManifestUrl . '; case "$manifest_url" in https://*) ;; *) echo "manifest URL must use HTTPS" >&2; exit 64;; esac; '
        . 'manifest_authority="${manifest_url#https://}"; manifest_authority="${manifest_authority%%/*}"; case "$manifest_authority" in ""|*@*) echo "manifest URL credentials are not allowed" >&2; exit 64;; esac; '
        . 'curl -fsSL --proto \'=https\' --proto-redir \'=https\' --tlsv1.2 --connect-timeout 15 --max-time 60 --max-filesize 1048576 -o "$tmp/update.json" "$manifest_url"; '
        . 'package_url="$(perl -MJSON::PP -0777 -e \'my $d=decode_json(<>); print $d->{package_url} || ""\' "$tmp/update.json")"; '
        . 'expected_sha="$(perl -MJSON::PP -0777 -e \'my $d=decode_json(<>); print lc($d->{sha256} || "")\' "$tmp/update.json")"; '
        . 'case "$package_url" in https://*) ;; *) echo "package URL must use HTTPS" >&2; exit 65;; esac; package_authority="${package_url#https://}"; package_authority="${package_authority%%/*}"; case "$package_authority" in ""|*@*) echo "package URL credentials are not allowed" >&2; exit 65;; esac; '
        . 'printf %s "$expected_sha" | grep -Eq \'^[0-9a-f]{64}$\' || { echo "manifest sha256 is missing or invalid" >&2; exit 66; }; '
        . 'curl -fsSL --proto \'=https\' --proto-redir \'=https\' --tlsv1.2 --connect-timeout 15 --max-time 120 --max-filesize 52428800 -o "$tmp/package.tar.gz" "$package_url"; '
        . 'actual_sha="$(sha256sum "$tmp/package.tar.gz" | awk \'{print $1}\')"; test "$actual_sha" = "$expected_sha" || { echo "package sha256 mismatch" >&2; exit 67; }; '
        . 'mkdir "$tmp/source"; tar --no-same-owner --no-same-permissions --strip-components=1 -xzf "$tmp/package.tar.gz" -C "$tmp/source"; '
        . 'test -x "$tmp/source/install.sh" && test -f "$tmp/source/src/bin/help4-disk-usage-scan" || { echo "invalid Help4 Disk Usage package" >&2; exit 68; }; '
        . 'HELP4_DU_RELEASE_URL="$package_url" HELP4_DU_UPDATE_MANIFEST_URL="$manifest_url" "$tmp/source/install.sh"';
}

function help4_disk_usage_update_command($releaseUrl, $manifestUrl, $apply)
{
    $safeUrl = escapeshellarg($releaseUrl ?: H4DU_DEFAULT_RELEASE_URL);
    $safeManifestUrl = escapeshellarg($manifestUrl ?: H4DU_DEFAULT_UPDATE_MANIFEST_URL);
    $mode = $apply ? '--apply' : '--check';
    $fallbackJson = escapeshellarg('{"ok":true,"status":"installed","installed_version":"","available_version":"","update_available":false}');
    $fallback = $apply
        ? help4_disk_usage_install_command($releaseUrl, $manifestUrl)
        : 'test -x /usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-scan && '
            . 'test -x /usr/local/cpanel/whostmgr/docroot/cgi/help4_disk_usage/index.cgi && '
            . 'test -x /usr/local/cpanel/base/frontend/jupiter/help4_disk_usage/index.live.pl && '
            . 'printf %s ' . $fallbackJson;
    return 'set -euo pipefail; if test -x /usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-update; then '
        . '/usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-update ' . $mode . ' --manifest-url ' . $safeManifestUrl . ' --release-url ' . $safeUrl . '; '
        . 'else '
        . $fallback . '; '
        . 'fi';
}

function help4_disk_usage_parse_update_json($output)
{
    $lines = preg_split('/\r?\n/', trim((string)$output));
    $lines = array_reverse($lines ?: []);
    foreach ($lines as $line) {
        $line = trim($line);
        if ($line === '' || $line[0] !== '{') {
            continue;
        }
        $data = json_decode($line, true);
        if (is_array($data)) {
            return $data;
        }
    }
    return ['ok' => false, 'status' => 'error', 'error' => 'updater did not return valid JSON'];
}

function help4_disk_usage_check_message($server, $check)
{
    $name = $server->name ?: $server->hostname;
    $installed = $check['installed_version'] ?? 'unknown';
    $available = $check['available_version'] ?? 'unknown';
    if (($check['status'] ?? '') === 'update_available') {
        return 'Update available for ' . $name . ': installed ' . $installed . ', available ' . $available . '.';
    }
    if (($check['status'] ?? '') === 'current') {
        return $name . ' is current at version ' . $installed . '.';
    }
    if (($check['status'] ?? '') === 'not_installed') {
        return $name . ' does not have Help4 Disk Usage installed. Use Deploy.';
    }
    return 'Check completed for ' . $name . '.';
}

function help4_disk_usage_update_message($server, $update)
{
    $name = $server->name ?: $server->hostname;
    if (($update['status'] ?? '') === 'updated') {
        return 'Updated ' . $name . ' to version ' . ($update['installed_version'] ?? 'unknown') . '.';
    }
    if (($update['status'] ?? '') === 'current') {
        return $name . ' is already current at version ' . ($update['installed_version'] ?? 'unknown') . '.';
    }
    return 'Update command completed for ' . $name . ' with status ' . ($update['status'] ?? 'unknown') . '.';
}

function help4_disk_usage_expected_fingerprint($server, $json)
{
    $map = json_decode((string)$json, true);
    if (!is_array($map)) {
        return '';
    }
    $keys = [
        (string)$server->id,
        (string)($server->hostname ?? ''),
        (string)($server->ipaddress ?? ''),
    ];
    foreach ($keys as $key) {
        if ($key !== '' && isset($map[$key]) && is_string($map[$key])) {
            return trim($map[$key]);
        }
    }
    return '';
}

function help4_disk_usage_fingerprint_matches($expected, $raw)
{
    if (!is_string($raw) || strlen($raw) !== 32) {
        return false;
    }
    $expected = trim((string)$expected);
    $openssh = 'SHA256:' . rtrim(base64_encode($raw), '=');
    if (strpos($expected, 'SHA256:') === 0) {
        return hash_equals($openssh, $expected);
    }
    $hex = strtolower(preg_replace('/[^0-9a-f]/i', '', $expected));
    return strlen($hex) === 64 && hash_equals(bin2hex($raw), $hex);
}

function help4_disk_usage_public_host_key_fingerprint_raw($publicKey)
{
    $publicKey = trim((string)$publicKey);
    if (!preg_match('/\A([A-Za-z0-9][A-Za-z0-9@._+-]{1,127})[ \t]+([A-Za-z0-9+\/]{20,}={0,2})\z/', $publicKey, $matches)) {
        return false;
    }
    $algorithm = $matches[1];
    if (!preg_match('/\A(?:ssh-|ecdsa-sha2-|sk-|rsa-sha2-)/', $algorithm)) {
        return false;
    }
    $blob = base64_decode($matches[2], true);
    if (!is_string($blob) || strlen($blob) < 8 || strlen($blob) > 16384) {
        return false;
    }
    $length = unpack('Nlength', substr($blob, 0, 4));
    $algorithmLength = (int)($length['length'] ?? 0);
    if ($algorithmLength < 1 || $algorithmLength > 128 || 4 + $algorithmLength > strlen($blob)) {
        return false;
    }
    $embeddedAlgorithm = substr($blob, 4, $algorithmLength);
    $algorithmMatches = hash_equals($embeddedAlgorithm, $algorithm)
        || (strpos($algorithm, 'rsa-sha2-') === 0 && $embeddedAlgorithm === 'ssh-rsa');
    if (!$algorithmMatches) {
        return false;
    }
    return hash('sha256', $blob, true);
}

function help4_disk_usage_ssh_exec($server, $command, $defaultPort, $expectedFingerprint = '', $allowUnpinned = false, $timeoutSeconds = 300)
{
    $host = $server->hostname ?: $server->ipaddress;
    $port = min(65535, max(1, (int)($defaultPort ?: 22)));
    $user = $server->username ?: 'root';
    $password = help4_disk_usage_decrypt((string)$server->password);

    if (!$host || !$password) {
        return ['ok' => false, 'error' => 'Missing host or decryptable server password in WHMCS server record.', 'output' => ''];
    }

    if (function_exists('ssh2_connect') && function_exists('ssh2_fingerprint')
        && defined('SSH2_FINGERPRINT_SHA256') && defined('SSH2_FINGERPRINT_RAW')) {
        return help4_disk_usage_native_ssh_exec(
            $host,
            $port,
            $user,
            $password,
            $command,
            $expectedFingerprint,
            $allowUnpinned,
            $timeoutSeconds
        );
    }

    foreach (['phpseclib3\\Net\\SSH2', 'phpseclib\\Net\\SSH2'] as $class) {
        if (class_exists($class)) {
            return help4_disk_usage_phpseclib_ssh_exec(
                $class,
                $host,
                $port,
                $user,
                $password,
                $command,
                $expectedFingerprint,
                $allowUnpinned,
                $timeoutSeconds
            );
        }
    }

    return ['ok' => false, 'error' => 'No supported SSH transport is available. Install PHP ssh2 or use a WHMCS runtime that provides phpseclib.', 'output' => ''];
}

function help4_disk_usage_native_ssh_exec($host, $port, $user, $password, $command, $expectedFingerprint, $allowUnpinned, $timeoutSeconds)
{
    $conn = @ssh2_connect($host, $port);
    if (!$conn) {
        return ['ok' => false, 'error' => 'Unable to connect to ' . $host . ':' . $port . '.', 'output' => ''];
    }

    $rawFingerprint = @ssh2_fingerprint($conn, SSH2_FINGERPRINT_SHA256 | SSH2_FINGERPRINT_RAW);
    $fingerprintError = help4_disk_usage_fingerprint_error($host, $expectedFingerprint, $allowUnpinned, $rawFingerprint);
    if ($fingerprintError !== '') {
        return ['ok' => false, 'error' => $fingerprintError, 'output' => ''];
    }

    if (!@ssh2_auth_password($conn, $user, $password)) {
        return ['ok' => false, 'error' => 'SSH authentication failed for ' . $user . '@' . $host . '.', 'output' => ''];
    }

    $wrapped = help4_disk_usage_wrapped_remote_command($command);
    if (!$wrapped) {
        return ['ok' => false, 'error' => 'Unable to create a remote execution marker.', 'output' => ''];
    }
    $stream = @ssh2_exec($conn, $wrapped['command'] . ' 2>&1');
    if (!$stream) {
        return ['ok' => false, 'error' => 'Unable to execute remote command.', 'output' => ''];
    }

    stream_set_blocking($stream, false);
    $timeoutSeconds = min(900, max(30, (int)$timeoutSeconds));
    $deadline = microtime(true) + $timeoutSeconds;
    $output = '';
    while (!feof($stream)) {
        if (microtime(true) >= $deadline) {
            fclose($stream);
            return ['ok' => false, 'error' => 'Remote command exceeded the ' . $timeoutSeconds . ' second safety limit.', 'output' => substr($output, -2000)];
        }
        $chunk = fread($stream, 8192);
        if ($chunk === false) {
            fclose($stream);
            return ['ok' => false, 'error' => 'Unable to read remote command output.', 'output' => $output];
        }
        if ($chunk !== '') {
            $output .= $chunk;
            if (strlen($output) > 16777216) {
                fclose($stream);
                return ['ok' => false, 'error' => 'Remote command output exceeded the 16 MiB safety limit.', 'output' => substr($output, -2000)];
            }
        } else {
            usleep(100000);
        }
    }
    fclose($stream);
    return help4_disk_usage_parse_remote_output($output, $wrapped['marker']);
}

function help4_disk_usage_phpseclib_ssh_exec($class, $host, $port, $user, $password, $command, $expectedFingerprint, $allowUnpinned, $timeoutSeconds)
{
    $timeoutSeconds = min(900, max(30, (int)$timeoutSeconds));
    try {
        $ssh = new $class($host, $port, $timeoutSeconds);
        $publicKey = @$ssh->getServerPublicHostKey();
    } catch (Throwable $e) {
        return ['ok' => false, 'error' => 'Unable to connect to ' . $host . ':' . $port . '.', 'output' => ''];
    }
    $rawFingerprint = help4_disk_usage_public_host_key_fingerprint_raw($publicKey);
    $fingerprintError = help4_disk_usage_fingerprint_error($host, $expectedFingerprint, $allowUnpinned, $rawFingerprint);
    if ($fingerprintError !== '') {
        return ['ok' => false, 'error' => $fingerprintError, 'output' => ''];
    }
    try {
        if (!@$ssh->login($user, $password)) {
            return ['ok' => false, 'error' => 'SSH authentication failed for ' . $user . '@' . $host . '.', 'output' => ''];
        }
        $ssh->setTimeout($timeoutSeconds);
    } catch (Throwable $e) {
        return ['ok' => false, 'error' => 'SSH authentication failed for ' . $user . '@' . $host . '.', 'output' => ''];
    }

    $wrapped = help4_disk_usage_wrapped_remote_command($command);
    if (!$wrapped) {
        return ['ok' => false, 'error' => 'Unable to create a remote execution marker.', 'output' => ''];
    }
    $output = '';
    $outputTooLarge = false;
    try {
        $result = $ssh->exec($wrapped['command'] . ' 2>&1', function ($chunk) use (&$output, &$outputTooLarge) {
            if (!is_string($chunk) || $chunk === '' || $outputTooLarge) {
                return;
            }
            $remaining = 16777216 - strlen($output);
            if (strlen($chunk) > $remaining) {
                $output .= substr($chunk, 0, max(0, $remaining));
                $outputTooLarge = true;
                return;
            }
            $output .= $chunk;
        });
    } catch (Throwable $e) {
        return ['ok' => false, 'error' => 'Unable to execute remote command.', 'output' => substr($output, -2000)];
    }
    if ($outputTooLarge) {
        return ['ok' => false, 'error' => 'Remote command output exceeded the 16 MiB safety limit.', 'output' => substr($output, -2000)];
    }
    if (method_exists($ssh, 'isTimeout') && $ssh->isTimeout()) {
        return ['ok' => false, 'error' => 'Remote command exceeded the ' . $timeoutSeconds . ' second safety limit.', 'output' => substr($output, -2000)];
    }
    if ($result === false && $output === '') {
        return ['ok' => false, 'error' => 'Unable to execute remote command.', 'output' => ''];
    }
    if (is_string($result) && $output === '') {
        $output = $result;
    }
    return help4_disk_usage_parse_remote_output($output, $wrapped['marker']);
}

function help4_disk_usage_fingerprint_error($host, $expectedFingerprint, $allowUnpinned, $rawFingerprint)
{
    $displayFingerprint = is_string($rawFingerprint) && strlen($rawFingerprint) === 32
        ? 'SHA256:' . rtrim(base64_encode($rawFingerprint), '=')
        : 'unavailable';
    if ($expectedFingerprint === '' && !$allowUnpinned) {
        return 'SSH host fingerprint is not configured for this server. Verify it out of band, then add ' . $displayFingerprint . ' to the module fingerprint map.';
    }
    if ($expectedFingerprint !== '' && !help4_disk_usage_fingerprint_matches($expectedFingerprint, $rawFingerprint)) {
        return 'SSH host fingerprint mismatch for ' . $host . '. Remote action was blocked before authentication.';
    }
    return '';
}

function help4_disk_usage_wrapped_remote_command($command)
{
    try {
        $marker = '__H4DU_EXIT_' . bin2hex(random_bytes(12)) . '__';
    } catch (Throwable $e) {
        return false;
    }
    $payload = 'set +e; ( ' . $command . ' ); rc=$?; printf "\\n' . $marker . ':%s\\n" "$rc"';
    return ['marker' => $marker, 'command' => 'bash -lc ' . escapeshellarg($payload)];
}

function help4_disk_usage_parse_remote_output($output, $marker)
{
    $pattern = '/(?:\r?\n)' . preg_quote($marker, '/') . ':(\d+)(?:\r?\n)?\z/';
    if (!preg_match($pattern, $output, $matches)) {
        return ['ok' => false, 'error' => 'Remote command ended without a verified exit status.', 'output' => trim((string)$output)];
    }
    $exitStatus = (int)$matches[1];
    $output = preg_replace($pattern, '', $output);
    $output = trim((string)$output);
    if ($exitStatus !== 0) {
        $tail = preg_replace('/[\x00-\x1F\x7F]+/', ' ', substr($output, -500));
        return ['ok' => false, 'error' => 'Remote command failed with exit status ' . $exitStatus . ($tail ? ': ' . $tail : '.'), 'output' => $output];
    }
    return ['ok' => true, 'output' => $output];
}

function help4_disk_usage_decrypt($value)
{
    if ($value === '') {
        return '';
    }
    if (function_exists('decrypt')) {
        try {
            return (string)decrypt($value);
        } catch (Throwable $e) {
            return '';
        }
    }
    return '';
}

function help4_disk_usage_save_scan_json($server, $json)
{
    $data = json_decode($json, true);
    if (!is_array($data) || !isset($data['accounts']) || !is_array($data['accounts'])) {
        throw new RuntimeException('Remote scan did not return valid Help4 Disk Usage JSON.');
    }

    $bad = 0;
    $check = 0;
    $saved = 0;

    foreach ($data['accounts'] as $account) {
        $username = (string)($account['user'] ?? '');
        if (!help4_disk_usage_valid_username($username)) {
            continue;
        }
        $severity = (string)($account['severity'] ?? 'unknown');
        $severity = help4_disk_usage_valid_severity($severity);
        $bad += $severity === 'bad' ? 1 : 0;
        $check += $severity === 'check' ? 1 : 0;
        $service = help4_disk_usage_find_service($server->id, $username);
        Capsule::table('mod_help4_disk_usage_accounts')->updateOrInsert(
            ['whmcs_server_id' => (int)$server->id, 'username' => $username],
            [
                'service_id' => $service ? (int)$service->id : null,
                'client_id' => $service ? (int)$service->userid : null,
                'domain' => $service ? (string)$service->domain : '',
                'owner' => (string)($account['owner'] ?? ''),
                'severity' => $severity,
                'disk_bytes' => (int)($account['disk_bytes'] ?? 0),
                'inode_count' => (int)($account['inode_count'] ?? 0),
                'scanned_at' => help4_disk_usage_mysql_datetime($account['scanned_at'] ?? null),
                'hints_json' => json_encode(help4_disk_usage_sanitize_text_list($account['remediation_hints'] ?? [])),
                'large_files_json' => json_encode(help4_disk_usage_sanitize_scan_items($account['large_files'] ?? [], ['relative_path', 'bytes', 'mtime'])),
                'hotspots_json' => json_encode(help4_disk_usage_sanitize_scan_items($account['category_hotspots'] ?? [], ['category', 'bytes', 'files', 'hint'])),
                'updated_at' => date('Y-m-d H:i:s'),
                'created_at' => date('Y-m-d H:i:s'),
            ]
        );
        $saved++;
    }

    $total = Capsule::table('mod_help4_disk_usage_accounts')->where('whmcs_server_id', (int)$server->id)->count();
    $totalBad = Capsule::table('mod_help4_disk_usage_accounts')->where('whmcs_server_id', (int)$server->id)->where('severity', 'bad')->count();
    $totalCheck = Capsule::table('mod_help4_disk_usage_accounts')->where('whmcs_server_id', (int)$server->id)->where('severity', 'check')->count();
    $syncStatus = !empty($data['scope_complete']) ? 'synced' : 'partial';

    help4_disk_usage_record_server_state($server, $syncStatus, [
        'last_scan_at' => help4_disk_usage_mysql_datetime($data['generated_at'] ?? null),
        'plugin_version' => (string)($data['version'] ?? ''),
        'account_count' => $total,
        'bad_count' => $totalBad,
        'check_count' => $totalCheck,
        'raw_summary' => json_encode([
            'host' => $data['host'] ?? '',
            'version' => $data['version'] ?? '',
            'generated_at' => $data['generated_at'] ?? '',
            'settings' => $data['settings'] ?? [],
            'scope_complete' => !empty($data['scope_complete']),
            'scope_account_count' => (int)($data['scope_account_count'] ?? $saved),
            'accounts_remaining' => (int)($data['accounts_remaining'] ?? 0),
            'batch_account_count' => $saved,
        ]),
    ], null);

    return ['accounts' => $saved, 'tracked' => $total, 'bad' => $totalBad, 'check' => $totalCheck, 'partial' => $syncStatus === 'partial'];
}

function help4_disk_usage_find_service($serverId, $username)
{
    return Capsule::table('tblhosting')
        ->select('id', 'userid', 'domain', 'username')
        ->where('server', (int)$serverId)
        ->where('username', $username)
        ->first();
}

function help4_disk_usage_valid_username($username)
{
    return is_string($username) && preg_match('/\A[A-Za-z0-9_.-]{1,128}\z/', $username);
}

function help4_disk_usage_valid_severity($severity)
{
    $severity = strtolower((string)$severity);
    return in_array($severity, ['bad', 'incomplete', 'check', 'good', 'unknown'], true) ? $severity : 'unknown';
}

function help4_disk_usage_sanitize_text_list($items)
{
    $out = [];
    foreach ((array)$items as $item) {
        if (!is_scalar($item)) {
            continue;
        }
        $text = trim((string)$item);
        if ($text === '') {
            continue;
        }
        $out[] = substr($text, 0, 500);
        if (count($out) >= 12) {
            break;
        }
    }
    return $out;
}

function help4_disk_usage_sanitize_scan_items($items, $allowedKeys)
{
    $out = [];
    foreach ((array)$items as $item) {
        if (!is_array($item)) {
            continue;
        }
        $row = [];
        foreach ($allowedKeys as $key) {
            if (!array_key_exists($key, $item)) {
                continue;
            }
            if (in_array($key, ['bytes', 'files'], true)) {
                $row[$key] = max(0, (int)$item[$key]);
            } else {
                $row[$key] = substr(trim((string)$item[$key]), 0, 500);
            }
        }
        if ($row) {
            $out[] = $row;
        }
        if (count($out) >= 25) {
            break;
        }
    }
    return $out;
}

function help4_disk_usage_record_server_state($server, $status, $extra = null, $error = null)
{
    $data = [
        'hostname' => (string)($server->hostname ?: $server->ipaddress),
        'status' => $status,
        'last_seen_at' => date('Y-m-d H:i:s'),
        'last_error' => $error,
        'updated_at' => date('Y-m-d H:i:s'),
    ];
    if (is_array($extra)) {
        $data = array_merge($data, $extra);
    }
    Capsule::table('mod_help4_disk_usage_servers')->updateOrInsert(
        ['whmcs_server_id' => (int)$server->id],
        array_merge($data, ['created_at' => date('Y-m-d H:i:s')])
    );
}

function help4_disk_usage_event($serverId, $type, $status, $message, $details)
{
    Capsule::table('mod_help4_disk_usage_events')->insert([
        'whmcs_server_id' => $serverId ?: null,
        'event_type' => $type,
        'status' => $status,
        'message' => substr((string)$message, 0, 60000),
        'details' => substr((string)$details, 0, 60000),
        'created_at' => date('Y-m-d H:i:s'),
        'updated_at' => date('Y-m-d H:i:s'),
    ]);
}

function help4_disk_usage_accounts_table($rows, $showClient)
{
    $html = '<table class="datatable h4du-table"><thead><tr><th>Account</th>';
    if ($showClient) {
        $html .= '<th>Client/Service</th>';
    }
    $html .= '<th>Status</th><th>Disk</th><th>Inodes</th><th>Last Scan</th><th>Support Hints</th></tr></thead><tbody>';
    foreach ($rows as $row) {
        $hints = json_decode($row->hints_json ?? '[]', true) ?: [];
        $html .= '<tr><td><strong>' . help4_disk_usage_e($row->username) . '</strong><br><span class="h4du-muted">' . help4_disk_usage_e($row->domain ?: 'no domain mapped') . '</span></td>';
        if ($showClient) {
            $html .= '<td>' . ($row->client_id ? 'Client #' . (int)$row->client_id . '<br>Service #' . (int)$row->service_id : '<span class="h4du-muted">not mapped</span>') . '</td>';
        }
        $html .= '<td>' . help4_disk_usage_badge($row->severity) . '</td>';
        $html .= '<td>' . help4_disk_usage_e(help4_disk_usage_bytes((int)$row->disk_bytes)) . '</td>';
        $html .= '<td>' . number_format((int)$row->inode_count) . '</td>';
        $html .= '<td>' . help4_disk_usage_e($row->scanned_at ?: 'unknown') . '</td>';
        $html .= '<td>' . help4_disk_usage_e(implode(' ', array_slice($hints, 0, 2))) . '</td></tr>';
    }
    if (count($rows) === 0) {
        $html .= '<tr><td colspan="' . ($showClient ? 7 : 6) . '">No synced account reports yet.</td></tr>';
    }
    return $html . '</tbody></table>';
}

function help4_disk_usage_server_action_form($moduleLink, $serverId, $action, $label, $returnView = 'servers')
{
    $safeView = preg_replace('/[^a-z0-9_-]/i', '', (string)$returnView) ?: 'servers';
    return '<form method="post" action="' . help4_disk_usage_e($moduleLink) . '&view=' . help4_disk_usage_e($safeView) . '" class="h4du-inline">'
        . help4_disk_usage_token_field()
        . '<input type="hidden" name="h4du_action" value="' . help4_disk_usage_e($action) . '">'
        . '<input type="hidden" name="server_id" value="' . (int)$serverId . '">'
        . '<button class="btn btn-default btn-sm" type="submit">' . help4_disk_usage_e($label) . '</button>'
        . '</form>';
}

function help4_disk_usage_tabs($moduleLink, $active)
{
    $tabs = [
        'dashboard' => 'Dashboard',
        'health' => 'Server Health',
        'servers' => 'Servers & Deploy',
        'accounts' => 'Customer Reports',
        'events' => 'Events',
    ];
    $html = '<ul class="nav nav-tabs h4du-tabs">';
    foreach ($tabs as $key => $label) {
        $class = ($active === $key || ($active === '' && $key === 'dashboard')) ? ' class="active"' : '';
        $html .= '<li' . $class . '><a href="' . help4_disk_usage_e($moduleLink) . '&view=' . help4_disk_usage_e($key) . '">' . help4_disk_usage_e($label) . '</a></li>';
    }
    return $html . '</ul>';
}

function help4_disk_usage_metric($label, $value)
{
    return '<div><strong>' . help4_disk_usage_e((string)$value) . '</strong><span>' . help4_disk_usage_e($label) . '</span></div>';
}

function help4_disk_usage_badge($status)
{
    $safe = preg_replace('/[^a-z0-9_-]/i', '', (string)$status) ?: 'unknown';
    return '<span class="h4du-badge h4du-' . help4_disk_usage_e($safe) . '">' . help4_disk_usage_e($status ?: 'unknown') . '</span>';
}

function help4_disk_usage_notice($status, $message)
{
    $class = $status === 'success' ? 'successbox' : ($status === 'error' ? 'errorbox' : 'infobox');
    return '<div class="' . $class . '">' . help4_disk_usage_e($message) . '</div>';
}

function help4_disk_usage_token_field()
{
    if (function_exists('generate_token')) {
        return generate_token('plain');
    }
    return '';
}

function help4_disk_usage_check_token()
{
    if (!function_exists('check_token')) {
        return false;
    }
    check_token('WHMCS.admin.default');
    return true;
}

function help4_disk_usage_mysql_datetime($value)
{
    if (!$value) {
        return null;
    }
    $ts = strtotime($value);
    return $ts ? date('Y-m-d H:i:s', $ts) : null;
}

function help4_disk_usage_display_name($vars)
{
    return help4_disk_usage_clean_label($vars['displayName'] ?? 'Disk Usage Audit', 'Disk Usage Audit', 80);
}

function help4_disk_usage_credit_prefix($vars)
{
    return help4_disk_usage_clean_label($vars['creditPrefix'] ?? 'Built by', 'Built by', 40);
}

function help4_disk_usage_credit_html($vars)
{
    return '<div class="h4du-credit">' . help4_disk_usage_e(help4_disk_usage_credit_prefix($vars))
        . ' <a href="https://help4network.com/" target="_blank" rel="noopener">Help4 Network</a></div>';
}

function help4_disk_usage_clean_label($value, $default, $maxLength)
{
    $value = trim((string)$value);
    $value = preg_replace('/[\r\n\t ]+/', ' ', $value);
    $value = preg_replace('/[^A-Za-z0-9_ .:()\/+-]/', '', $value);
    if ($value === '') {
        $value = $default;
    }
    return substr($value, 0, $maxLength);
}

function help4_disk_usage_bytes($bytes)
{
    $units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    $value = max(0, $bytes);
    foreach ($units as $unit) {
        if ($value < 1024 || $unit === 'PB') {
            return sprintf('%.1f %s', $value, $unit);
        }
        $value /= 1024;
    }
}

function help4_disk_usage_e($value)
{
    return htmlspecialchars((string)$value, ENT_QUOTES, 'UTF-8');
}

function help4_disk_usage_admin_css()
{
    return '<style>
    .h4du-wrap{max-width:1280px}.h4du-muted{color:#687386}.h4du-tabs{margin:18px 0}.h4du-metrics{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:10px;margin:16px 0}
    .h4du-metrics div{border:1px solid #d9dee7;background:#fff;border-radius:4px;padding:12px}.h4du-metrics strong{display:block;font-size:22px}.h4du-metrics span{color:#687386}
    .h4du-table td,.h4du-table th{vertical-align:top}.h4du-inline{display:inline-block;margin:0 2px 4px 0}.h4du-pre{white-space:pre-wrap;background:#f6f7f9;border:1px solid #d9dee7;padding:12px;border-radius:4px}
    .h4du-badge{display:inline-block;padding:3px 8px;border-radius:99px;font-weight:700;text-transform:uppercase;background:#e8ebf0}.h4du-good,.h4du-installed,.h4du-synced,.h4du-success,.h4du-healthy{background:#dff8e8;color:#075e2a}
    .h4du-check,.h4du-attention,.h4du-stale,.h4du-not_synced,.h4du-not_checked,.h4du-update_available{background:#fff1c2;color:#774400}.h4du-bad,.h4du-error{background:#ffd9d4;color:#7a1e16}.h4du-incomplete{background:#f0dcff;color:#5b356d}.h4du-disabled{background:#e8ebf0;color:#687386}.h4du-credit{margin-top:28px;color:#687386;font-size:12px;text-align:right}.h4du-credit a{color:inherit;text-decoration:underline;text-underline-offset:2px}
    </style>';
}
