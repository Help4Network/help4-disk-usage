#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../src/lib";
our @mutex_fd_updates;
BEGIN {
    # Observe the real descriptor operation without replacing kernel flag enforcement.
    *CORE::GLOBAL::fcntl = sub (*$$) {
        my ($fh, $command, $value) = @_;
        my $result = CORE::fcntl($fh, $command, $value);
        if (caller eq 'Help4::DiskUsage::InstallSafety' && $command == Fcntl::F_SETFD()) {
            push @mutex_fd_updates, {result => $result, flags => CORE::fcntl($fh, Fcntl::F_GETFD(), 0)};
        }
        return $result;
    };
}
use Help4::DiskUsage::InstallSafety;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use Fcntl qw(:DEFAULT :flock);
use POSIX qw(_exit WNOHANG setsid mkfifo);
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC sleep);
use Test::More;

sub put { open my $fh, '>', $_[0] or die $!; print {$fh} $_[1] or die $!; close $fh or die $!; chmod($_[2] // 0600, $_[0]) or die $!; }
sub get { open my $fh, '<', $_[0] or die $!; local $/; my $body = <$fh>; close $fh or die $!; return $body; }
sub streams { my @fd = glob('/dev/fd/*'); return scalar @fd; }
my $root = tempdir(CLEANUP => 1);
chmod 0700, $root;
make_path("$root/cache/locks", "$root/cache/accounts", "$root/runtime", {mode => 0755});
make_path("$root/alternate", {mode => 0755});
put("$root/alternate/scan.lock", 'outside-lock-sentinel', 0644);
my $lock = "$root/cache/locks/scan.lock";
my $report = "$root/cache/accounts/synthetic.json";
put($lock, 'mutex-sentinel', 0644); put($report, 'private-report-sentinel');
put("$root/runtime/module", 'installed');
put("$root/outside", 'outside-sentinel');
symlink "$root/outside", "$root/cache/accounts/not-traversed" or die $!;
my $targets = [{path => "$root/runtime", kind => 'tree'}];
sub guarded { Help4::DiskUsage::InstallSafety::with_removal_lock($_[0], lock_path => $lock, targets => $targets, anchor => $root, uid => $>, @_[1 .. $#_]) }
sub probe {
    my $code = <<'PERL';
use strict; use warnings; use Fcntl qw(:DEFAULT :flock);
my @lock = stat $ARGV[0]; die 'missing fixture' unless @lock;
for my $path (glob('/dev/fd/*')) {
    my @fd = stat $path;
    exit 72 if @fd && $fd[0] == $lock[0] && $fd[1] == $lock[1];
}
sysopen my $fh, $ARGV[0], O_RDONLY | O_NOFOLLOW or die 'probe open';
exit(flock($fh, LOCK_EX | LOCK_NB) ? 0 : 71);
PERL
    local $SIG{ALRM} = sub { die "Probe exceeded watchdog\n" };
    alarm 5;
    my $status = system {$^X} $^X, '-e', $code, $lock;
    alarm 0;
    return ($status & 127) ? 128 + ($status & 127) : $status >> 8;
}
my $initial_streams = streams();
{
    local $^F = 999;
    local @mutex_fd_updates;
    my $called = 0;
    my $value = guarded(sub {
        $called++;
        is_deeply($_[0], {held => 1, installation_absent => 0}, 'Callback runs inside the owned scanner mutex');
        is(scalar @mutex_fd_updates, 1, 'Mutex explicitly updates descriptor flags before callback');
        ok(@mutex_fd_updates && defined $mutex_fd_updates[0]{result} &&
            defined $mutex_fd_updates[0]{flags} && ($mutex_fd_updates[0]{flags} & FD_CLOEXEC),
            'Actual mutex descriptor has close-on-exec after its explicit flag update');
        is(probe(), 71, 'Independent exec sees the held mutex but no inherited descriptor');
        return 0;
    });
    is($value, 0, 'Zero callback result preserved');
    is($called, 1, 'Callback admitted exactly once');
}
is(probe(), 0, 'Mutex releases after successful callback');
is(streams(), $initial_streams, 'Successful callback leaks no descriptor');

pipe my $ready_r, my $ready_w or die $!;
pipe my $release_r, my $release_w or die $!;
my $pid = fork(); die $! unless defined $pid;
if (!$pid) {
    setsid() != -1 or _exit(90);
    close $ready_r; close $release_w;
    sysopen my $held, $lock, O_RDONLY | O_NOFOLLOW or _exit(91);
    flock($held, LOCK_EX | LOCK_NB) or _exit(92);
    print {$ready_w} '1' or _exit(93); close $ready_w;
    sysread($release_r, my $ignored, 1);
    close $release_r; close $held; _exit(0);
}
close $ready_w; close $release_r;
{
    local $SIG{ALRM} = sub { die "Contention fixture exceeded watchdog\n" };
    alarm 5;
    my $ready = ''; is(sysread($ready_r, $ready, 1), 1, 'Separate process holds the actual scanner mutex');
    my $called = 0;
    my $started = clock_gettime(CLOCK_MONOTONIC);
    my $ok = eval { guarded(sub { $called++; put("$root/unsafe-callback", 'changed'); }); 1 };
    my $error = $@;
    alarm 0;
    ok(!$ok && $error =~ /scan is active/, 'Busy scanner refuses removal callback explicitly');
    is($called, 0, 'Busy scanner does not enter callback');
    ok(!-e "$root/unsafe-callback", 'Refused callback performs no fixture mutation');
    cmp_ok(clock_gettime(CLOCK_MONOTONIC) - $started, '<', 2, 'Busy scanner refusal is nonblocking');
    is(get($lock), 'mutex-sentinel', 'Held lock contents are unchanged');
    is(get($report), 'private-report-sentinel', 'Busy refusal preserves cached report');
}
close $ready_r; close $release_w;
my $deadline = clock_gettime(CLOCK_MONOTONIC) + 3;
while (waitpid($pid, WNOHANG) != $pid) {
    if (clock_gettime(CLOCK_MONOTONIC) >= $deadline) { kill 'KILL', -$pid; waitpid($pid, 0); die 'Holder did not stop'; }
    sleep 0.01;
}
is($? >> 8, 0, 'Owned holder exited without forced cancellation');
is(probe(), 0, 'Independent process can acquire mutex after holder exit');

for my $case ('symlink', 'hardlink', 'fifo', 'writable-file', 'writable-parent', 'linked-parent', 'foreign-owner', 'missing') {
    unlink $lock or die $!;
    if ($case eq 'symlink') { symlink "$root/outside", $lock or die $!; }
    elsif ($case eq 'hardlink') { link "$root/outside", $lock or die $!; }
    elsif ($case eq 'fifo') { mkfifo($lock, 0600) or die $!; }
    elsif ($case eq 'linked-parent') {
        rmdir "$root/cache/locks" or die $!;
        symlink "$root/alternate", "$root/cache/locks" or die $!;
    }
    elsif ($case ne 'missing') { put($lock, 'mutex-sentinel', $case eq 'writable-file' ? 0664 : 0644); }
    chmod 0775, "$root/cache/locks" if $case eq 'writable-parent';
    my $called = 0; my $ok;
    {
        local $SIG{ALRM} = sub { die "Unsafe-object fixture exceeded watchdog\n" };
        alarm 5;
        $ok = eval { guarded(sub { $called++; }, $case eq 'foreign-owner' ? (uid => $> + 1) : ()); 1 };
        alarm 0;
    }
    ok(!$ok && $@, "$case mutex rejected");
    is($called, 0, "$case rejection never enters callback");
    is(get($report), 'private-report-sentinel', "$case refusal preserves cached report");
    is(get("$root/outside"), 'outside-sentinel', "$case refusal never writes outside target");
    if ($case eq 'linked-parent') {
        unlink "$root/cache/locks" or die $!;
        mkdir "$root/cache/locks", 0755 or die $!;
    } else { chmod 0755, "$root/cache/locks"; }
    unlink $lock if -e $lock || -l $lock;
    put($lock, 'mutex-sentinel', 0644);
    is(probe(), 0, "$case refusal leaves no mutex held");
}
{
    my $ok = eval { guarded(sub { die "Synthetic callback failure\n" }); 1 };
    ok(!$ok && $@ eq "Synthetic callback failure\n", 'Callback exception preserved');
    is(probe(), 0, 'Callback exception releases mutex');
}
my $guard_calls = 8;
{
    no warnings 'redefine';
    my $calls = 0;
    local *Help4::DiskUsage::InstallSafety::monotonic_time = sub { $calls++; return 0 };
    is(guarded(sub { return 'clock-control' }), 'clock-control', 'Deterministic timing baseline remains usable');
    is($calls, $guard_calls, 'Final mutex admission clock remains distinct from the inner path audit');
}
for my $elapsed (4.999, 5, 6) {
    no warnings 'redefine';
    my ($calls, $called) = (0, 0);
    local *Help4::DiskUsage::InstallSafety::monotonic_time = sub { return ++$calls == $guard_calls ? $elapsed : 0 };
    my $ok = eval { guarded(sub { $called++; return 'admitted'; }); 1 };
    is($ok ? 1 : 0, $elapsed < 5 ? 1 : 0, "Final mutex admission at $elapsed obeys inclusive budget");
    is($called, $elapsed < 5 ? 1 : 0, 'Expired mutex admission never enters callback');
    is($calls, $guard_calls, 'Intended final admission clock was reached');
    is(probe(), 0, 'Deadline path releases mutex');
}
unlink $lock or die $!;
my $absent = Help4::DiskUsage::InstallSafety::with_removal_lock(sub { return $_[0] },
    lock_path => $lock, targets => [{path => "$root/never-installed", kind => 'tree'}], anchor => $root, uid => $>);
is_deeply($absent, {held => 0, installation_absent => 1}, 'Missing mutex allowed only when every removal target is absent');
ok(!-e $lock, 'Idempotent no-install check creates no mutex');
is(get($report), 'private-report-sentinel', 'Retained account subtree is never traversed or removed');
is(get("$root/alternate/scan.lock"), 'outside-lock-sentinel', 'Linked ancestor target remains unchanged');
is(streams(), $initial_streams, 'All guards/child processes leave descriptor count unchanged');
note('Actual local POSIX advisory locks and child processes; no native cPanel hooks, cancellation, concurrent installer, process-death or continuously atomic path safety certification.');
done_testing;
