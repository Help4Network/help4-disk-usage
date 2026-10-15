#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../src/lib";
use Help4::DiskUsage::InstallSafety;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use Fcntl qw(:DEFAULT :flock);
use POSIX qw(setsid WNOHANG);
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC sleep);
use Test::More;

sub get { open my $fh, '<', $_[0] or die $!; local $/; my $body = <$fh>; close $fh or die $!; return $body; }
sub put { open my $fh, '>', $_[0] or die $!; print {$fh} $_[1] or die $!; close $fh or die $!; chmod($_[2] // 0600, $_[0]) or die $!; }
sub quote { my $v = shift; $v =~ s/'/'\\''/g; return "'$v'"; }
sub run_child {
    my ($dir) = @_;
    my $pid = fork(); die $! unless defined $pid;
    if (!$pid) {
        setsid() != -1 or die $!;
        open STDOUT, '>', "$dir/output" or die $!; open STDERR, '>&', \*STDOUT or die $!;
        exec {$^X} $^X, "$dir/scripts/uninstall-run.pl"; die $!;
    }
    my $deadline = clock_gettime(CLOCK_MONOTONIC) + 5;
    while (1) {
        my $done = waitpid($pid, WNOHANG);
        if ($done == $pid) { my $status = $?; return ($status & 127) ? 128 + ($status & 127) : $status >> 8; }
        die 'Runner wait failed' if $done < 0;
        if (clock_gettime(CLOCK_MONOTONIC) >= $deadline) {
            kill 'KILL', -$pid; waitpid($pid, 0); die 'Owned runner exceeded watchdog';
        }
        sleep 0.01;
    }
}
my $root = tempdir(CLEANUP => 1); chmod 0700, $root;
my $original_module = get("$FindBin::Bin/../src/lib/Help4/DiskUsage/InstallSafety.pm");
my $original_runner = get("$FindBin::Bin/../scripts/uninstall-run.pl");
for my $case ('available', 'busy', 'hook-failure') {
    my $dir = "$root/$case";
    make_path("$dir/scripts", "$dir/src/lib/Help4/DiskUsage", "$dir/tools", "$dir/packaging", {mode => 0700});
    my %prefix = ('/usr/local/cpanel' => "$dir/cpanel", '/var/cpanel/apps' => "$dir/apps",
        '/var/cpanel/help4-disk-usage' => "$dir/cache", '/var/log/help4-disk-usage-scan.log' => "$dir/retained-log",
        '/etc/cron.d' => "$dir/cron", '/etc/logrotate.d' => "$dir/logrotate");
    my ($module, $runner) = ($original_module, $original_runner);
    for my $old (keys %prefix) { $module =~ s/\Q$old\E/$prefix{$old}/g; $runner =~ s/\Q$old\E/$prefix{$old}/g; }
    # Private bootstrap changes only trust roots/owner and OS admission, not lock/control-flow bodies.
    my $uid_default = q{my $uid = defined $opts{uid} ? $opts{uid} : 0;};
    is(($module =~ s/\Q$uid_default\E/my \$uid = defined \$opts{uid} ? \$opts{uid} : $>;/g), 2, 'Fixture rebases exactly two owner defaults');
    my $anchor_default = q{my $anchor = $opts{anchor} || '/';};
    is(($module =~ s/\Q$anchor_default\E/my \$anchor = \$opts{anchor} || '$dir';/g), 1, 'Fixture confines audit anchor');
    my $lock_anchor = q{anchor => $opts{anchor} || '/', uid => $uid};
    is(($module =~ s/\Q$lock_anchor\E/anchor => \$opts{anchor} || '$dir', uid => \$uid/g), 1, 'Fixture confines mutex anchor');
    my $admission = q{if @ARGV || $^O ne 'linux' || $> != 0;};
    is(($runner =~ s/\Q$admission\E/if \@ARGV;/g), 1, 'Fixture replaces only native OS/identity admission');
    put("$dir/src/lib/Help4/DiskUsage/InstallSafety.pm", $module);
    put("$dir/scripts/uninstall-run.pl", $runner);
    my @paths;
    for my $target (@{Help4::DiskUsage::InstallSafety::removal_targets()}) {
        my $path = $target->{path}; $path =~ s/\Q$_\E/$prefix{$_}/g for keys %prefix;
        push @paths, $path;
        if ($target->{kind} eq 'tree') { make_path($path, {mode => 0755}); put("$path/canary", 'installed'); }
        else { (my $parent = $path) =~ s{/[^/]+\z}{}; make_path($parent, {mode => 0755}); put($path, 'installed'); }
    }
    make_path("$dir/cache/locks", "$dir/cache/accounts", "$dir/cpanel/scripts", "$dir/cpanel/bin", {mode => 0755});
    my $lock = "$dir/cache/locks/scan.lock"; put($lock, 'mutex-sentinel', 0644);
    put("$dir/cache/accounts/retained.json", 'synthetic-private-report'); put("$dir/retained-log", 'synthetic-log');
    put("$dir/probe.pl", <<'PERL');
use strict; use warnings; use Fcntl qw(:DEFAULT :flock);
my @lock = stat $ARGV[0]; die 'fixture lock absent' unless @lock;
for my $path (glob('/dev/fd/*')) {
    my @fd = stat $path;
    exit 73 if @fd && $fd[0] == $lock[0] && $fd[1] == $lock[1];
}
sysopen my $fh, $ARGV[0], O_RDONLY | O_NOFOLLOW or die 'fixture probe unavailable';
exit(flock($fh, LOCK_EX | LOCK_NB) ? 74 : 0);
PERL
    my $probe = '"$H4DU_PERL" "$H4DU_CASE/probe.pl" "$H4DU_CASE/cache/locks/scan.lock"' . "\n";
    put("$dir/cpanel/scripts/uninstall_plugin", "#!/usr/bin/env bash\nset -euo pipefail\n" .
        'test "$#" -eq 2 && test "$1" = "$H4DU_CASE/packaging" && test "$2" = --theme=jupiter' . "\n" .
        $probe . 'printf \'%s\n\' uninstall >> "$H4DU_CASE/trace"' . "\n" .
        'test "$H4DU_CASE_MODE" != hook-failure || exit 4' . "\n", 0755);
    put("$dir/cpanel/bin/unregister_appconfig", "#!/usr/bin/env bash\nset -euo pipefail\n" .
        'test "$#" -eq 1 && test "$1" = "$H4DU_CASE/apps/help4_disk_usage.conf"' . "\n" .
        $probe . 'printf \'%s\n\' unregister >> "$H4DU_CASE/trace"' . "\n", 0755);
    my $allowed = join '|', map { quote($_) } @paths;
    my $rm = -x '/bin/rm' ? '/bin/rm' : '/usr/bin/rm';
    put("$dir/tools/rm", "#!/usr/bin/env bash\nset -euo pipefail\n" .
        'for arg in "$@"; do' . "\ncase \"\$arg\" in -rf|-f|$allowed) ;; *) exit 97 ;; esac\ndone\n" .
        $probe . 'printf \'%s\n\' removal >> "$H4DU_CASE/trace"' . "\nexec " . quote($rm) . ' "$@"' . "\n", 0755);
    put("$dir/tools/cp", "#!/usr/bin/env bash\nexit 98\n", 0755);
    local $ENV{PATH} = "$dir/tools:$ENV{PATH}";
    local $ENV{H4DU_CASE} = $dir; local $ENV{H4DU_PERL} = $^X; local $ENV{H4DU_CASE_MODE} = $case;
    local $ENV{HELP4_DU_BACKUP_DIR} = $case eq 'busy' ? "$dir/backup" : '';
    my $held;
    if ($case eq 'busy') { sysopen($held, $lock, O_RDONLY) or die $!; flock($held, LOCK_EX | LOCK_NB) or die $!; }
    my $exit = run_child($dir);
    is($exit, $case eq 'available' ? 0 : $case eq 'busy' ? 2 : 4, "$case guarded runner preserves result");
    my @trace = -f "$dir/trace" ? split(/\n/, get("$dir/trace")) : ();
    is_deeply(\@trace, $case eq 'available' ? [qw(uninstall unregister removal removal)] :
        $case eq 'hook-failure' ? ['uninstall'] : [], "$case hooks and deletions all observed a held mutex without inherited descriptor");
    like(get("$dir/output"), qr/scan is active/, 'Busy runner is explicit') if $case eq 'busy';
    close $held if $held;
    for my $path (@paths) {
        my $removed = $case eq 'available' && $path ne "$dir/apps/help4_disk_usage.conf";
        is(-e $path ? 1 : 0, $removed ? 0 : 1, "$case managed fixture path state preserved");
    }
    is(get($lock), 'mutex-sentinel', "$case lock inode contents retained");
    is(get("$dir/cache/accounts/retained.json"), 'synthetic-private-report', "$case account cache retained");
    is(get("$dir/retained-log"), 'synthetic-log', "$case scan log retained");
    ok(!-d "$dir/backup", "$case never copies on refused/default path");
    sysopen my $check, $lock, O_RDONLY or die $!;
    ok(flock($check, LOCK_EX | LOCK_NB), "$case runner releases mutex after completion"); close $check;
}
note('Rebased source/real kernel locks and guarded removal; only owner/anchor/OS fixture bootstrap differs. Native hooks are controlled probes, not cPanel registry/lifecycle proof.');
done_testing;
