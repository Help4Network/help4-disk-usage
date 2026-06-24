<?php

if (!defined('WHMCS')) {
    die('This file cannot be accessed directly');
}

use WHMCS\Database\Capsule;

const H4DU_VERSION = '0.2.2';
const H4DU_DEFAULT_RELEASE_URL = 'https://github.com/Help4Network/help4-disk-usage/archive/refs/heads/main.tar.gz';

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
                'Description' => 'URL WHMCS will ask cPanel servers to download during SSH deployment.',
            ],
            'sshPort' => [
                'FriendlyName' => 'Default SSH Port',
                'Type' => 'text',
                'Size' => '8',
                'Default' => '22',
            ],
            'syncAccountLimit' => [
                'FriendlyName' => 'Sync Account Limit',
                'Type' => 'text',
                'Size' => '8',
                'Default' => '0',
                'Description' => '0 means scan all accounts. Use a small number during first rollout.',
            ],
            'scanMaxSeconds' => [
                'FriendlyName' => 'Per-Account Scan Max Seconds',
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
            'creditText' => [
                'FriendlyName' => 'Footer Credit',
                'Type' => 'text',
                'Size' => '90',
                'Default' => 'Help4 Disk Usage by Help4 Network',
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
    $action = $_POST['h4du_action'] ?? $_GET['view'] ?? 'dashboard';
    $message = null;

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        help4_disk_usage_check_token();
        $serverId = (int)($_POST['server_id'] ?? 0);
        if ($action === 'check_server') {
            $message = help4_disk_usage_check_server($serverId, $vars);
        } elseif ($action === 'deploy_server') {
            $message = help4_disk_usage_deploy_server($serverId, $vars);
        } elseif ($action === 'sync_server') {
            $message = help4_disk_usage_sync_server($serverId, $vars);
        }
    }

    echo help4_disk_usage_admin_css();
    echo '<div class="h4du-wrap">';
    echo '<h1>Help4 Disk Usage</h1>';
    echo '<p class="h4du-muted">WHMCS deployment and support reporting for cPanel/WHM disk and inode scans.</p>';
    echo help4_disk_usage_tabs($moduleLink, $action);
    if ($message) {
        echo help4_disk_usage_notice($message['status'], $message['message']);
    }

    if ($action === 'servers') {
        echo help4_disk_usage_servers_page($moduleLink, $vars);
    } elseif ($action === 'accounts') {
        echo help4_disk_usage_accounts_page($moduleLink);
    } elseif ($action === 'events') {
        echo help4_disk_usage_events_page();
    } else {
        echo help4_disk_usage_dashboard_page($moduleLink, $vars);
    }

    echo '<div class="h4du-credit">' . help4_disk_usage_e($vars['creditText'] ?: 'Help4 Disk Usage by Help4 Network') . '</div>';
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
            'vars' => ['accounts' => [], 'disabled' => true, 'creditText' => $vars['creditText'] ?? 'Help4 Disk Usage by Help4 Network'],
        ];
    }

    $clientId = (int)($_SESSION['uid'] ?? 0);
    $accounts = Capsule::table('mod_help4_disk_usage_accounts')
        ->where('client_id', $clientId)
        ->orderBy('severity', 'asc')
        ->orderBy('disk_bytes', 'desc')
        ->get();
    $accountRows = json_decode(json_encode($accounts), true);
    foreach ($accountRows as &$accountRow) {
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
            'creditText' => $vars['creditText'] ?? 'Help4 Disk Usage by Help4 Network',
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

    $html .= '<h2>Top Disk Offenders</h2>';
    $html .= help4_disk_usage_accounts_table($top, false);
    $html .= '<p><a class="btn btn-primary" href="' . help4_disk_usage_e($moduleLink) . '&view=servers">Deploy or sync servers</a></p>';

    return $html;
}

