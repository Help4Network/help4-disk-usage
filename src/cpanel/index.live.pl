#!/usr/bin/env perl
use strict;
use warnings;
use File::Path qw(make_path);
use File::Spec;
use JSON::PP qw(decode_json);

my $APP = 'Help4 Disk Usage';
my $SCANNER = $ENV{HELP4_DU_SCANNER} || '/usr/local/cpanel/3rdparty/help4-disk-usage/bin/help4-disk-usage-scan';
my %q = parse_query($ENV{QUERY_STRING} || '');
my $user = $ENV{REMOTE_USER} || $ENV{CPANEL_USER} || $ENV{USER} || getpwuid($<) || '';
$user =~ s/[^A-Za-z0-9_.-]//g;
my $home = $ENV{HOME} || (getpwnam($user))[7] || '';
my $cache_dir = File::Spec->catdir($home || '/tmp', '.cpanel', 'help4-disk-usage');
my $account_cache = File::Spec->catfile($cache_dir, 'accounts', "$user.json");
my $notice = '';

if ($q{refresh} && $user && $home && -d $home) {
    make_path(File::Spec->catdir($cache_dir, 'accounts'), { mode => 0700 });
    my @cmd = (
        $SCANNER,
        '--scope', 'account',
        '--account', $user,
        '--home', $home,
        '--cache-dir', $cache_dir,
        '--max-seconds', '60',
        '--write-cache',
        '--quiet',
    );
    system(@cmd);
    $notice = $? == 0 ? 'Scan refreshed for this account.' : 'Scan command returned a non-zero status; existing cache is shown.';
}

my $data = read_json($account_cache);

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
