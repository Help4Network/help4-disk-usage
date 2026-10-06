#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use File::Temp qw(tempdir);
use File::Path qw(make_path remove_tree);
use File::Spec;
use Fcntl qw(:flock);
use JSON::PP qw(decode_json encode_json);

my $root = "$FindBin::Bin/..";
my $tmp = tempdir(CLEANUP => 1);
make_path("$tmp/fixture/alice/tree", "$tmp/victim", "$tmp/cache", "$tmp/hooks");
for my $i (1 .. 45) {
    open my $fh, '>', "$tmp/fixture/alice/tree/file-$i" or die $!;
    truncate($fh, 1024 * 1024 + $i) or die $!;
}
open my $secret, '>', "$tmp/victim/private-offender" or die $!;
truncate($secret, 50 * 1024 * 1024) or die $!;
close $secret;
symlink("$tmp/victim", "$tmp/fixture/alice/static-link") or die $!;

sub scan {
    open my $fh, '-|', $^X, "$root/src/bin/help4-disk-usage-scan",
        '--fixture-root', "$tmp/fixture", '--cache-dir', "$tmp/cache",
        '--scope', 'account', '--account', 'alice', '--large-mb', '1', '--top', '3', @_ or die $!;
    local $/;
    my $json = <$fh>;
    close $fh or die "scan failed: $?\n";
    return decode_json($json)->{accounts}[0];
}
sub check { die "$_[1]\n" unless $_[0] }

my $full = scan('--write-cache');
check($full->{scan_complete}, 'fixture scan should be complete');
check(@{$full->{large_files}} == 3, 'top-N was not capped');
check($full->{large_files}[0]{relative_path} eq 'tree/file-45', 'top-N ordering is wrong');
check(encode_json($full) !~ /private-offender/, 'static symlink leaked victim metadata');
my $partial = scan('--max-entries', '8', '--write-cache');
check(!$partial->{scan_complete} && $partial->{limit_reason} eq 'ENTRY_LIMIT', 'entry limit did not mark partial coverage');
check(!$partial->{growth}{has_previous}, 'partial scan generated growth');
my $after = scan('--write-cache');
check(!$after->{growth}{has_previous}, 'partial baseline generated growth');
check(scan('--write-cache')->{growth}{has_previous}, 'two complete scans did not compare growth');
open my $invalid_cache, '>', "$tmp/cache/accounts/alice.json" or die $!;
print {$invalid_cache} '[]';
close $invalid_cache;
check(!scan('--write-cache')->{growth}{has_previous}, 'non-object cache was used as a growth baseline');
check(scan('--max-dirs', '1')->{scan_complete}, 'one directory should fit directory cap');
make_path("$tmp/fixture/alice/tree/deeper");
check(!scan('--max-dirs', '1')->{scan_complete}, 'directory cap did not stop deeper traversal');
check(scan('--max-depth', '1')->{limit_reason} eq 'DEPTH_LIMIT', 'depth cap was not enforced');
for my $i (1 .. 12) {
    my $dir = "$tmp/fixture/alice/" . ('p' x 100) . $i;
    make_path($dir);
    open my $file, '>', "$dir/file" or die $!;
    print {$file} 'fixture';
}
check(scan('--max-path-bytes', '1024')->{limit_reason} eq 'PATH_LIMIT', 'retained path memory cap was not enforced');
remove_tree(glob "$tmp/fixture/alice/pp*");
symlink("$tmp/fixture/alice", "$tmp/linked-home") or die $!;
my $linked = scan('--home', "$tmp/linked-home");
check(!$linked->{scan_complete} && !$linked->{disk_bytes}, 'symlinked home was traversed');

