#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../src/lib";
use Help4::DiskUsage::InstallSafety;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use JSON::PP;
use Test::More;
use POSIX qw(setsid WNOHANG);
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC sleep);

sub read_file { open my $fh, '<', $_[0] or die $!; local $/; my $v = <$fh>; close $fh or die $!; return $v; }
sub write_file {
    my ($p, $v, $mode) = @_;
    open my $fh, '>', $p or die $!; print {$fh} $v or die $!; close $fh or die $!;
    chmod($mode // 0600, $p) or die $!;
}
sub quote { my $v = shift; $v =~ s/'/'\\''/g; return "'$v'"; }
my $root = tempdir(CLEANUP => 1);
chmod 0700, $root;
my $source = read_file("$FindBin::Bin/../uninstall.sh");
my $targets = Help4::DiskUsage::InstallSafety::removal_targets();
is(scalar @$targets, 9, 'Removal checks all five trees and four singleton integration paths');
ok(!grep({$_->{path} =~ m{(?:/home/|\A/var/cpanel/help4-disk-usage|\A/var/log/)}} @$targets),
    'Preserved cache/log and customer homes excluded from removal traversal');

sub run_child {
    my ($dir, @command) = @_;
    my $pid = fork(); die 'Fork unavailable' unless defined $pid;
    if (!$pid) {
        setsid() != -1 or die 'Private process group unavailable';
        open STDOUT, '>', "$dir/output" or die $!;
        open STDERR, '>&', \*STDOUT or die $!;
        exec @command; die 'Fixture command unavailable';
    }
    my $deadline = clock_gettime(CLOCK_MONOTONIC) + 10;
    while (1) {
        my $done = waitpid($pid, WNOHANG);
        if ($done == $pid) { my $status = $?; return ($status & 127) ? 128 + ($status & 127) : $status >> 8; }
        die 'Private wait failed' if $done < 0;
        if (clock_gettime(CLOCK_MONOTONIC) >= $deadline) {
            kill 'KILL', -$pid; waitpid($pid, 0) == $pid or die 'Private cleanup failed';
            die 'Uninstall fixture exceeded its watchdog';
        }
        sleep 0.02;
    }
}
my @cases = (
    ['check', ['--check'], 0, 0, '', 0, 0],
    ['check-denied', ['--check'], 0, 2, '', 0, 2],
    ['apply-denied', [], 0, 2, '', 1, 2],
    ['non-root', [], 1000, 0, '', 0, 1],
    ['bad-option', ['--unknown'], 0, 0, '', 0, 2],
    ['extra-option', ['--check', 'extra'], 0, 0, '', 0, 2],
    ['uninstall-hook-failure', [], 0, 0, 'uninstall', 0, 4],
    ['appconfig-hook-failure', [], 0, 0, 'unregister', 0, 5],
    ['apply', [], 0, 0, '', 0, 0],
    ['apply-explicit-backup', [], 0, 0, '', 1, 0],
);
for my $case (@cases) {
    my ($name, $args, $uid, $preflight, $fail, $backup, $expected) = @$case;
    my $dir = "$root/$name";
    make_path("$dir/tools", "$dir/scripts", "$dir/packaging", {mode => 0700});
    my %prefix = ('/usr/local/cpanel' => "$dir/cpanel", '/var/cpanel/apps' => "$dir/apps",
        '/etc/cron.d' => "$dir/cron", '/etc/logrotate.d' => "$dir/logrotate");
    my $script = $source;
    $script =~ s/\Q$_\E/$prefix{$_}/g for keys %prefix;
    die 'Unrebased destructive fixture path' if grep { index($script, $_) >= 0 } keys %prefix;
    write_file("$dir/uninstall.sh", $script, 0755);
    my @paths;
    for my $target (@$targets) {
        my $path = $target->{path}; $path =~ s/\Q$_\E/$prefix{$_}/g for keys %prefix;
        push @paths, $path;
        if ($target->{kind} eq 'tree') { make_path($path, {mode => 0755}); write_file("$path/canary", 'retained'); }
        else { (my $parent = $path) =~ s{/[^/]+\z}{}; make_path($parent, {mode => 0755}); write_file($path, 'retained'); }
    }
    write_file("$dir/preserved-cache", 'private-cache'); write_file("$dir/preserved-log", 'scan-log');
    my $audit = Help4::DiskUsage::InstallSafety::audit([
        map { my $p = $_->{path}; $p =~ s/\Q$_\E/$prefix{$_}/g for keys %prefix; +{path => $p, kind => $_->{kind}} } @$targets
    ], anchor => $dir, uid => $>);
    ok($audit->{ok}, "$name real synthetic removal targets pass metadata inspection");
    my $unsafe = "$dir/cpanel/base/frontend/jupiter";
    chmod 0775, $unsafe;
    my $denied = Help4::DiskUsage::InstallSafety::audit([
        {path => "$unsafe/help4_disk_usage", kind => 'tree'}], anchor => $dir, uid => $>);
    ok(!$denied->{ok}, "$name writable parent rejected by real path auditor");
    chmod 0755, $unsafe;
    write_file("$dir/tools/id", "#!/usr/bin/env bash\nprintf '%s\\n' \"\$H4DU_FAKE_UID\"\n", 0755);
    write_file("$dir/tools/perl", '#!/usr/bin/env bash' . "\nset -euo pipefail\n" .
        'test "$#" -eq 1 && test "$1" = "$H4DU_CASE/scripts/uninstall-preflight.pl"' . "\n" .
        'printf \'%s\n\' preflight >> "$H4DU_CASE/trace"' . "\n" .
        'printf \'{"ok":%s}\n\' "$H4DU_PREFLIGHT_OK"' . "\nexit \"\$H4DU_PREFLIGHT_EXIT\"\n", 0755);
    write_file("$dir/scripts/uninstall-preflight.pl", "# Synthetic preflight placeholder; command/arguments enforced by transport fixture.\n");
    make_path("$dir/cpanel/scripts", "$dir/cpanel/bin", {mode => 0755});
    write_file("$dir/cpanel/scripts/uninstall_plugin", <<'SH', 0755);
#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 2 && test "$1" = "$H4DU_CASE/packaging" && test "$2" = '--theme=jupiter'
printf '%s\n' uninstall >> "$H4DU_CASE/trace"
test "$H4DU_FAIL_HOOK" != uninstall || exit 4
SH
    write_file("$dir/cpanel/bin/unregister_appconfig", <<'SH', 0755);
#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 1 && test "$1" = "$H4DU_CASE/apps/help4_disk_usage.conf"
printf '%s\n' unregister >> "$H4DU_CASE/trace"
test "$H4DU_FAIL_HOOK" != unregister || exit 5
SH
    my $allowed = join('|', map { quote($_) } @paths);
    my $real_rm = -x '/bin/rm' ? '/bin/rm' : '/usr/bin/rm';
    write_file("$dir/tools/rm", "#!/usr/bin/env bash\nset -euo pipefail\n" .
        'for arg in "$@"; do' . "\n  case \"\$arg\" in\n    -rf|-f|$allowed) ;;\n    *) exit 97 ;;\n  esac\ndone\n" .
        'printf \'%s\n\' removal >> "$H4DU_CASE/trace"' . "\nexec " . quote($real_rm) . ' "$@"' . "\n", 0755);
    my $real_cp = -x '/bin/cp' ? '/bin/cp' : '/usr/bin/cp';
    write_file("$dir/tools/cp", "#!/usr/bin/env bash\nset -euo pipefail\n" .
        'test "$#" -eq 3 && test "$1" = -a' . "\ncase \"\$2\" in $allowed) ;; *) exit 97 ;; esac\n" .
        'case "$3" in "$H4DU_CASE"/backup/*) ;; *) exit 97 ;; esac' . "\n" .
        'printf \'%s\n\' backup >> "$H4DU_CASE/trace"' . "\nexec " . quote($real_cp) . ' "$@"' . "\n", 0755);
    local $ENV{PATH} = "$dir/tools:$ENV{PATH}";
    local $ENV{H4DU_CASE} = $dir;
    local $ENV{H4DU_FAKE_UID} = $uid;
    local $ENV{H4DU_PREFLIGHT_EXIT} = $preflight;
    local $ENV{H4DU_PREFLIGHT_OK} = $preflight ? 'false' : 'true';
    local $ENV{H4DU_FAIL_HOOK} = $fail;
    local $ENV{HELP4_DU_BACKUP_DIR} = $backup ? "$dir/backup" : '';
    is(run_child($dir, 'bash', "$dir/uninstall.sh", @$args), $expected, "$name expected exit status");
    my @trace = -f "$dir/trace" ? split(/\n/, read_file("$dir/trace")) : ();
    my @expected_trace = $name eq 'non-root' || $name eq 'bad-option' || $name eq 'extra-option' ? () : ('preflight');
    push @expected_trace, ('backup') x 9 if $name eq 'apply-explicit-backup';
    push @expected_trace, 'uninstall' if $name =~ /hook-failure|\Aapply(?:-|\z)/ && !$preflight;
    push @expected_trace, 'unregister' if $name eq 'appconfig-hook-failure' || $name eq 'apply' || $name eq 'apply-explicit-backup';
    push @expected_trace, ('removal') x 2 if $name eq 'apply' || $name eq 'apply-explicit-backup';
    is_deeply(\@trace, \@expected_trace, "$name preflight precedes side effects and failures stop later steps");
    for my $path (@paths) {
        my $removed = ($name eq 'apply' || $name eq 'apply-explicit-backup') && $path ne "$dir/apps/help4_disk_usage.conf";
        is(-e $path ? 1 : 0, $removed ? 0 : 1, "$name managed fixture path preserved/removed as intended");
    }
    is(read_file("$dir/preserved-cache"), 'private-cache', "$name retained cache untouched");
    is(read_file("$dir/preserved-log"), 'scan-log', "$name retained log untouched");
    is(-d "$dir/backup" ? 1 : 0, $name eq 'apply-explicit-backup' ? 1 : 0, "$name default/refused path creates no backup");
}
make_path("$root/native-check", {mode => 0700});
my $native_exit = run_child("$root/native-check", 'bash', "$FindBin::Bin/../uninstall.sh", '--check');
my $native = decode_json(read_file("$root/native-check/output"));
if ($^O ne 'linux' || $> != 0) {
    is($native_exit, 2, 'Native removal preflight refuses unsupported OS/non-root');
    ok(!$native->{ok}, 'Rejected native check never reports ready');
    is($native->{removal_paths}{objects_checked}, 0, 'Rejected platform/identity never traverses production paths');
} else {
    is($native_exit, $native->{ok} ? 0 : 2, 'Root Linux read-only preflight status matches metadata audit');
    ok(exists $native->{removal_paths}{objects_checked}, 'Read-only root Linux inspection is explicit, not native uninstall proof');
}
note('Offline root/preflight/vendor-hook transports; real removal/copy only on allowlisted synthetic paths. Native lifecycle, active-worker quiescence and continuous path-race protection remain unmeasured.');
done_testing;
