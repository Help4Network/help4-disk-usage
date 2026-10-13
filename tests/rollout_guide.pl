#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use JSON::PP;
use Digest::SHA qw(sha256_hex);
use Test::More;
use POSIX qw(setsid WNOHANG);
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC sleep);

sub read_file {
    open my $fh, '<', $_[0] or die $!;
    local $/; my $data = <$fh>; close $fh or die $!; return $data;
}
sub write_file {
    my ($path, $value, $mode) = @_;
    open my $fh, '>', $path or die $!;
    print {$fh} $value or die $!; close $fh or die $!;
    chmod($mode // 0600, $path) or die $!;
}
my $guide = read_file("$FindBin::Bin/../docs/rollout.md");
my ($command) = $guide =~ /## First Install on a New cPanel Server\n.*?```bash\n(.*?)\n```/s;
die 'First-install command unavailable' unless defined $command;
my $root = tempdir(CLEANUP => 1);
chmod 0700, $root;
make_path("$root/bin", "$root/payload/help4-disk-usage-9.8.7", {mode => 0700});
write_file("$root/payload/help4-disk-usage-9.8.7/install.sh", <<'SH', 0755);
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = '--check' ] && [ "$#" -eq 1 ]; then
  printf '%s\n' preflight >> "$H4DU_ROLLOUT_CASE/install-calls"
  test "${H4DU_ROLLOUT_FAIL_PREFLIGHT:-0}" = 0
  exit
fi
test "$#" -eq 0
printf '%s\n' apply >> "$H4DU_ROLLOUT_CASE/install-calls"
printf '%s\n%s\n' "$HELP4_DU_RELEASE_URL" "$HELP4_DU_UPDATE_MANIFEST_URL" > "$H4DU_ROLLOUT_CASE/metadata"
SH
system('tar', '-czf', "$root/package.tar.gz", '-C', "$root/payload", 'help4-disk-usage-9.8.7') == 0 or die 'Fixture package unavailable';
my $digest = sha256_hex(read_file("$root/package.tar.gz"));
write_file("$root/bin/mktemp", <<'SH', 0755);
#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 2 && test "$1" = '-d' && test "$2" = '/root/help4-disk-usage.XXXXXX'
printf '%s\n' "$H4DU_ROLLOUT_CASE/work"
SH
write_file("$root/bin/curl", <<'SH', 0755);
#!/usr/bin/env bash
set -euo pipefail
destination=''
url=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) shift; destination="$1";;
    https://*) url="$1";;
  esac
  shift
done
printf '%s\n' "$url" >> "$H4DU_ROLLOUT_CASE/requests"
case "$url" in
  https://raw.githubusercontent.com/Help4Network/help4-disk-usage/main/update.json)
    cp "$H4DU_ROLLOUT_CASE/manifest.json" "$destination";;
  https://github.com/Help4Network/help4-disk-usage/archive/refs/tags/v9.8.7.tar.gz)
    cp "$H4DU_ROLLOUT_ROOT/package.tar.gz" "$destination";;
  *) exit 22;;
esac
SH
write_file("$root/bin/sha256sum", <<'SH', 0755);
#!/usr/bin/env bash
set -euo pipefail
exec shasum -a 256 "$@"
SH
my $url = 'https://github.com/Help4Network/help4-disk-usage/archive/refs/tags/v9.8.7.tar.gz';
my $manifest = {version => '9.8.7', package_url => $url, sha256 => $digest};
my @cases = (
    ['valid', $manifest, 0, 0, 2],
    ['preflight-denied', $manifest, 1, 1, 2],
    ['wrong-digest', {%$manifest, sha256 => '0' x 64}, 1, 0, 2],
    ['moving-branch', {%$manifest, package_url => 'https://github.com/Help4Network/help4-disk-usage/archive/refs/heads/main.tar.gz'}, 1, 0, 1],
    ['wrong-version', {%$manifest, version => '9.8.8'}, 1, 0, 1],
    ['foreign-repository', {%$manifest, package_url => 'https://github.com/example/foreign/archive/refs/tags/v9.8.7.tar.gz'}, 1, 0, 1],
    ['missing-digest', {version => '9.8.7', package_url => $url}, 1, 0, 1],
    ['wrong-digest-type', {%$manifest, sha256 => []}, 1, 0, 1],
    ['leading-zero-version', {%$manifest, version => '09.8.7'}, 1, 0, 1],
    ['non-object', [], 1, 0, 1],
    ['invalid-json', '{', 1, 0, 1],
);
for my $case (@cases) {
    my ($name, $data, $fails, $preflight, $requests) = @$case;
    my $dir = "$root/$name";
    make_path("$dir/work", {mode => 0700});
    write_file("$dir/manifest.json", ref($data) ? JSON::PP->new->canonical->encode($data) : $data);
    write_file("$dir/first-install.sh", "$command\n");
    my $pid = fork(); die 'Fork unavailable' unless defined $pid;
    if (!$pid) {
        setsid() != -1 or die 'Private process group unavailable';
        $ENV{PATH} = "$root/bin:$ENV{PATH}";
        $ENV{H4DU_ROLLOUT_ROOT} = $root; $ENV{H4DU_ROLLOUT_CASE} = $dir;
        $ENV{H4DU_ROLLOUT_FAIL_PREFLIGHT} = $preflight;
        open STDOUT, '>', "$dir/output" or die $!;
        open STDERR, '>&', \*STDOUT or die $!;
        exec('bash', "$dir/first-install.sh"); die 'Bash unavailable';
    }
    my $timed_out = 0;
    my $status;
    my $deadline = clock_gettime(CLOCK_MONOTONIC) + 10;
    while (1) {
        my $completed = waitpid($pid, WNOHANG);
        if ($completed == $pid) { $status = $?; last; }
        die 'Private process wait failed' if $completed < 0;
        if (clock_gettime(CLOCK_MONOTONIC) >= $deadline) {
            $timed_out = 1;
            kill 'KILL', -$pid;
            waitpid($pid, 0) == $pid or die 'Private process cleanup failed';
            $status = $?;
            last;
        }
        sleep 0.02;
    }
    ok(!$timed_out && !($status & 127), "$name completes without timeout or signal");
    is(($status >> 8) != 0 ? 1 : 0, $fails, "$name documented command exit");
    my @actual = -e "$dir/requests" ? split(/\n/, read_file("$dir/requests")) : ();
    is(scalar @actual, $requests, "$name download admission bound");
    my $calls = -e "$dir/install-calls" ? read_file("$dir/install-calls") : '';
    if (!$fails) {
        is(read_file("$dir/metadata"), "$url\nhttps://raw.githubusercontent.com/Help4Network/help4-disk-usage/main/update.json\n",
            'Installer metadata uses the exact manifest package URL');
        is($calls, "preflight\napply\n", 'Native preflight precedes application');
    } else {
        ok(!-e "$dir/metadata", "$name cannot apply the package");
        is($calls, $preflight ? "preflight\n" : '', "$name expected preflight admission");
    }
}
note('Documentation command executed with download/mktemp/installer fixtures and real checksum/tar; no network, root or native installation proof.');
done_testing;
