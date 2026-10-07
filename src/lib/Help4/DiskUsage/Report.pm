package Help4::DiskUsage::Report;
use strict;
use warnings;
use Exporter 'import';
use Cwd qw(abs_path);
use File::Spec;
use Fcntl qw(:mode);
use Encode qw(encode_utf8);
use JSON::PP ();
our @EXPORT_OK = qw(report_html report_export filemanager_url report_path h uri);

my @groups = (
    ['large_files', 'Large files', 0],
    ['stale_large_files', 'Stale large files', 0],
    ['size_hotspots', 'Largest directories (direct files)', 1],
    ['inode_hotspots', 'Directories with most direct files', 1],
    ['tree_size_hotspots', 'Largest directory trees', 1],
    ['tree_inode_hotspots', 'Directory trees with most entries', 1],
);

sub h {
    my ($s) = @_;
    $s = '' if !defined($s) || ref($s);
    $s =~ s/&/&amp;/g; $s =~ s/</&lt;/g; $s =~ s/>/&gt;/g;
    $s =~ s/"/&quot;/g; $s =~ s/'/&#39;/g;
    return $s;
}

sub uri {
    my ($s) = @_;
    $s = encode_utf8($s) if utf8::is_utf8($s);
    $s =~ s/([^A-Za-z0-9_.~-])/sprintf('%%%02X', ord($1))/ge;
    return $s;
}

sub report_path {
    my ($path, $directory) = @_;
    return undef unless defined($path) && !ref($path) && length($path) <= 4096;
    return '.' if $directory && $path eq '.';
    return undef if $path eq '' || $path =~ m{\A/|[\x00-\x1f\x7f\\]};
    return undef if grep { $_ eq '' || $_ eq '.' || $_ eq '..' } split m{/}, $path, -1;
    return $path;
}

sub filemanager_url {
    my ($home, $path, $directory) = @_;
    $path = report_path($path, $directory);
    return '' unless defined($path);
    my $base = abs_path($home);
    return '' unless $base && $base ne '/' && -d $base;
    my $target = File::Spec->catfile($base, $path);
    my @st = lstat($target);
    return '' unless @st && ($directory ? S_ISDIR($st[2]) : S_ISREG($st[2]));
    my $dir = $path;
    $dir =~ s{/?[^/]+\z}{} unless $directory;
    $dir = '.' if $dir eq '';
    my $resolved = abs_path(File::Spec->catdir($base, $dir));
    return '' unless $resolved && -d $resolved
        && ($resolved eq $base || index($resolved, "$base/") == 0);
    # A relative route keeps the current authenticated cPanel session prefix.
    return '../filemanager/index.html?dir=' . uri($resolved);
}

sub rows {
    my ($a, $key) = @_;
    return [] unless ref($a->{$key}) eq 'ARRAY';
    my @out = @{$a->{$key}};
    splice @out, 100 if @out > 100;
    return \@out;
}

sub number {
    my ($n) = @_;
    return defined($n) && !ref($n) && $n =~ /\A\d{1,16}\z/ ? 0 + $n : 0;
}

sub integer {
    my ($n) = @_;
    $n = number($n);
    1 while $n =~ s/^(\d+)(\d{3})/$1,$2/;
    return $n;
}

sub bytes {
    my ($n) = @_;
    $n = number($n);
    for my $unit (qw(B KB MB GB TB PB)) {
        return sprintf('%.1f %s', $n, $unit) if $n < 1024 || $unit eq 'PB';
        $n /= 1024;
    }
}

sub tools {
    my ($id, $default, $directory) = @_;
    my $sort = $directory ? '<option value="files">File count</option>' : '<option value="mtime">Modified date</option>';
    my $selected = $default eq 'files' ? ' selected' : '';
    $sort =~ s/value="files"/value="files"$selected/ if $selected;
    my $bytes_selected = $default eq 'bytes' ? ' selected' : '';
    return '<div class="report-tools">'
        . '<label>Search paths<input type="search" data-search aria-controls="' . $id . '" placeholder="Filter paths"></label>'
        . '<label>Sort by<select data-sort><option value="bytes"' . $bytes_selected . '>Size</option>' . $sort . '<option value="path">Path</option></select></label>'
        . '<label>Order<select data-order><option value="desc">Descending</option><option value="asc">Ascending</option></select></label>'
        . '<label>Rows<select data-limit><option>25</option><option>50</option><option>100</option></select></label>'
        . '<button type="button" class="button secondary" data-export-visible>Export results</button></div>';
}

