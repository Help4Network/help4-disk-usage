#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use File::Find qw(find);
use Test::More;

my $root = "$FindBin::Bin/..";

# Check the working tree, not the index: extraction may not be committed yet.
for my $path (
    'integrations/whmcs/modules/addons/help4_disk_usage/help4_disk_usage.php',
    'integrations/whmcs/modules/addons/help4_disk_usage/hooks.php',
    'integrations/whmcs/modules/addons/help4_disk_usage/templates/clientarea.tpl',
    'tests/whmcs_tenant_isolation.php',
    'tests/whmcs_ssh_security.php',
    'tests/whmcs_package.sh',
    'scripts/package-whmcs.sh',
) {
    ok(!-e "$root/$path" && !-l "$root/$path", "extracted file absent: $path");
}

my @addon_sources;
my @source_roots = grep { -d $_ } map { "$root/$_" } qw(src packaging integrations modules);
find({no_chdir => 1, wanted => sub {
    return if -d $_ && !-l $_;
    push @addon_sources, $File::Find::name
        if m{/(?:help4_disk_usage\.php|hooks\.php|clientarea\.tpl)$}
        || m{/(?:integrations/whmcs|modules/addons)/};
}}, @source_roots);
is_deeply(\@addon_sources, [], 'native source trees contain no embedded addon sources');

sub read_file {
    my ($path) = @_;
    open my $fh, '<', "$root/$path" or die "Cannot read $path: $!";
    local $/;
    return <$fh>;
}

my $coupling = qr{integrations/whmcs|modules/addons|package-whmcs\.sh|tests/whmcs_|help4-disk-usage-whmcs-[^\s]*\.zip}i;
for my $path (
    'install.sh', 'uninstall.sh', 'scripts/package.sh', 'scripts/preflight.pl',
    'scripts/uninstall-preflight.pl', 'scripts/uninstall-run.pl',
    'tests/branding_update_contract.sh',
) {
    unlike(read_file($path), $coupling, "no addon build/install/test coupling: $path");
}

for my $path ('.github/workflows/ci.yml', '.github/workflows/release.yml') {
    my $workflow = read_file($path);
    unlike($workflow, $coupling, "no addon lint/test/build/upload coupling: $path");
    unlike($workflow, qr{setup-php|\bphp(?:\s|$)}i, "no addon PHP runtime dependency: $path");
    like($workflow, qr{^\s+perl tests/native_separation\.pl\s*$}m, "separation regression runs: $path");
}

for my $path ('README.md', 'docs/whmcs-integration.md') {
    my $doc = read_file($path);
    for my $guide ('cpanel', 'install') {
        like($doc, qr{https://github\.com/Help4Network/help4-disk-usage-whmcs/blob/main/docs/\Q$guide\E\.md},
            "canonical $guide guide linked: $path");
    }
}

done_testing;
