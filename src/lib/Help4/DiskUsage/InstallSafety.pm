package Help4::DiskUsage::InstallSafety;
use strict;
use warnings;
use Fcntl qw(S_ISDIR S_ISREG);
use Errno qw(ENOENT);
use Time::HiRes qw(time);

sub targets {
    return [
        map({ {path => $_, kind => 'tree'} }
            '/usr/local/cpanel/3rdparty/help4-disk-usage',
            '/usr/local/cpanel/whostmgr/docroot/cgi/help4_disk_usage',
            '/usr/local/cpanel/whostmgr/docroot/templates/help4_disk_usage',
            '/usr/local/cpanel/whostmgr/docroot/help4-disk-usage',
            '/usr/local/cpanel/base/frontend/jupiter/help4_disk_usage',
            '/var/cpanel/help4-disk-usage'),
        map({ {path => $_, kind => 'file'} }
            '/usr/local/cpanel/whostmgr/docroot/addon_plugins/help4-disk-usage.png',
            '/var/cpanel/apps/help4_disk_usage.conf',
            '/etc/cron.d/help4-disk-usage',
            '/etc/logrotate.d/help4-disk-usage',
            '/var/log/help4-disk-usage-scan.log'),
    ];
}

sub audit {
    my ($targets, %opts) = @_;
    my $anchor = $opts{anchor} || '/';
    my $uid = defined $opts{uid} ? $opts{uid} : 0;
    my $limit = $opts{limit} || 8192;
    my $depth = $opts{depth} || 32;
    my $seconds = $opts{seconds} || 5;
    die "Invalid audit bounds\n" unless $limit >= 1 && $limit <= 8192 &&
        $depth >= 1 && $depth <= 32 && $seconds > 0 && $seconds <= 5;
    my (@errors, %seen);
    my $count = 0;
    my $deadline = time() + $seconds;
    my $inspect;
    $inspect = sub {
        my ($path, $kind, $level) = @_;
        # Checking a directory as an ancestor must not suppress a later tree walk.
        return if $seen{"$kind:$path"}++;
        die "Installation path inspection limit exceeded\n" if ++$count > $limit ||
            time() > $deadline || $level > $depth;
        my @st = lstat $path;
        if (!@st) {
            return if $! == ENOENT;
            die "Cannot inspect installation path: $path\n";
        }
        die "Unsafe installation path type: $path\n" unless
            ($kind eq 'file' ? S_ISREG($st[2]) : S_ISDIR($st[2]));
        die "Installation path is not administrator-owned: $path\n" unless $st[4] == $uid;
        die "Installation path permits non-administrator writes: $path\n" if $st[2] & 0022;
        die "Hard-linked installation file: $path\n" if S_ISREG($st[2]) && $st[3] != 1;
        return unless $kind eq 'tree';
        opendir my $dh, $path or die "Cannot inspect installation directory: $path\n";
        my @opened = stat $dh;
        die "Installation directory changed during inspection: $path\n" unless
            @opened && $opened[0] == $st[0] && $opened[1] == $st[1];
        while (defined(my $name = readdir $dh)) {
            next if $name eq '.' || $name eq '..';
            my $child = "$path/$name";
            my @child = lstat $child;
            die "Installation entry changed during inspection: $child\n" unless @child;
            $inspect->($child, S_ISDIR($child[2]) ? 'tree' : 'file', $level + 1);
        }
        closedir $dh or die "Cannot close installation directory: $path\n";
    };
    for my $target (@$targets) {
        my $ok = eval {
            my ($path, $kind) = @{$target}{qw(path kind)};
            die "Invalid installation target\n" unless defined $path && $path =~ m{\A/} &&
                length($path) <= 4096 && $path !~ m{[\x00-\x1f\x7f]|//|(?:\A|/)\.{1,2}(?:/|\z)} &&
                $kind =~ /\A(?:tree|file)\z/ &&
                ($anchor eq '/' || $path =~ /^\Q$anchor\E\//);
            $inspect->($anchor, 'dir', 0);
            my $parent = $path;
            my @parents;
            while ($parent =~ s{/[^/]+\z}{}) {
                last if $parent eq '' || $parent eq $anchor;
                unshift @parents, $parent;
            }
            $inspect->($_, 'dir', 0) for @parents;
            $inspect->($path, $kind, 0);
            1;
        };
        push @errors, $@ unless $ok;
        last if !$ok;
    }
    chomp @errors;
    return {ok => @errors ? 0 : 1, objects_checked => $count, errors => \@errors};
}

1;
