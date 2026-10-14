#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../src/lib";
use Help4::DiskUsage::InstallSafety;
use JSON::PP;

if (@ARGV) { die "Usage: uninstall-preflight.pl\n"; }
my @errors;
push @errors, 'Plugin removal requires Linux' unless $^O eq 'linux';
push @errors, 'Plugin removal requires root' unless $> == 0;
my $paths = {ok => 0, objects_checked => 0, errors => []};
if (!@errors) {
    $paths = Help4::DiskUsage::InstallSafety::audit(Help4::DiskUsage::InstallSafety::removal_targets());
    push @errors, @{$paths->{errors}};
}
print JSON::PP->new->canonical->pretty->encode({ok => @errors ? JSON::PP::false : JSON::PP::true,
    removal_paths => $paths, errors => \@errors, built_by => 'https://help4network.com'});
exit(@errors ? 2 : 0);
