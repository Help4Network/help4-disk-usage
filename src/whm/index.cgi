#!/usr/bin/env perl
use strict;
use warnings;
use File::Spec;
use File::Path qw(make_path);
use JSON::PP qw(decode_json);
use POSIX qw(strftime);

my $APP = 'Help4 Disk Usage';
my $DEFAULT_MANIFEST_URL = 'https://raw.githubusercontent.com/Help4Network/help4-disk-usage/main/update.json';
my $CACHE_DIR = $ENV{HELP4_DU_CACHE_DIR} || '/var/cpanel/help4-disk-usage';
my $SCANNER = $ENV{HELP4_DU_SCANNER} || '/usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-scan';
my $UPDATER = $ENV{HELP4_DU_UPDATER} || '/usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-update';
my $CONFIG_FILE = $ENV{HELP4_DU_CONFIG} || File::Spec->catfile($CACHE_DIR, 'config.json');
my %q = parse_query($ENV{QUERY_STRING} || '');
my $auth_user = $ENV{REMOTE_USER} || $ENV{USER} || '';
$auth_user =~ s/[^A-Za-z0-9_.-]//g;
my $config = load_config();
my $update_status;

my $notice = '';
my $is_root = $auth_user eq 'root' || $> == 0 && !$auth_user;
my %owned = map { $_ => 1 } owned_accounts($auth_user);
$owned{$auth_user} = 1 if $auth_user && !$is_root;

if ($q{save_settings} && $is_root) {
    $notice = save_settings(\%q, $config);
    $config = load_config();
}

if ($q{update_check} && $is_root) {
    $update_status = run_update('check', $config);
}

if ($q{update_apply} && $is_root) {
    $update_status = run_update('apply', $config);
    if ($update_status->{ok} && ($update_status->{status} || '') eq 'updated') {
        $notice = 'Update applied to version ' . ($update_status->{installed_version} || 'unknown') . '. Backup: ' . ($update_status->{backup} || 'see install output');
    } elsif ($update_status->{ok}) {
        $notice = 'Update check completed: ' . ($update_status->{status} || 'unknown') . '.';
    } else {
        $notice = 'Update failed: ' . ($update_status->{error} || 'unknown error');
    }
}

if ($q{refresh}) {
    my @cmd = ($SCANNER, '--write-cache', '--quiet', '--lock-dir', $config->{scan_lock_dir}, '--max-seconds', $config->{whm_scan_max_seconds});
    if ($q{account}) {
        my $account = clean_user($q{account});
        if ($account && ($is_root || $owned{$account})) {
            push @cmd, ('--scope', 'account', '--account', $account);
        } else {
            $notice = 'Refresh denied for that account.';
        }
    } elsif ($is_root) {
        push @cmd, ('--scope', 'all');
    } elsif ($auth_user) {
        push @cmd, ('--scope', 'owner', '--owner', $auth_user);
    }
    if (!$notice) {
        local $ENV{HELP4_DU_LOCK_DIR} = $config->{scan_lock_dir};
        system(@cmd);
        $notice = $? == 0 ? 'Scan refreshed. Review the timestamps below.' : 'Scan is already running or returned a non-zero status; existing cache is shown.';
    }
}

my @accounts = grep { allowed($_, $is_root, \%owned) } read_account_caches();
@accounts = sort {
    severity_rank($b->{severity}) <=> severity_rank($a->{severity})
    || ($b->{disk_bytes} || 0) <=> ($a->{disk_bytes} || 0)
    || ($a->{user} || '') cmp ($b->{user} || '')
} @accounts;

print "Content-Type: text/html; charset=utf-8\r\n\r\n";
print page(\@accounts, $notice, $auth_user, $is_root, $config, $update_status);

