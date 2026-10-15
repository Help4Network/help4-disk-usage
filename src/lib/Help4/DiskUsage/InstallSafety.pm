package Help4::DiskUsage::InstallSafety;
use strict;
use warnings;
use Fcntl qw(S_ISDIR S_ISREG O_RDONLY O_NOFOLLOW O_NONBLOCK :flock F_GETFD F_SETFD FD_CLOEXEC);
use Errno qw(ENOENT EWOULDBLOCK EAGAIN);
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC);

sub monotonic_time { return clock_gettime(CLOCK_MONOTONIC) }

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

sub removal_targets {
    return [grep { $_->{path} ne '/var/cpanel/help4-disk-usage' &&
        $_->{path} ne '/var/log/help4-disk-usage-scan.log' } @{targets()}];
}

sub with_removal_lock {
    my ($callback, %opts) = @_;
    die "Invalid removal callback\n" unless ref($callback) eq 'CODE';
    my $lock = $opts{lock_path} || '/var/cpanel/help4-disk-usage/locks/scan.lock';
    my $targets = $opts{targets} || removal_targets();
    my $uid = defined $opts{uid} ? $opts{uid} : 0;
    my $deadline = monotonic_time() + 5;
    my $paths = audit([{path => $lock, kind => 'file'}], anchor => $opts{anchor} || '/', uid => $uid);
    die "Removal mutex path is unsafe; inspect installation ownership and permissions\n" unless $paths->{ok};
    my @before = lstat $lock;
    if (!@before) {
        die "Cannot inspect removal mutex\n" unless $! == ENOENT;
        for my $target (@$targets) {
            my @present = lstat $target->{path};
            die "Removal mutex missing; repair the installation before removal\n" if @present;
            die "Cannot inspect removal targets\n" unless $! == ENOENT;
        }
        die "Removal mutex inspection exceeded its deadline\n" if monotonic_time() >= $deadline;
        return $callback->({held => 0, installation_absent => 1});
    }
    sysopen my $fh, $lock, O_RDONLY | O_NOFOLLOW | O_NONBLOCK or die "Cannot open removal mutex\n";
    my ($result, $error);
    my $ok = eval {
        my @opened = stat $fh;
        die "Removal mutex changed during open\n" unless @opened && S_ISREG($opened[2]) &&
            $opened[0] == $before[0] && $opened[1] == $before[1] && $opened[3] == 1 &&
            $opened[4] == $uid && !($opened[2] & 0022);
        my $flags = fcntl($fh, F_GETFD, 0);
        die "Cannot protect removal mutex handle\n" unless defined $flags &&
            defined fcntl($fh, F_SETFD, $flags | FD_CLOEXEC);
        if (!flock($fh, LOCK_EX | LOCK_NB)) {
            die "A disk usage scan is active; retry removal after it finishes\n" if $! == EWOULDBLOCK || $! == EAGAIN;
            die "Cannot acquire removal mutex\n";
        }
        my @current = lstat $lock;
        die "Removal mutex changed during admission\n" unless @current && S_ISREG($current[2]) &&
            $current[0] == $opened[0] && $current[1] == $opened[1] && $current[3] == 1 &&
            $current[4] == $uid && !($current[2] & 0022);
        die "Removal mutex inspection exceeded its deadline\n" if monotonic_time() >= $deadline;
        $result = $callback->({held => 1, installation_absent => 0});
        1;
    };
    $error = $@;
    my $closed = close $fh;
    die $error unless $ok;
    die "Cannot close removal mutex\n" unless $closed;
    return $result;
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
    my $deadline = monotonic_time() + $seconds;
    my $inspect;
    $inspect = sub {
        my ($path, $kind, $level) = @_;
        # Checking a directory as an ancestor must not suppress a later tree walk.
        return if $seen{"$kind:$path"}++;
        die "Installation path inspection limit exceeded\n" if ++$count > $limit ||
            monotonic_time() >= $deadline || $level > $depth;
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
            die "Installation path inspection limit exceeded\n" if monotonic_time() >= $deadline;
            1;
        };
        push @errors, $@ unless $ok;
        last if !$ok;
    }
    chomp @errors;
    return {ok => @errors ? 0 : 1, objects_checked => $count, errors => \@errors};
}

1;
