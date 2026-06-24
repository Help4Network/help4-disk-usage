#!/usr/bin/env perl
use strict;
use warnings;
use File::Path qw(make_path);
use File::Spec;
use JSON::PP qw(decode_json);

my $APP = 'Help4 Disk Usage';
my $SCANNER = $ENV{HELP4_DU_SCANNER} || '/usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-scan';
my $GLOBAL_CONFIG = $ENV{HELP4_DU_CONFIG} || '/var/cpanel/help4-disk-usage/config.json';
my %q = parse_query($ENV{QUERY_STRING} || '');
my $user = $ENV{REMOTE_USER} || $ENV{CPANEL_USER} || $ENV{USER} || getpwuid($<) || '';
$user =~ s/[^A-Za-z0-9_.-]//g;
my $euid_user = getpwuid($<) || '';
if ($euid_user && $euid_user !~ /\A(?:root|cpanel|nobody)\z/ && $euid_user =~ /\A[A-Za-z0-9_.-]+\z/) {
    $user = $euid_user;
}
my $passwd_home = $user ? (getpwnam($user))[7] : '';
my $home = $passwd_home || $ENV{HOME} || '';
my $cache_dir = File::Spec->catdir($home || '/tmp', '.cpanel', 'help4-disk-usage');
my $account_cache = File::Spec->catfile($cache_dir, 'accounts', "$user.json");
my $config = load_config();
my $limits = limits_for_user($user, $config);
my $notice = '';

if ($q{refresh} && $user && $home && -d $home) {
    make_path(File::Spec->catdir($cache_dir, 'accounts'), { mode => 0700 });
    my ($allowed, $message) = allow_refresh($cache_dir, $limits);
    if (!$allowed) {
        $notice = $message;
    } else {
    my @cmd = (
        $SCANNER,
        '--scope', 'account',
        '--account', $user,
        '--home', $home,
        '--cache-dir', $cache_dir,
        '--lock-dir', $config->{scan_lock_dir},
        '--max-seconds', $limits->{cpanel_scan_max_seconds},
        '--write-cache',
        '--quiet',
    );
    local $ENV{HELP4_DU_LOCK_DIR} = $config->{scan_lock_dir};
    system(@cmd);
    $notice = $? == 0 ? 'Scan refreshed for this account.' : 'Scan is already running or returned a non-zero status; existing cache is shown.';
    }
}

my $data = read_json($account_cache);
$data = undef if $data && (($data->{user} || '') ne $user);

print "Content-Type: text/html; charset=utf-8\r\n\r\n";
print page($data, $notice, $user);

sub page {
    my ($a, $notice, $user) = @_;
    my $notice_html = $notice ? '<div class="notice">' . h($notice) . '</div>' : '';
    my $summary = $a ? summary($a) : '<div class="empty">No account scan cache exists yet.</div>';
    return <<"HTML";
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>$APP</title>
  <link rel="stylesheet" href="help4-disk-usage.css">
</head>
<body>
  <main class="wrap">
    <header class="topbar">
      <div>
        <h1>$APP</h1>
        <p class="muted">Account view for @{[h($user || 'unknown')]}. Paths are shown relative to your home directory.</p>
      </div>
      <div class="actions"><a class="button" href="?refresh=1">Refresh scan</a></div>
    </header>
    $notice_html
    $summary
    <footer class="credit">Help4 Disk Usage by Help4 Network</footer>
  </main>
</body>
</html>
HTML
}

sub summary {
    my ($a) = @_;
    my $hints = join '', map { '<li>' . h($_) . '</li>' } @{$a->{remediation_hints} || []};
    my $large = table($a->{large_files} || [], ['relative_path', 'bytes', 'mtime'], 'Large files');
    my $stale = table($a->{stale_large_files} || [], ['relative_path', 'bytes', 'mtime'], 'Stale large files');
    my $inode = table($a->{inode_hotspots} || [], ['relative_path', 'files', 'bytes'], 'Inode-heavy directories');
    my $cats = category_table($a->{category_hotspots} || []);
    return <<"HTML";
<section class="metrics">
  <div><strong>@{[h($a->{severity} || 'unknown')]}</strong><span>Status</span></div>
  <div><strong>@{[fmt_bytes($a->{disk_bytes} || 0)]}</strong><span>Indexed file bytes</span></div>
  <div><strong>@{[fmt_int($a->{inode_count} || 0)]}</strong><span>Indexed inodes</span></div>
  <div><strong>@{[h($a->{scanned_at} || 'never')]}</strong><span>Last scanned</span></div>
</section>
<section>
  <h2>Remediation Hints</h2>
  <ul class="hints">$hints</ul>
</section>
$cats
$large
$stale
$inode
HTML
}

sub table {
    my ($rows, $cols, $title) = @_;
    my $body = join '', map {
        my $r = $_;
        '<tr>' . join('', map { '<td>' . cell($r, $_) . '</td>' } @$cols) . '</tr>'
    } @$rows;
    $body ||= '<tr><td colspan="' . scalar(@$cols) . '" class="muted">No entries in this scan.</td></tr>';
    my $head = join '', map { '<th>' . h(label($_)) . '</th>' } @$cols;
    return "<section><h2>" . h($title) . "</h2><table><thead><tr>$head</tr></thead><tbody>$body</tbody></table></section>";
}