sub page {
    my ($accounts, $notice, $auth_user, $is_root, $config, $update_status) = @_;
    my $total_bytes = 0;
    my $total_inodes = 0;
    my %sev;
    for my $a (@$accounts) {
        $total_bytes += $a->{disk_bytes} || 0;
        $total_inodes += $a->{inode_count} || 0;
        $sev{$a->{severity} || 'unknown'}++;
    }
    my $display_name = h($config->{display_name} || $APP);
    my $scope = $is_root ? 'Root view: all accounts' : 'Reseller view: owned accounts only';
    my $rows = join '', map { account_row($_, $is_root) } @$accounts;
    $rows ||= '<tr><td colspan="8" class="muted">No scan cache exists yet. Run a refresh to collect data.</td></tr>';
    my $refresh_all = $is_root ? '<a class="button" href="?refresh=1">Refresh all accounts</a>' : '<a class="button" href="?refresh=1">Refresh owned accounts</a>';
    my $notice_html = $notice ? '<div class="notice">' . h($notice) . '</div>' : '';
    my $settings = $is_root ? settings_panel($config) : '';
    my $updates = $is_root ? update_panel($config, $update_status) : '';
    return <<"HTML";
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>$display_name</title>
  <link rel="stylesheet" href="/help4-disk-usage/help4-disk-usage.css">
</head>
<body>
  <main class="wrap">
    <header class="topbar">
      <div>
        <h1>$display_name</h1>
        <p class="muted">$scope. Signed in as @{[h($auth_user || 'unknown')]}.</p>
      </div>
      <div class="actions">$refresh_all</div>
    </header>
    $notice_html
    <section class="metrics">
      <div><strong>@{[scalar @$accounts]}</strong><span>Visible accounts</span></div>
      <div><strong>@{[fmt_bytes($total_bytes)]}</strong><span>Indexed file bytes</span></div>
      <div><strong>@{[fmt_int($total_inodes)]}</strong><span>Indexed inodes</span></div>
      <div><strong>@{[fmt_int($sev{bad} || 0)]}</strong><span>Bad accounts</span></div>
      <div><strong>@{[fmt_int($sev{incomplete} || 0)]}</strong><span>Incomplete scans</span></div>
    </section>
    <section>
      <h2>Actionable Offenders</h2>
      <table>
        <thead>
          <tr>
            <th>Account</th><th>Owner</th><th>Status</th><th>Disk</th><th>Inodes</th><th>Last scan</th><th>Top issue</th><th></th>
          </tr>
        </thead>
        <tbody>$rows</tbody>
      </table>
    </section>
    $settings
    $updates
    @{[credit_html($config)]}
  </main>
</body>
</html>
HTML
}

sub settings_panel {
    my ($cfg) = @_;
    my $overrides = JSON::PP->new->canonical->pretty->encode($cfg->{package_overrides} || {});
    return <<"HTML";
    <section>
      <h2>Scan Limits</h2>
      <form method="get" class="settings-grid">
        <input type="hidden" name="save_settings" value="1">
        <label>WHM scan max seconds<input name="whm_scan_max_seconds" value="@{[h($cfg->{whm_scan_max_seconds})]}"></label>
        <label>cPanel refreshes per hour<input name="cpanel_refreshes_per_hour" value="@{[h($cfg->{cpanel_refreshes_per_hour})]}"></label>
        <label>cPanel min interval seconds<input name="cpanel_min_interval_seconds" value="@{[h($cfg->{cpanel_min_interval_seconds})]}"></label>
        <label>cPanel scan max seconds<input name="cpanel_scan_max_seconds" value="@{[h($cfg->{cpanel_scan_max_seconds})]}"></label>
        <label>Display name<input name="display_name" value="@{[h($cfg->{display_name})]}"></label>
        <label>Footer prefix<input name="credit_prefix" value="@{[h($cfg->{credit_prefix})]}"></label>
        <label class="wide">Release tarball URL<input name="release_url" value="@{[h($cfg->{release_url})]}"></label>
        <label class="wide">Update manifest URL<input name="update_manifest_url" value="@{[h($cfg->{update_manifest_url})]}"></label>
        <label class="wide">Shared scan lock directory<input name="scan_lock_dir" value="@{[h($cfg->{scan_lock_dir})]}"></label>
        <label class="wide">Package overrides JSON<textarea name="package_overrides_json" rows="8">@{[h($overrides)]}</textarea></label>
        <div class="wide"><button class="button" type="submit">Save limits</button></div>
      </form>
      <p class="muted">All foreground scans use the shared lock, so only one scan runs at a time. cPanel user refreshes are also throttled by account and can be overridden by package name. Display name and footer prefix can be customized, but the Help4 Network builder credit link remains visible.</p>
    </section>
HTML
}

sub update_panel {
    my ($cfg, $status) = @_;
    my $current = current_version();
    my $status_html = '<p class="muted">Click check to compare this server with the configured release tarball.</p>';
    if ($status) {
        my $badge = $status->{status} || 'unknown';
        my $err = $status->{error} ? '<br>Error: ' . h($status->{error}) : '';
        my $backup = $status->{backup} ? '<br>Backup: ' . h($status->{backup}) : '';
        $status_html = '<p><strong>Status:</strong> <span class="pill ' . h($badge) . '">' . h($badge) . '</span>'
            . '<br>Installed: ' . h($status->{installed_version} || $current || 'unknown')
            . '<br>Available: ' . h($status->{available_version} || 'unknown')
            . '<br>Manifest: ' . h($status->{manifest_url} || $cfg->{update_manifest_url} || '')
            . '<br>Package: ' . h($status->{release_url} || $cfg->{release_url} || '')
            . $err . $backup . '</p>';
    }
    return <<"HTML";
    <section>
      <h2>Repository Updates</h2>
      $status_html
      <p class="muted">Updates read the configured manifest when available, download the selected release tarball, compare versions, run the normal backup-first installer, and preserve scan cache/config. Use this after publishing a new release or changing update channels.</p>
      <p>
        <a class="button" href="?update_check=1">Check for update</a>
        <a class="button" href="?update_apply=1">Apply update</a>
      </p>
    </section>
HTML
}

