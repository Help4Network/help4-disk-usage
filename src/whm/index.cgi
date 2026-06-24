#!/usr/bin/env perl
use strict;
use warnings;
use File::Spec;
use JSON::PP qw(decode_json);
use POSIX qw(strftime);

my $APP = 'Help4 Disk Usage';
my $CACHE_DIR = $ENV{HELP4_DU_CACHE_DIR} || '/var/cpanel/help4-disk-usage';
my $SCANNER = $ENV{HELP4_DU_SCANNER} || '/usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-scan';
my %q = parse_query($ENV{QUERY_STRING} || '');
my $auth_user = $ENV{REMOTE_USER} || $ENV{USER} || '';
$auth_user =~ s/[^A-Za-z0-9_.-]//g;

my $notice = '';
my $is_root = $auth_user eq 'root' || $> == 0 && !$auth_user;
my %owned = map { $_ => 1 } owned_accounts($auth_user);
$owned{$auth_user} = 1 if $auth_user && !$is_root;

if ($q{refresh}) {
    my @cmd = ($SCANNER, '--write-cache', '--quiet', '--max-seconds', '90');
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
        system(@cmd);
        $notice = $? == 0 ? 'Scan refreshed. Review the timestamps below.' : 'Scan command returned a non-zero status; existing cache is shown.';
    }
}

my @accounts = grep { allowed($_, $is_root, \%owned) } read_account_caches();
@accounts = sort {
    severity_rank($b->{severity}) <=> severity_rank($a->{severity})
    || ($b->{disk_bytes} || 0) <=> ($a->{disk_bytes} || 0)
    || ($a->{user} || '') cmp ($b->{user} || '')
} @accounts;

print "Content-Type: text/html; charset=utf-8\r\n\r\n";
print page(\@accounts, $notice, $auth_user, $is_root);

sub page {
    my ($accounts, $notice, $auth_user, $is_root) = @_;
    my $total_bytes = 0;
    my $total_inodes = 0;
    my %sev;
    for my $a (@$accounts) {
        $total_bytes += $a->{disk_bytes} || 0;
        $total_inodes += $a->{inode_count} || 0;
        $sev{$a->{severity} || 'unknown'}++;
    }
    my $scope = $is_root ? 'Root view: all accounts' : 'Reseller view: owned accounts only';
    my $rows = join '', map { account_row($_, $is_root) } @$accounts;
    $rows ||= '<tr><td colspan="8" class="muted">No scan cache exists yet. Run a refresh to collect data.</td></tr>';
    my $refresh_all = $is_root ? '<a class="button" href="?refresh=1">Refresh all accounts</a>' : '<a class="button" href="?refresh=1">Refresh owned accounts</a>';
    my $notice_html = $notice ? '<div class="notice">' . h($notice) . '</div>' : '';
    return <<"HTML";
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>$APP</title>
  <link rel="stylesheet" href="/help4-disk-usage/help4-disk-usage.css">
</head>
<body>
  <main class="wrap">
    <header class="topbar">
      <div>
        <h1>$APP</h1>
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
  </main>
</body>
</html>
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
        my $path = File::Spec->catfile($dir, $file);
        open my $fh, '<', $path or next;
        local $/;
        my $data = eval { decode_json(<$fh>) };
        push @out, $data if $data && ref $data eq 'HASH';
    }
    return @out;
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
    return $owned->{$acct->{user}} || ($acct->{owner} && $owned->{$acct->{owner}});
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