sub category_table {
    my ($rows) = @_;
    my $body = join '', map {
        '<tr><td>' . h($_->{category}) . '</td><td>' . fmt_bytes($_->{bytes} || 0) . '</td><td>' . fmt_int($_->{files} || 0) . '</td><td>' . h($_->{hint}) . '</td></tr>'
    } @$rows;
    $body ||= '<tr><td colspan="4" class="muted">No cache/log/temp/mail/backup hotspots detected.</td></tr>';
    return "<section><h2>Cleanup Hotspots</h2><table><thead><tr><th>Category</th><th>Bytes</th><th>Files</th><th>Hint</th></tr></thead><tbody>$body</tbody></table></section>";
}

sub cell {
    my ($r, $col) = @_;
    return fmt_bytes($r->{$col} || 0) if $col eq 'bytes';
    return fmt_int($r->{$col} || 0) if $col eq 'files';
    return h($r->{$col} || '');
}

sub label {
    my ($s) = @_;
    $s =~ s/_/ /g;
    return ucfirst $s;
}

sub read_json {
    my ($path) = @_;
    return unless -f $path;
    open my $fh, '<', $path or return;
    local $/;
    return eval { decode_json(<$fh>) };
}

sub default_config {
    return {
        scan_lock_dir                 => '/var/cpanel/help4-disk-usage/locks',
        cpanel_refreshes_per_hour     => 3,
        cpanel_min_interval_seconds   => 300,
        cpanel_scan_max_seconds       => 60,
        package_overrides             => {},
    };
}

sub load_config {
    my $cfg = default_config();
    my $disk = read_json($GLOBAL_CONFIG);
    if ($disk && ref $disk eq 'HASH') {
        for my $key (keys %$cfg) {
            $cfg->{$key} = $disk->{$key} if exists $disk->{$key};
        }
    }
    $cfg->{scan_lock_dir} ||= '/var/cpanel/help4-disk-usage/locks';
    $cfg->{cpanel_refreshes_per_hour} = bounded_int($cfg->{cpanel_refreshes_per_hour}, 1, 24, 3);
    $cfg->{cpanel_min_interval_seconds} = bounded_int($cfg->{cpanel_min_interval_seconds}, 0, 3600, 300);
    $cfg->{cpanel_scan_max_seconds} = bounded_int($cfg->{cpanel_scan_max_seconds}, 10, 600, 60);
    $cfg->{package_overrides} = {} unless ref $cfg->{package_overrides} eq 'HASH';
    return $cfg;
}

sub limits_for_user {
    my ($user, $cfg) = @_;
    my %limits = (
        cpanel_refreshes_per_hour   => $cfg->{cpanel_refreshes_per_hour},
        cpanel_min_interval_seconds => $cfg->{cpanel_min_interval_seconds},
        cpanel_scan_max_seconds     => $cfg->{cpanel_scan_max_seconds},
    );
    my $package = account_package($user);
    if ($package && $cfg->{package_overrides}{$package} && ref $cfg->{package_overrides}{$package} eq 'HASH') {
        my $override = $cfg->{package_overrides}{$package};
        for my $key (keys %limits) {
            $limits{$key} = $override->{$key} if exists $override->{$key};
        }
        $limits{cpanel_refreshes_per_hour} = bounded_int($limits{cpanel_refreshes_per_hour}, 1, 24, $cfg->{cpanel_refreshes_per_hour});
        $limits{cpanel_min_interval_seconds} = bounded_int($limits{cpanel_min_interval_seconds}, 0, 3600, $cfg->{cpanel_min_interval_seconds});
        $limits{cpanel_scan_max_seconds} = bounded_int($limits{cpanel_scan_max_seconds}, 10, 600, $cfg->{cpanel_scan_max_seconds});
    }
    return \%limits;
}

sub account_package {
    my ($user) = @_;
    return '' unless $user =~ /\A[A-Za-z0-9_.-]+\z/;
    my $file = "/var/cpanel/users/$user";
    return '' unless -r $file;
    open my $fh, '<', $file or return '';
    while (defined(my $line = <$fh>)) {
        chomp $line;
        return $1 if $line =~ /\APLAN=(.+)\z/;
    }
    return '';
}

sub allow_refresh {
    my ($cache_dir, $limits) = @_;
    my $rate_path = File::Spec->catfile($cache_dir, 'rate.json');
    my $now = time;
    my $window = 3600;
    my $state = read_json($rate_path) || {};
    my @attempts = grep { $_ && $_ >= $now - $window } @{$state->{attempts} || []};
    my $last = $state->{last_attempt} || 0;

    if ($limits->{cpanel_min_interval_seconds} && $last && $now - $last < $limits->{cpanel_min_interval_seconds}) {
        my $wait = $limits->{cpanel_min_interval_seconds} - ($now - $last);
        return (0, 'Refresh throttled. Try again in about ' . int(($wait + 59) / 60) . ' minute(s).');
    }
    if (@attempts >= $limits->{cpanel_refreshes_per_hour}) {
        my $reset = $attempts[0] + $window - $now;
        return (0, 'Hourly refresh limit reached. Try again in about ' . int(($reset + 59) / 60) . ' minute(s).');
    }

    push @attempts, $now;
    write_json($rate_path, { last_attempt => $now, attempts => \@attempts });
    return (1, '');
}

sub write_json {
    my ($path, $data) = @_;
    my $tmp = "$path.$$";
    open my $fh, '>', $tmp or return;
    print {$fh} JSON::PP->new->canonical->pretty->encode($data);
    close $fh or return;
    chmod 0600, $tmp;
    rename $tmp, $path;
}

sub bounded_int {
    my ($value, $min, $max, $default) = @_;
    $value = $default unless defined $value && $value =~ /\A\d+\z/;
    $value = int($value);
    $value = $min if $value < $min;
    $value = $max if $value > $max;
    return $value;
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