sub account_row {
    my ($a, $is_root) = @_;
    my $issue = top_issue($a);
    my $home = $is_root ? '<div class="path">' . h($a->{home} || '') . '</div>' : '';
    return '<tr>' .
        '<td><strong>' . h($a->{user}) . '</strong>' . $home . '</td>' .
        '<td>' . h($a->{owner} || '') . '</td>' .
        '<td><span class="pill ' . h($a->{severity} || 'unknown') . '">' . h($a->{severity} || 'unknown') . '</span></td>' .
        '<td>' . fmt_bytes($a->{disk_bytes} || 0) . '</td>' .
        '<td>' . fmt_int($a->{inode_count} || 0) . '</td>' .
        '<td>' . h($a->{scanned_at} || 'never') . '</td>' .
        '<td>' . $issue . '</td>' .
        '<td><a class="button small" href="?refresh=1&account=' . h($a->{user}) . '">Rescan</a></td>' .
        '</tr>';
}

sub top_issue {
    my ($a) = @_;
    my @bits;
    if ($a->{category_hotspots} && @{$a->{category_hotspots}}) {
        my $h = $a->{category_hotspots}[0];
        push @bits, h($h->{category}) . ': ' . fmt_bytes($h->{bytes} || 0) . ', ' . fmt_int($h->{files} || 0) . ' files';
    }
    if ($a->{large_files} && @{$a->{large_files}}) {
        my $f = $a->{large_files}[0];
        push @bits, 'largest: ' . fmt_bytes($f->{bytes} || 0) . ' ' . h($f->{relative_path} || '');
    }
    if ($a->{growth} && $a->{growth}{has_previous} && ($a->{growth}{bytes_delta} || 0) > 0) {
        push @bits, 'growth: +' . fmt_bytes($a->{growth}{bytes_delta});
    }
    return @bits ? join('<br>', @bits[0 .. (@bits > 2 ? 1 : $#bits)]) : '<span class="muted">No major offender in cache</span>';
}

sub read_account_caches {
    my $dir = File::Spec->catdir($CACHE_DIR, 'accounts');
    return unless -d $dir;
    opendir my $dh, $dir or return;
    my @out;
    while (defined(my $file = readdir $dh)) {
        next unless $file =~ /\A[A-Za-z0-9_.-]+\.json\z/;
        (my $cache_user = $file) =~ s/\.json\z//;
        my $path = File::Spec->catfile($dir, $file);
        open my $fh, '<', $path or next;
        local $/;
        my $data = eval { decode_json(<$fh>) };
        next unless $data && ref $data eq 'HASH';
        next unless ($data->{user} || '') eq $cache_user;
        push @out, $data if $data && ref $data eq 'HASH';
    }
    return @out;
}

sub default_config {
    return {
        scan_lock_dir                 => File::Spec->catdir($CACHE_DIR, 'locks'),
        display_name                  => 'Disk Usage Audit',
        credit_prefix                 => 'Built by',
        release_url                   => 'https://github.com/Help4Network/help4-disk-usage/archive/refs/heads/main.tar.gz',
        update_manifest_url           => $DEFAULT_MANIFEST_URL,
        whm_scan_max_seconds          => 90,
        cpanel_refreshes_per_hour     => 3,
        cpanel_min_interval_seconds   => 300,
        cpanel_scan_max_seconds       => 60,
        package_overrides             => {},
    };
}

sub load_config {
    my $cfg = default_config();
    my $disk = read_json_file($CONFIG_FILE);
    if ($disk && ref $disk eq 'HASH') {
        for my $key (keys %$cfg) {
            $cfg->{$key} = $disk->{$key} if exists $disk->{$key};
        }
    }
    $cfg->{scan_lock_dir} ||= File::Spec->catdir($CACHE_DIR, 'locks');
    $cfg->{display_name} = clean_label($cfg->{display_name}, 'Disk Usage Audit');
    $cfg->{credit_prefix} = clean_label($cfg->{credit_prefix}, 'Built by');
    $cfg->{release_url} = clean_url($cfg->{release_url}) || 'https://github.com/Help4Network/help4-disk-usage/archive/refs/heads/main.tar.gz';
    $cfg->{update_manifest_url} = clean_url($cfg->{update_manifest_url}) || $DEFAULT_MANIFEST_URL;
    $cfg->{whm_scan_max_seconds} = bounded_int($cfg->{whm_scan_max_seconds}, 10, 1800, 90);
    $cfg->{cpanel_refreshes_per_hour} = bounded_int($cfg->{cpanel_refreshes_per_hour}, 1, 24, 3);
    $cfg->{cpanel_min_interval_seconds} = bounded_int($cfg->{cpanel_min_interval_seconds}, 0, 3600, 300);
    $cfg->{cpanel_scan_max_seconds} = bounded_int($cfg->{cpanel_scan_max_seconds}, 10, 600, 60);
    $cfg->{package_overrides} = {} unless ref $cfg->{package_overrides} eq 'HASH';
    return $cfg;
}

sub save_settings {
    my ($q, $current) = @_;
    my $cfg = {
        scan_lock_dir                 => clean_abs_path($q->{scan_lock_dir}) || $current->{scan_lock_dir},
        display_name                  => clean_label($q->{display_name}, $current->{display_name}),
        credit_prefix                 => clean_label($q->{credit_prefix}, $current->{credit_prefix}),
        release_url                   => clean_url($q->{release_url}) || $current->{release_url},
        update_manifest_url           => clean_url($q->{update_manifest_url}) || $current->{update_manifest_url},
        whm_scan_max_seconds          => bounded_int($q->{whm_scan_max_seconds}, 10, 1800, $current->{whm_scan_max_seconds}),
        cpanel_refreshes_per_hour     => bounded_int($q->{cpanel_refreshes_per_hour}, 1, 24, $current->{cpanel_refreshes_per_hour}),
        cpanel_min_interval_seconds   => bounded_int($q->{cpanel_min_interval_seconds}, 0, 3600, $current->{cpanel_min_interval_seconds}),
        cpanel_scan_max_seconds       => bounded_int($q->{cpanel_scan_max_seconds}, 10, 600, $current->{cpanel_scan_max_seconds}),
        package_overrides             => $current->{package_overrides} || {},
    };
    if (defined $q->{package_overrides_json} && $q->{package_overrides_json} ne '') {
        my $decoded = eval { decode_json($q->{package_overrides_json}) };
        return 'Settings not saved: package overrides must be valid JSON object.' if !$decoded || ref $decoded ne 'HASH';
        $cfg->{package_overrides} = sanitize_overrides($decoded, $cfg);
    }
    make_path($CACHE_DIR, { mode => 0755 });
    make_path($cfg->{scan_lock_dir}, { mode => 0755 });
    my $lock = File::Spec->catfile($cfg->{scan_lock_dir}, 'scan.lock');
    open my $lfh, '>>', $lock;
    close $lfh if $lfh;
    chmod 0666, $lock if -e $lock;
    write_json_file($CONFIG_FILE, $cfg) or return 'Settings not saved: unable to write config file.';
    chmod 0644, $CONFIG_FILE;
    return 'Settings saved.';
}

sub credit_html {
    my ($cfg) = @_;
    my $prefix = h($cfg->{credit_prefix} || 'Built by');
    return '<footer class="credit">' . $prefix . ' <a href="https://help4network.com/" target="_blank" rel="noopener">Help4 Network</a></footer>';
}

sub sanitize_overrides {
    my ($raw, $defaults) = @_;
    my %out;
    for my $package (keys %$raw) {
        next unless $package =~ /\A[A-Za-z0-9_.:-]+\z/ && ref $raw->{$package} eq 'HASH';
        $out{$package} = {
            cpanel_refreshes_per_hour   => bounded_int($raw->{$package}{cpanel_refreshes_per_hour}, 1, 24, $defaults->{cpanel_refreshes_per_hour}),
            cpanel_min_interval_seconds => bounded_int($raw->{$package}{cpanel_min_interval_seconds}, 0, 3600, $defaults->{cpanel_min_interval_seconds}),
            cpanel_scan_max_seconds     => bounded_int($raw->{$package}{cpanel_scan_max_seconds}, 10, 600, $defaults->{cpanel_scan_max_seconds}),
        };
    }
    return \%out;
}

sub read_json_file {
    my ($path) = @_;
    return unless -f $path;
    open my $fh, '<', $path or return;
    local $/;
    return eval { decode_json(<$fh>) };
}

sub write_json_file {
    my ($path, $data) = @_;
    my $tmp = "$path.$$";
    open my $fh, '>', $tmp or return 0;
    print {$fh} JSON::PP->new->canonical->pretty->encode($data);
    close $fh or return 0;
    rename $tmp, $path or return 0;
    return 1;
}

sub clean_abs_path {
    my ($path) = @_;
    return '' unless defined $path && $path =~ m{\A/[A-Za-z0-9_./-]+\z};
    $path =~ s{/+}{/}g;
    return $path;
}

sub clean_url {
    my ($url) = @_;
    return '' unless defined $url;
    $url =~ s/^\s+|\s+\z//g;
    return $url if $url =~ m{\Ahttps?://[A-Za-z0-9._~:/?#\[\]\@!\$&'()*+,;=%-]+\z};
    return '';
}

sub clean_label {
    my ($value, $default) = @_;
    $value = '' unless defined $value;
    $value =~ s/^\s+|\s+\z//g;
    $value =~ s/[\r\n\t ]+/ /g;
    $value =~ s/[^A-Za-z0-9_ .:()\/+-]//g;
    return substr($value || $default, 0, 80);
}

sub current_version {
    return '' unless -x $SCANNER;
    open my $fh, '-|', $SCANNER, '--help' or return '';
    while (defined(my $line = <$fh>)) {
        if ($line =~ /\AHelp4 Disk Usage scanner v(.+)\s*\z/) {
            close $fh;
            return $1;
        }
    }
    close $fh;
    return '';
}

sub run_update {
    my ($mode, $cfg) = @_;
    return { ok => 0, status => 'error', error => 'Updater binary is not installed yet. Reinstall this release once to enable updates.' } unless -x $UPDATER;
    my @cmd = ($UPDATER, $mode eq 'apply' ? '--apply' : '--check', '--manifest-url', $cfg->{update_manifest_url}, '--release-url', $cfg->{release_url});
    open my $fh, '-|', @cmd or return { ok => 0, status => 'error', error => 'Unable to start updater.' };
    local $/;
    my $json = <$fh>;
    close $fh;
    my $data = eval { decode_json($json) };
    return $data if $data && ref $data eq 'HASH';
    return { ok => 0, status => 'error', error => 'Updater returned invalid output.' };
}

sub bounded_int {
    my ($value, $min, $max, $default) = @_;
    $value = $default unless defined $value && $value =~ /\A\d+\z/;
    $value = int($value);
    $value = $min if $value < $min;
    $value = $max if $value > $max;
    return $value;
}

sub owned_accounts {
    my ($owner) = @_;
    return unless $owner && -d '/var/cpanel/users';
    opendir my $dh, '/var/cpanel/users' or return;
    my @out;
    while (defined(my $user = readdir $dh)) {
        next if $user =~ /^\./;
        my $file = "/var/cpanel/users/$user";
        next unless -f $file;
        open my $fh, '<', $file or next;
        while (defined(my $line = <$fh>)) {
            if ($line =~ /\AOWNER=\Q$owner\E\s*\z/) {
                push @out, $user;
                last;
            }
        }
    }
    return @out;
}

sub allowed {
    my ($acct, $is_root, $owned) = @_;
    return 1 if $is_root;
    my $user = $acct->{user} || '';
    return $user && $owned->{$user};
}

sub parse_query {
    my ($q) = @_;
    my %out;
    for my $pair (split /[&;]/, $q) {
        my ($k, $v) = split /=/, $pair, 2;
        next unless defined $k;
        $v //= '';
        tr/+/ / for $k, $v;
        $k =~ s/%([0-9A-Fa-f]{2})/chr hex $1/ge;
        $v =~ s/%([0-9A-Fa-f]{2})/chr hex $1/ge;
        $out{$k} = $v;
    }
    return %out;
}

sub clean_user {
    my ($u) = @_;
    return '' unless defined $u;
    return $u =~ /\A[A-Za-z0-9_.-]+\z/ ? $u : '';
}

sub severity_rank {
    return { bad => 5, incomplete => 4, check => 3, good => 1 }->{$_[0] || ''} || 0;
}

sub fmt_bytes {
    my ($n) = @_;
    $n ||= 0;
    for my $unit (qw(B KB MB GB TB PB)) {
        return sprintf('%.1f %s', $n, $unit) if $n < 1024 || $unit eq 'PB';
        $n /= 1024;
    }
}

sub fmt_int {
    my ($n) = @_;
    1 while defined($n) && $n =~ s/^(-?\d+)(\d{3})/$1,$2/;
    return $n || 0;
}

sub h {
    my ($s) = @_;
    $s = '' unless defined $s;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/"/&quot;/g;
    return $s;
}
