#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../src/lib";
use Help4::DiskUsage::InstallSafety;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use Test::More;
use POSIX qw(mkfifo);

my $root = tempdir(CLEANUP => 1);
chmod 0700, $root;
make_path("$root/plugin/bin", "$root/private", {mode => 0755});
my $file = "$root/plugin/bin/scanner";
open my $fh, '>', $file or die $!;
print {$fh} "fixture\n";
close $fh;
chmod 0755, $file;
my $targets = [{path => "$root/plugin", kind => 'tree'}, {path => "$root/new/config.json", kind => 'file'}];
sub audit { Help4::DiskUsage::InstallSafety::audit($targets, anchor => $root, uid => $>, @_) }
ok(audit()->{ok}, 'Safe existing tree and missing install targets pass');
ok(audit()->{objects_checked} >= 5, 'Ancestors and managed descendants inspected');
ok(!audit(uid => $> + 1)->{ok}, 'Foreign ownership denied');
chmod 0775, "$root/plugin/bin";
ok(!audit()->{ok}, 'Group-writable directory denied');
chmod 0755, "$root/plugin/bin";
chmod 0757, $file;
ok(!audit()->{ok}, 'World-writable executable denied');
chmod 0755, $file;
link $file, "$root/private/hardlink" or die $!;
ok(!audit()->{ok}, 'Hard-linked executable denied before overwrite');
unlink "$root/private/hardlink";
symlink "$root/private", "$root/plugin/link" or die $!;
ok(!audit()->{ok}, 'Managed tree symlink denied without traversal');
my $overlap = Help4::DiskUsage::InstallSafety::audit([
    {path => $file, kind => 'file'}, {path => "$root/plugin", kind => 'tree'}],
    anchor => $root, uid => $>);
ok(!$overlap->{ok}, 'Prior ancestor inspection cannot skip subsequent tree traversal');
unlink "$root/plugin/link";
symlink $file, "$root/plugin/leaf" or die $!;
ok(!audit()->{ok}, 'File symlink denied');
unlink "$root/plugin/leaf";
mkfifo("$root/plugin/fifo", 0600) or die $!;
ok(!audit()->{ok}, 'FIFO rejected without blocking open');
unlink "$root/plugin/fifo";
ok(!audit(limit => 2)->{ok}, 'Entry cap fails closed');
ok(!audit(depth => 1)->{ok}, 'Depth cap fails closed');
{
    no warnings 'redefine';
    my $clock = 0;
    local *Help4::DiskUsage::InstallSafety::time = sub { ++$clock };
    ok(!audit(seconds => 0.5)->{ok}, 'Elapsed-time cap fails closed');
}
my $bounded = eval { audit(limit => 8193) };
ok(!$bounded && $@, 'Unbounded inspection configuration rejected');
symlink "$root/private", "$root/alias" or die $!;
my $ancestor = Help4::DiskUsage::InstallSafety::audit(
    [{path => "$root/alias/new/file", kind => 'file'}], anchor => $root, uid => $>);
ok(!$ancestor->{ok}, 'Symlink ancestor denied even for missing destination');
my $wrong = Help4::DiskUsage::InstallSafety::audit(
    [{path => "$file/new", kind => 'file'}], anchor => $root, uid => $>);
ok(!$wrong->{ok}, 'Regular-file ancestor denied');
for my $path ("$root/../outside", "$root/plugin//new", "$root/plugin\nnew", '/outside') {
    ok(!Help4::DiskUsage::InstallSafety::audit([{path => $path, kind => 'file'}],
        anchor => $root, uid => $>)->{ok}, 'Malformed or out-of-scope fixture target denied');
}
chmod 0777, $root;
ok(!audit()->{ok}, 'Writable installation anchor denied');
chmod 0700, $root;
ok(audit()->{ok}, 'Safe tree remains unchanged after denied inspections');
is(-s $file, 8, 'No executable writes performed');
my $production = Help4::DiskUsage::InstallSafety::targets();
is(scalar @$production, 11, 'All installer-owned destination trees and singleton files covered');
ok(!grep({$_->{path} =~ /home|tmp/} @$production), 'No customer home traversal');
done_testing;
