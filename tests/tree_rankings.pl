#!/usr/bin/env perl
use strict;
use warnings;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use FindBin;
use JSON::PP qw(decode_json);
my $tmp = tempdir(CLEANUP => 1);
make_path("$tmp/tree/account/public_html/cache/deep");
for my $path ('public_html/file', 'public_html/cache/file', 'public_html/cache/deep/file') {
    open my $fh, '>', "$tmp/tree/account/$path" or die $!;
    print {$fh} '1234567890'; close $fh;
}
symlink('/etc', "$tmp/tree/account/public_html/cache/blocked-link") or die $!;
open my $pipe, '-|', $^X, "$FindBin::Bin/../src/bin/help4-disk-usage-scan", '--fixture-root', "$tmp/tree", '--scope', 'all', '--no-cache', '--max-seconds', '10', '--top', '2' or die $!;
local $/; my $data = decode_json(<$pipe>); close $pipe;
die 'scanner failed' if $?;
my $a = $data->{accounts}[0];
die 'tree bytes/count not recursive or followed link' unless $a->{tree_size_hotspots}[0]{relative_path} eq 'public_html'
    && $a->{tree_size_hotspots}[0]{bytes} == 30 && $a->{tree_size_hotspots}[0]{files} == 7;
die 'tree rank not bounded' unless @{$a->{tree_size_hotspots}} == 2 && @{$a->{tree_inode_hotspots}} == 2;
die 'direct ranking semantics changed' unless $a->{size_hotspots}[0]{bytes} == 10 && $a->{size_hotspots}[0]{files} == 1;
print "tree ranking tests passed\n";
