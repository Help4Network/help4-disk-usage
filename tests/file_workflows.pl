#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../src/lib";
use Help4::DiskUsage::Report qw(report_html report_export filemanager_url report_path);
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use JSON::PP qw(decode_json encode_json);
use Cwd qw(abs_path);
use File::Basename qw(basename);

sub check { die "$_[1]\n" unless $_[0]; }
my $root = abs_path("$FindBin::Bin/..");
my ($user, $home) = ((getpwuid($>))[0], (getpwuid($>))[7]);
my $tmp = tempdir('h4du-files-XXXXXX', DIR => $home, CLEANUP => 1);
my $outside = tempdir(CLEANUP => 1);
my $relative = basename($tmp);
my $odd = 'odd # & + %';
make_path("$tmp/$odd", "$tmp/cache/accounts");
open my $fh, '>', "$tmp/$odd/report.log" or die $!;
print {$fh} 'synthetic'; close $fh;
symlink($outside, "$tmp/escape") or die $!;
open $fh, '>', "$outside/private.log" or die $!;
close $fh;

my $url = filemanager_url($home, "$relative/$odd/report.log", 0);
check($url =~ m{\A\.\./filemanager/index\.html\?dir=%2F}, 'File Manager route not session-relative');
check($url =~ /odd%20%23%20%26%20%2B%20%25/, 'special filename component not safely encoded');
check(filemanager_url($home, "$relative/$odd", 1) eq $url, 'directory jump not equivalent to file parent');
check(!filemanager_url($home, "$relative/escape/private.log", 0), 'symlink escape generated cross-home URL');
check(!filemanager_url($home, "$relative/missing.log", 0), 'removed cache entry generated URL');
for my $invalid ('../victim', '/etc/passwd', 'x/../y', 'x//y', "x\nheader", 'x\\y', 'x/.') {
    check(!defined(report_path($invalid, 1)), 'invalid report path accepted');
    check(!filemanager_url($home, $invalid, 1), 'invalid path generated File Manager URL');
}

my $data = { user => $user, home => '/home/OTHER_PRIVATE_ACCOUNT', scanned_at => '2026-10-07T12:00:00Z',
    scanned_at_epoch => time, scan_complete => JSON::PP::true, disk_bytes => 999,
    large_files => [{relative_path => "$relative/$odd/report.log", bytes => 999}, {relative_path => '=SUM(1).log', bytes => 1},
        {relative_path => '../OTHER_PRIVATE_ACCOUNT/secret.log', bytes => 1}, {relative_path => 'x"<b>.log', bytes => 1}],
    size_hotspots => [{relative_path => "$relative/$odd", bytes => 999, files => 1}] };
my $html = report_html($data, filemanager => 1);
check($html =~ /filemanager-link/ && $html =~ /data-copy=/ && $html =~ /data-search/, 'file actions not rendered');
check($html !~ /OTHER_PRIVATE_ACCOUNT|x"<b>/, 'unsafe path or markup leaked');
my $json = report_export($data, 'json');
check($json !~ /OTHER_PRIVATE_ACCOUNT/ && decode_json($json)->{credit} =~ /help4network.com/, 'JSON export leaked server path or lost credit');
my $csv = report_export($data, 'csv');
check($csv =~ /'\=SUM/ && $csv !~ /OTHER_PRIVATE_ACCOUNT/, 'CSV formula or server path not neutralized');

open $fh, '>', "$tmp/cache/accounts/$user.json" or die $!;
print {$fh} encode_json($data); close $fh;
local $ENV{LC_ALL} = 'C'; local $ENV{LANG} = 'C';
local $ENV{PERL5LIB} = "$root/tests/lib";
local $ENV{HELP4_DU_ACCOUNT_CACHE_DIR} = "$tmp/cache";
local $ENV{HELP4_DU_CONFIG} = "$tmp/no-config";
local $ENV{REMOTE_USER} = $user;
local $ENV{REQUEST_METHOD} = 'GET';
sub cpanel {
    my ($query) = @_;
    local $ENV{QUERY_STRING} = $query;
    open my $pipe, '-|', $^X, "$root/src/cpanel/index.live.pl" or die $!;
    local $/; my $response = <$pipe>; close $pipe;
    check($? == 0, 'cPanel controller failed');
    return $response;
}
if ($user !~ /\A(?:root|cpanel|nobody)\z/) {
    my $jump = cpanel('open=large_files&row=0&account=another-user');
    check($jump =~ /Status: 303/ && $jump =~ /Location: \Q$url\E\r/, 'native file jump did not ignore forged account selector');
    check(cpanel('open=large_files&row=99') =~ /location unavailable/, 'invalid row did not fail closed');
    check(cpanel('open=..%2Fvictim&row=0') =~ /location unavailable/, 'forged group not rejected');
    check(cpanel('export=json&account=another-user') !~ /OTHER_PRIVATE_ACCOUNT/, 'account export accepted other account');
    my $foreign = {%$data, user => 'another-user'};
    open $fh, '>', "$tmp/cache/accounts/$user.json" or die $!;
    print {$fh} encode_json($foreign); close $fh;
    check(cpanel('open=large_files&row=0') !~ /Location:.*filemanager/, 'foreign cache allowed navigation');
    check(cpanel('export=json') !~ /Content-Disposition/, 'foreign cache allowed export');
}
make_path("$tmp/whm/accounts");
for my $name ($user, 'foreignaccount') {
    open $fh, '>', "$tmp/whm/accounts/$name.json" or die $!;
    print {$fh} encode_json({%$data, user => $name}); close $fh;
}
local $ENV{HELP4_DU_CACHE_DIR} = "$tmp/whm";
sub whm {
    my ($query) = @_;
    local $ENV{QUERY_STRING} = $query;
    open my $pipe, '-|', $^X, "$root/src/whm/index.cgi" or die $!;
    local $/; my $response = <$pipe>; close $pipe;
    check($? == 0, 'WHM controller failed');
    return $response;
}
check(whm("view_account=$user") =~ /data-search/, 'owned WHM detail missing');
if ($user ne 'root') {
    check(whm('view_account=foreignaccount&export=json') =~ /Status: 404/, 'foreign WHM export bypassed ownership');
    check(whm('view_account=foreignaccount') !~ /OTHER_PRIVATE_ACCOUNT|data-search/, 'foreign WHM detail exposed report');
}
print "file workflow tests passed\n";