# Inject scheduling/race points in the test subprocess only, without a production hook.
open my $module, '>', "$tmp/hooks/AuditHook.pm" or die $!;
print {$module} <<'MODULE';
package AuditHook;
use strict;
use warnings;
use Cwd qw(getcwd);
our $triggered;
BEGIN {
    *CORE::GLOBAL::lstat = sub (_) {
        my @st = CORE::lstat($_[0]);
        if (!$triggered && $ENV{H4DU_RACE} && $_[0] eq 'swap') {
            $triggered = 1;
            rename('swap', 'original') or die $!;
            symlink($ENV{H4DU_VICTIM}, 'swap') or die $!;
        }
        return wantarray ? @st : scalar @st;
    };
    *CORE::GLOBAL::opendir = sub (*$) {
        if (!$triggered && $ENV{H4DU_HOLD} && $_[1] eq '.') {
            $triggered = 1;
            open my $ready, '>', $ENV{H4DU_READY} or die $!;
            close $ready;
            select undef, undef, undef, 0.8;
        }
        if (!$triggered && $ENV{H4DU_ANCESTOR} && getcwd() eq $ENV{H4DU_ANCESTOR}) {
            $triggered = 1;
            rename($ENV{H4DU_ANCESTOR}, "$ENV{H4DU_ANCESTOR}-moved") or die $!;
            symlink($ENV{H4DU_VICTIM}, $ENV{H4DU_ANCESTOR}) or die $!;
        }
        return CORE::opendir($_[0], $_[1]);
    };
}
1;
MODULE
close $module;
{
    local $ENV{PERL5OPT} = '-MAuditHook';
    local $ENV{PERL5LIB} = "$tmp/hooks";
    local $ENV{H4DU_VICTIM} = "$tmp/victim";
    local $ENV{H4DU_RACE} = 1;
    make_path("$tmp/fixture/alice/swap");
    my $raced = scan();
    check(!$raced->{scan_complete}, 'replacement race should be recorded as incomplete');
    check(encode_json($raced) !~ /private-offender/, 'check/open race leaked metadata');
}
{
    local $ENV{PERL5OPT} = '-MAuditHook';
    local $ENV{PERL5LIB} = "$tmp/hooks";
    local $ENV{H4DU_VICTIM} = "$tmp/victim";
    local $ENV{H4DU_ANCESTOR} = "$tmp/fixture/alice/tree";
    my $anchored = scan();
    check(encode_json($anchored) !~ /private-offender/, 'ancestor replacement escaped anchored traversal');
    check($anchored->{disk_bytes} == $full->{disk_bytes}, 'ancestor rename lost anchored children');
}
{
    local $ENV{PERL5OPT} = '-MAuditHook';
    local $ENV{PERL5LIB} = "$tmp/hooks";
    local $ENV{H4DU_HOLD} = 1;
    local $ENV{H4DU_READY} = "$tmp/ready";
    my $pid = fork();
    die $! unless defined $pid;
    if (!$pid) { scan('--write-cache'); exit 0 }
    for (1 .. 100) { last if -e "$tmp/ready"; select undef, undef, undef, 0.01 }
    check(-e "$tmp/ready", 'scan never reached held traversal');
    open my $lock, '<', "$tmp/cache/scan.lock" or die $!;
    check(!flock($lock, LOCK_EX | LOCK_NB), 'scanner released lock before traversal finished');
    my $output = "$tmp/concurrent.out";
    my $second = fork();
    die $! unless defined $second;
    if (!$second) {
        open STDERR, '>', $output or die $!;
        open STDOUT, '>', File::Spec->devnull() or die $!;
        exec $^X, "$root/src/bin/help4-disk-usage-scan", '--fixture-root', "$tmp/fixture",
            '--cache-dir', "$tmp/cache", '--scope', 'account', '--account', 'alice', '--write-cache';
        die $!;
    }
    waitpid($second, 0);
    check($? != 0, 'second cache-writing scanner was allowed');
    open my $denied, '<', $output or die $!;
    local $/;
    check(<$denied> =~ /Another Help4 Disk Usage scan/, 'second scanner failed for the wrong reason');
    waitpid($pid, 0);
    check($? == 0, 'held scanner failed');
    check(flock($lock, LOCK_EX | LOCK_NB), 'scanner did not release lock after publication');
}
check(((stat("$tmp/cache/scan.lock"))[2] & 0222) == 0200, 'shared lock grants tenant write permission');
print "scanner hardening tests passed\n";
