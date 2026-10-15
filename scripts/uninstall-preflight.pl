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
my $mutex = {acquired_during_check => 0, installation_absent => 0, snapshot_only => JSON::PP::true};
if (!@errors) {
    $paths = Help4::DiskUsage::InstallSafety::audit(Help4::DiskUsage::InstallSafety::removal_targets());
    push @errors, @{$paths->{errors}};
    if (!@errors) {
        my $ok = eval {
            $mutex = Help4::DiskUsage::InstallSafety::with_removal_lock(sub {
                return {acquired_during_check => $_[0]{held}, installation_absent => $_[0]{installation_absent},
                    snapshot_only => JSON::PP::true};
            });
            1;
        };
        push @errors, $@ unless $ok;
    }
}
chomp @errors;
print JSON::PP->new->canonical->pretty->encode({ok => @errors ? JSON::PP::false : JSON::PP::true,
    removal_paths => $paths, removal_mutex => $mutex, errors => \@errors, built_by => 'https://help4network.com'});
exit(@errors ? 2 : 0);