sub report_html {
    my ($a, %opt) = @_;
    my $complete = $a->{scan_complete} ? 1 : 0;
    my $epoch = number($a->{scanned_at_epoch});
    my $freshness = !$epoch ? 'Freshness unknown' : time - $epoch > 86400 ? 'Stale (over 24 hours)' : 'Recent scan';
    my $coverage = $complete ? 'Complete traversal' : 'Partial coverage: lower-bound totals';
    my $out = '<section class="report-summary"><div class="metrics">'
        . '<div><strong>' . h($a->{severity} || 'unknown') . '</strong><span>Status</span></div>'
        . '<div><strong>' . bytes($a->{disk_bytes}) . '</strong><span>Indexed file bytes</span></div>'
        . '<div><strong>' . integer($a->{inode_count}) . '</strong><span>Indexed inodes</span></div>'
        . '<div><strong class="scan-date">' . h($a->{scanned_at} || 'never') . '</strong><span>Last scanned</span></div></div>'
        . '<p class="coverage-line">' . h($coverage) . ' &middot; ' . h($freshness)
        . ' &middot; ' . integer($a->{duration_seconds}) . ' seconds &middot; ' . integer($a->{errors}) . ' errors</p>';
    $out .= '<div class="notice">Incomplete scan: totals are lower bounds. Reason: ' . h($a->{limit_reason} || 'unreadable or changed entries') . '.</div>' unless $complete;
    if (ref($a->{growth}) eq 'HASH' && $a->{growth}{has_previous}) {
        my $delta = $a->{growth}{bytes_delta};
        if (defined($delta) && !ref($delta) && $delta =~ /\A-?\d{1,16}\z/) {
            $out .= '<p>Change since previous complete scan: ' . ($delta < 0 ? '-' : '+') . bytes(abs($delta)) . '.</p>';
        }
    }
    $out .= '</section><nav class="report-nav" aria-label="Report sections">';
    for my $group (@groups) {
        next if $group->[0] =~ /\Atree_/ && !exists($a->{$group->[0]});
        $out .= '<a href="#report-' . $group->[0] . '">' . $group->[1] . '</a>';
    }
    $out .= '</nav><section><h2>Remediation Hints</h2><ul class="hints">';
    for my $hint (@{rows($a, 'remediation_hints')}) { $out .= '<li>' . h($hint) . '</li>' unless ref($hint); }
    $out .= '</ul></section>';
    if (ref($a->{report_policy}) eq 'HASH') {
        $out .= '<p class="muted">Large files: ' . integer($a->{report_policy}{large_mb}) . ' MB or more; stale: ' . integer($a->{report_policy}{stale_days}) . ' days or older; up to ' . integer($a->{report_policy}{top}) . ' entries per ranking.</p>';
    }
    $out .= '<section><h2>Cleanup Hotspots</h2><table class="category-table"><thead><tr><th>Category</th><th>Bytes</th><th>Files</th><th>Hint</th></tr></thead><tbody>';
    for my $r (@{rows($a, 'category_hotspots')}) {
        next unless ref($r) eq 'HASH';
        $out .= '<tr><td>' . h($r->{category}) . '</td><td>' . bytes($r->{bytes}) . '</td><td>' . integer($r->{files}) . '</td><td>' . h($r->{hint}) . '</td></tr>';
    }
    $out .= '</tbody></table></section>';
    for my $group (@groups) {
        my ($key, $title, $directory) = @$group;
        my $id = 'report-' . $key;
        my $tree = $key =~ /\Atree_/ ? 1 : 0;
        next if $tree && !exists($a->{$key});
        $out .= '<section class="file-report" data-report="' . $key . '"><h2>' . $title . '</h2>' . tools($id, $key =~ /inode/ ? 'files' : 'bytes', $directory)
            . '<p class="result-count muted" aria-live="polite"></p><div class="table-scroll"><table id="' . $id . '"><thead><tr><th>Path</th><th>Bytes</th><th>' . ($tree ? 'Subtree entries' : $directory ? 'Direct files' : 'Modified (UTC)') . '</th><th>Actions</th></tr></thead><tbody>';
        my $i = -1;
        for my $r (@{rows($a, $key)}) {
            $i++;
            next unless ref($r) eq 'HASH';
            my $path = report_path($r->{relative_path}, $directory);
            next unless defined($path);
            my $action = $opt{filemanager} ? '<a class="button small secondary filemanager-link" href="index.live.pl?open=' . $key . '&amp;row=' . $i . '" target="_blank" rel="noopener" title="' . ($directory ? 'Open directory in File Manager' : 'Open containing directory in File Manager') . '"><i class="fa fa-folder-open" aria-hidden="true"></i> File Manager</a> ' : '';
            $action .= '<button type="button" class="button small secondary" data-copy="' . h($path) . '" title="Copy relative path"><i class="fa fa-copy" aria-hidden="true"></i> Copy path</button>';
            my $path_cell = $opt{filemanager} ? '<a href="index.live.pl?open=' . $key . '&amp;row=' . $i . '" target="_blank" rel="noopener" title="Open location in File Manager">' . h($path) . '</a>' : h($path);
            $out .= '<tr data-path="' . h($path) . '" data-bytes="' . number($r->{bytes}) . '" data-files="' . number($r->{files}) . '" data-mtime="' . h($r->{mtime}) . '"><td class="path">' . $path_cell . '</td><td>' . bytes($r->{bytes}) . '</td><td>' . ($directory ? integer($r->{files}) : h($r->{mtime})) . '</td><td><div class="actions">' . $action . '</div></td></tr>';
        }
        $out .= '</tbody></table></div><p class="no-results muted" hidden>No matching entries.</p><div class="pagination"><button type="button" class="button small secondary" data-prev>Previous</button><span data-page aria-live="polite"></span><button type="button" class="button small secondary" data-next>Next</button></div></section>';
    }
    $out .= '<div class="action-status muted" role="status" aria-live="polite"></div>';
    return $out;
}

