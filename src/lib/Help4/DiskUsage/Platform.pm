package Help4::DiskUsage::Platform;
use strict;
use warnings;

sub os_release {
    my ($raw) = @_;
    die "Invalid operating-system metadata\n" if !defined($raw) || length($raw) > 65536;
    my %values;
    for my $line (split /\n/, $raw) {
        next unless $line =~ /\A(ID|VERSION_ID)=(.*)\z/;
        my ($key, $value) = ($1, $2);
        die "Duplicate operating-system metadata\n" if exists $values{$key};
        $value = $1 if $value =~ /\A["']([^"']*)["']\z/;
        die "Invalid operating-system metadata\n" unless $value =~ /\A[A-Za-z0-9._-]+\z/;
        $values{$key} = lc $value;
    }
    die "Missing operating-system metadata\n" unless $values{ID} && $values{VERSION_ID};
    return \%values;
}

sub classify {
    my ($os, $version, $arch) = @_;
    my ($major) = ($version || '') =~ /\A(?:11\.)?([0-9]+)\.[0-9]+(?:\.[0-9]+)?\z/;
    return {status => 'unsupported', reason => 'cPanel version is unavailable'} unless defined $major;
    return {status => 'unsupported', reason => 'cPanel requires x86_64'} unless ($arch || '') eq 'x86_64';
    my $id = $os->{ID} || '';
    return {status => 'unsupported', reason => 'OS version is not a reviewed numeric release'}
        unless ($os->{VERSION_ID} || '') =~ /\A[0-9]+(?:\.[0-9]+)*\z/;
    my ($os_major) = ($os->{VERSION_ID} || '') =~ /\A([0-9]+)/;
    my %minimum = (almalinux => {8 => 110, 9 => 114, 10 => 132},
        cloudlinux => {8 => 110, 9 => 114, 10 => 134}, ubuntu => {24 => 110});
    if (exists $minimum{$id} && exists $minimum{$id}{$os_major || 0} &&
        ($id ne 'ubuntu' || ($os->{VERSION_ID} || '') eq '24.04')) {
        return {status => 'unsupported', reason => 'cPanel version is too old for this OS'}
            if $major < $minimum{$id}{$os_major};
        return {status => 'current', reason => 'Listed vendor OS family; native plugin QA still required'};
    }
    return {status => 'legacy', reason => 'CloudLinux 7 ELS requires cPanel 110 and a current ELS entitlement'}
        if $id eq 'cloudlinux' && ($os_major || 0) == 7 && $major == 110;
    return {status => 'legacy', reason => 'Vendor no longer supports new/current installations on this OS'}
        if ($id eq 'rocky' && ($os_major || 0) =~ /\A[89]\z/) ||
           ($id eq 'ubuntu' && ($os->{VERSION_ID} || '') eq '22.04');
    return {status => 'unsupported', reason => 'OS/version is not in the reviewed cPanel matrix'};
}

1;