function help4_disk_usage_servers_page($moduleLink, $vars)
{
    $servers = Capsule::table('tblservers')
        ->select('id', 'name', 'hostname', 'ipaddress', 'type', 'username', 'disabled')
        ->whereIn('type', ['cpanel', 'cpanelExtended', 'whm'])
        ->orWhere('type', 'like', '%cpanel%')
        ->orderBy('name')
        ->get();

    $html = '<h2>cPanel/WHM Servers</h2>';
    $html .= '<p class="h4du-muted">Check verifies installed files. Deploy installs the plugin over SSH when PHP ssh2 and WHMCS server credentials are available. Sync runs a bounded scan and stores customer-facing summaries.</p>';
    $html .= '<table class="datatable h4du-table"><thead><tr><th>Server</th><th>Host</th><th>Module</th><th>Status</th><th>Last Scan</th><th>Counts</th><th>Actions</th></tr></thead><tbody>';

    foreach ($servers as $server) {
        $state = Capsule::table('mod_help4_disk_usage_servers')->where('whmcs_server_id', $server->id)->first();
        $html .= '<tr>';
        $html .= '<td><strong>' . help4_disk_usage_e($server->name) . '</strong><br><span class="h4du-muted">ID ' . (int)$server->id . '</span></td>';
        $html .= '<td>' . help4_disk_usage_e($server->hostname ?: $server->ipaddress) . '</td>';
        $html .= '<td>' . help4_disk_usage_e($server->type) . '</td>';
        $html .= '<td>' . help4_disk_usage_badge($state->status ?? 'unknown') . '</td>';
        $html .= '<td>' . help4_disk_usage_e($state->last_scan_at ?? 'never') . '</td>';
        $html .= '<td>' . (int)($state->account_count ?? 0) . ' accounts<br>' . (int)($state->bad_count ?? 0) . ' bad / ' . (int)($state->check_count ?? 0) . ' check</td>';
        $html .= '<td>' . help4_disk_usage_server_action_form($moduleLink, $server->id, 'check_server', 'Check') . ' '
            . help4_disk_usage_server_action_form($moduleLink, $server->id, 'deploy_server', 'Deploy') . ' '
            . help4_disk_usage_server_action_form($moduleLink, $server->id, 'sync_server', 'Sync') . '</td>';
        $html .= '</tr>';
    }

    $html .= '</tbody></table>';
    $html .= '<h3>Manual Deployment Command</h3>';
    $html .= '<pre class="h4du-pre">' . help4_disk_usage_e(help4_disk_usage_install_command($vars['releaseUrl'] ?? H4DU_DEFAULT_RELEASE_URL)) . '</pre>';
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

function help4_disk_usage_sync_server($serverId, $vars)
{
    return help4_disk_usage_server_ssh_action($serverId, 'sync', $vars);
}

function help4_disk_usage_server_ssh_action($serverId, $action, $vars)
{
    $server = Capsule::table('tblservers')->where('id', $serverId)->first();
    if (!$server) {
        return ['status' => 'error', 'message' => 'Server not found.'];
    }

    $command = help4_disk_usage_command_for_action($action, $vars);
    $result = help4_disk_usage_ssh_exec($server, $command, (int)($vars['sshPort'] ?? 22));

    if (!$result['ok']) {
        help4_disk_usage_record_server_state($server, 'error', null, $result['error']);
        help4_disk_usage_event($serverId, $action, 'error', $result['error'], $result['output'] ?? '');
        return ['status' => 'error', 'message' => $result['error']];
    }

    if ($action === 'sync') {
        $saved = help4_disk_usage_save_scan_json($server, $result['output']);
        help4_disk_usage_event($serverId, $action, 'success', 'Synced ' . $saved['accounts'] . ' account scan records.', '');
        return ['status' => 'success', 'message' => 'Synced ' . $saved['accounts'] . ' account scan records from ' . ($server->name ?: $server->hostname) . '.'];
    }

    help4_disk_usage_record_server_state($server, 'installed', null, null);
    help4_disk_usage_event($serverId, $action, 'success', ucfirst($action) . ' completed.', $result['output']);
    return ['status' => 'success', 'message' => ucfirst($action) . ' completed for ' . ($server->name ?: $server->hostname) . '.'];
}

function help4_disk_usage_command_for_action($action, $vars)
{
    if ($action === 'deploy') {
        return help4_disk_usage_install_command($vars['releaseUrl'] ?? H4DU_DEFAULT_RELEASE_URL);
    }

    if ($action === 'sync') {
        $limit = max(0, (int)($vars['syncAccountLimit'] ?? 0));
        $maxSeconds = max(15, (int)($vars['scanMaxSeconds'] ?? 90));
        $limitArg = $limit > 0 ? ' --account-limit ' . $limit : '';
        return '/usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-scan --scope all --max-seconds ' . $maxSeconds . ' --top 25 --write-cache' . $limitArg;
    }

    return 'test -x /usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-scan && '
        . 'test -x /usr/local/cpanel/whostmgr/docroot/cgi/help4_disk_usage/index.cgi && '
        . 'test -x /usr/local/cpanel/base/frontend/jupiter/help4_disk_usage/index.live.pl && '
        . 'echo help4_disk_usage_installed';
}

function help4_disk_usage_install_command($releaseUrl)
{
    $safeUrl = escapeshellarg($releaseUrl ?: H4DU_DEFAULT_RELEASE_URL);
    return 'set -euo pipefail; tmp="$(mktemp -d /root/help4-disk-usage.XXXXXX)"; '
        . 'cd "$tmp"; curl -fsSL -o help4-disk-usage.tar.gz ' . $safeUrl . '; '
        . 'tar -xzf help4-disk-usage.tar.gz; cd help4-disk-usage-*; ./install.sh';
}

function help4_disk_usage_ssh_exec($server, $command, $defaultPort)
{
    if (!function_exists('ssh2_connect')) {
        return ['ok' => false, 'error' => 'PHP ssh2 extension is not installed. Use the manual deployment command or install ssh2 for one-click WHMCS deployment.', 'output' => ''];
    }

    $host = $server->hostname ?: $server->ipaddress;
    $port = (int)($server->port ?: $defaultPort ?: 22);
    $user = $server->username ?: 'root';
    $password = help4_disk_usage_decrypt((string)$server->password);

    if (!$host || !$password) {
        return ['ok' => false, 'error' => 'Missing host or decryptable server password in WHMCS server record.', 'output' => ''];
    }

    $conn = @ssh2_connect($host, $port);
    if (!$conn) {
        return ['ok' => false, 'error' => 'Unable to connect to ' . $host . ':' . $port . '.', 'output' => ''];
    }

    if (!@ssh2_auth_password($conn, $user, $password)) {
        return ['ok' => false, 'error' => 'SSH authentication failed for ' . $user . '@' . $host . '.', 'output' => ''];
    }

    $stream = @ssh2_exec($conn, $command . ' 2>&1');
    if (!$stream) {
        return ['ok' => false, 'error' => 'Unable to execute remote command.', 'output' => ''];
    }

    stream_set_blocking($stream, true);
    $output = stream_get_contents($stream);
    fclose($stream);
    return ['ok' => true, 'output' => trim((string)$output)];
}

function help4_disk_usage_decrypt($value)
{
    if ($value === '') {
        return '';
    }
    if (function_exists('decrypt')) {
        return (string)decrypt($value);
    }
    return $value;
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
        if ($username === '') {
            continue;
        }
        $severity = (string)($account['severity'] ?? 'unknown');
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
                'hints_json' => json_encode($account['remediation_hints'] ?? []),
                'large_files_json' => json_encode($account['large_files'] ?? []),
                'hotspots_json' => json_encode($account['category_hotspots'] ?? []),
                'updated_at' => date('Y-m-d H:i:s'),
                'created_at' => date('Y-m-d H:i:s'),
            ]
        );
        $saved++;
    }

    help4_disk_usage_record_server_state($server, 'synced', [
        'last_scan_at' => help4_disk_usage_mysql_datetime($data['generated_at'] ?? null),
        'account_count' => $saved,
        'bad_count' => $bad,
        'check_count' => $check,
        'raw_summary' => json_encode([
            'host' => $data['host'] ?? '',
            'version' => $data['version'] ?? '',
            'generated_at' => $data['generated_at'] ?? '',
            'settings' => $data['settings'] ?? [],
        ]),
    ], null);

    return ['accounts' => $saved, 'bad' => $bad, 'check' => $check];
}