sub clean_report {
    my ($a) = @_;
    my %out = (credit => 'Built by Help4 Network - https://help4network.com/', schema_version => 1);
    for my $key (qw(user scanned_at severity limit_reason)) { $out{$key} = !ref($a->{$key}) ? ($a->{$key} || '') : ''; }
    for my $key (qw(disk_bytes inode_count duration_seconds errors)) { $out{$key} = number($a->{$key}); }
    $out{scan_complete} = $a->{scan_complete} ? JSON::PP::true : JSON::PP::false;
    $out{remediation_hints} = [grep { !ref($_) } @{rows($a, 'remediation_hints')}];
    $out{category_hotspots} = [map { {category => !ref($_->{category}) ? ($_->{category} || '') : '', bytes => number($_->{bytes}), files => number($_->{files}), hint => !ref($_->{hint}) ? ($_->{hint} || '') : ''} } grep { ref($_) eq 'HASH' } @{rows($a, 'category_hotspots')}];
    for my $group (@groups) {
        my ($key, undef, $directory) = @$group;
        my @items;
        for my $r (@{rows($a, $key)}) {
            next unless ref($r) eq 'HASH';
            my $path = report_path($r->{relative_path}, $directory);
            next unless defined $path;
            push @items, {relative_path => $path, bytes => number($r->{bytes}), files => number($r->{files}), mtime => !ref($r->{mtime}) ? ($r->{mtime} || '') : ''};
        }
        $out{$key} = \@items;
    }
    return \%out;
}

sub csv_cell {
    my ($s) = @_;
    $s = '' if !defined($s) || ref($s);
    $s = "'$s" if $s =~ /\A[\s]*[=+\-@]/ || $s =~ /\A[\t\r\n]/;
    $s =~ s/"/""/g;
    return '"' . $s . '"';
}

sub report_export {
    my ($a, $format) = @_;
    my $clean = clean_report($a);
    return JSON::PP->new->canonical->pretty->utf8->encode($clean) if $format eq 'json';
    my @csv = (['account', 'scanned_at', 'coverage', 'group', 'relative_path', 'bytes', 'file_or_subtree_entry_count', 'modified_utc']);
    for my $group (@groups) {
        for my $r (@{$clean->{$group->[0]}}) {
            push @csv, [$clean->{user}, $clean->{scanned_at}, $clean->{scan_complete} ? 'complete' : 'partial', $group->[0], $r->{relative_path}, $r->{bytes}, $r->{files}, $r->{mtime}];
        }
    }
    push @csv, [$clean->{credit}];
    return join('', map { join(',', map { csv_cell($_) } @$_) . "\r\n" } @csv);
}
1;
