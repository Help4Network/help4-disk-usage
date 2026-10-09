#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../src/lib";
use Help4::DiskUsage::Platform;
use Test::More;

for my $id (qw(almalinux cloudlinux)) {
    for my $v (8, 9, 10) {
        my $os = Help4::DiskUsage::Platform::os_release("ID=$id\nVERSION_ID=\"$v.1\"\n");
        is(Help4::DiskUsage::Platform::classify($os, '11.136.0.37', 'x86_64')->{status}, 'current', "$id $v");
    }
}
my $ubuntu = Help4::DiskUsage::Platform::os_release("ID='ubuntu'\nVERSION_ID=24.04\n");
is(Help4::DiskUsage::Platform::classify($ubuntu, '11.136.0.37', 'x86_64')->{status}, 'current', 'Ubuntu 24.04');
for my $case ([almalinux => '10', '11.130.0.1'], [cloudlinux => '10', '11.132.0.1'],
    [almalinux => '9', '11.110.0.1'], [ubuntu => '26.04', '11.136.0.37'],
    [debian => '12', '11.136.0.37'], [cloudlinux => '7', '11.136.0.37'], [ubuntu => '24.10', '11.136.0.37'],
    [almalinux => '9-beta', '11.136.0.37']) {
    is(Help4::DiskUsage::Platform::classify({ID => $case->[0], VERSION_ID => $case->[1]}, $case->[2], 'x86_64')->{status},
        'unsupported', "Reject unreviewed pairing @$case");
}
for my $case ([rocky => '8.10', '11.110.0.1'], [rocky => '9.6', '11.136.0.37'],
    [cloudlinux => '7.9', '11.110.0.1'], [ubuntu => '22.04', '11.110.0.1']) {
    is(Help4::DiskUsage::Platform::classify({ID => $case->[0], VERSION_ID => $case->[1]}, $case->[2], 'x86_64')->{status},
        'legacy', "Flag legacy pairing @$case");
}
is(Help4::DiskUsage::Platform::classify($ubuntu, '11.136.0.37', 'aarch64')->{status}, 'unsupported', 'Reject ARM');
is(Help4::DiskUsage::Platform::classify($ubuntu, 'unknown', 'x86_64')->{status}, 'unsupported', 'Reject unknown panel version');
for my $raw ("ID=ubuntu\nID=almalinux\nVERSION_ID=24.04", 'ID=$(touch invalid)', "ID=ubuntu\nVERSION_ID=\"24.04\"junk", 'ID=ubuntu', 'x' x 65537) {
    my $value = eval { Help4::DiskUsage::Platform::os_release($raw) };
    ok(!$value && $@, 'Reject malformed metadata without executing it');
}
done_testing;