function help4_disk_usage_find_service($serverId, $username)
{
    return Capsule::table('tblhosting')
        ->select('id', 'userid', 'domain', 'username')
        ->where('server', (int)$serverId)
        ->where('username', $username)
        ->first();
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
        'message' => $message,
        'details' => $details,
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

function help4_disk_usage_server_action_form($moduleLink, $serverId, $action, $label)
{
    return '<form method="post" action="' . help4_disk_usage_e($moduleLink) . '&view=servers" class="h4du-inline">'
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
    if (function_exists('check_token')) {
        check_token('WHMCS.admin.default');
    }
}

function help4_disk_usage_mysql_datetime($value)
{
    if (!$value) {
        return null;
    }
    $ts = strtotime($value);
    return $ts ? date('Y-m-d H:i:s', $ts) : null;
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
    .h4du-badge{display:inline-block;padding:3px 8px;border-radius:99px;font-weight:700;text-transform:uppercase;background:#e8ebf0}.h4du-good,.h4du-installed,.h4du-synced,.h4du-success{background:#dff8e8;color:#075e2a}
    .h4du-check{background:#fff1c2;color:#774400}.h4du-bad,.h4du-error{background:#ffd9d4;color:#7a1e16}.h4du-incomplete{background:#f0dcff;color:#5b356d}.h4du-credit{margin-top:28px;color:#687386;font-size:12px;text-align:right}
    </style>';
}
