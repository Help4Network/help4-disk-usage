#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../src/lib";
use Help4::DiskUsage::Platform;
use JSON::PP;
use POSIX qw(uname);

my @errors;
my @warnings;
push @errors, 'Plugin installation requires Linux' unless $^O eq 'linux';
push @errors, 'Plugin installation requires root' unless $> == 0;
my $os = eval {
    open my $fh, '<', '/etc/os-release' or die "OS metadata unavailable\n";
    local $/;
    Help4::DiskUsage::Platform::os_release(<$fh>);
};
push @errors, 'Operating-system metadata is unavailable or invalid' unless $os;
my $version = '';
if (open my $fh, '<', '/usr/local/cpanel/version') { $version = <$fh> || ''; chomp $version; }
my @uname = uname();
my $platform = Help4::DiskUsage::Platform::classify($os || {}, $version, $uname[4]);
push @errors, $platform->{reason} if $platform->{status} eq 'unsupported';
push @warnings, $platform->{reason} if $platform->{status} eq 'legacy';
for my $required ('/usr/local/cpanel/bin/register_appconfig', '/usr/local/cpanel/scripts/install_plugin',
    '/usr/local/cpanel/scripts/uninstall_plugin', '/usr/local/cpanel/3rdparty/bin/perl') {
    push @errors, "Missing executable: $required" unless -x $required;
}
push @errors, 'Jupiter account frontend is unavailable (DNSOnly is not supported)'
    unless -d '/usr/local/cpanel/base/frontend/jupiter';
for my $command (qw(install tar gzip curl sha256sum nice ionice)) {
    my $found = grep { -x "$_/$command" && !-d "$_/$command" } qw(/usr/bin /bin /usr/sbin /sbin);
    push @errors, "Missing system command: $command" unless $found;
}
for my $dir ('/etc/cron.d', '/etc/logrotate.d') {
    push @errors, "Required system integration directory is missing: $dir" unless -d $dir;
}
my $perl = '/usr/local/cpanel/3rdparty/bin/perl';
if (-x $perl) {
    my $result = system($perl, '-MJSON::PP', '-MFile::Path', '-MFile::Spec', '-MCwd', '-MFcntl',
        '-MEncode', '-MPOSIX', '-MSys::Hostname', '-MCpanel::LiveAPI', '-e', 'exit 0');
    push @errors, 'The bundled cPanel Perl runtime is missing required modules' if $result != 0;
}
print JSON::PP->new->canonical->pretty->encode({ok => @errors ? JSON::PP::false : JSON::PP::true,
    os => $os || {}, cpanel_version => $version, platform => $platform, errors => \@errors,
    warnings => \@warnings, built_by => 'https://help4network.com'});
exit(@errors ? 2 : 0);
