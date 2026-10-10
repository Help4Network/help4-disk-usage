# Linux Installation And Validation Matrix

Reviewed 2026-10-09 against the vendor installation and lifecycle documentation. This plugin installs into an existing licensed cPanel & WHM server with Jupiter; it does not install the panel, change its OS, disable security controls, or install system packages.

| OS target | Vendor prerequisite | Plugin coverage |
| --- | --- | --- |
| AlmaLinux 8 | cPanel 110+ | OS pairing fixtures and Linux collector CI |
| AlmaLinux 9 | cPanel 114+ | OS pairing fixtures and Linux collector CI |
| AlmaLinux 10 | cPanel 132+ | OS pairing fixtures and Linux collector CI |
| CloudLinux 8/9 | Supported panel release for that major | OS pairing fixtures; licensed LVE/CageFS QA required |
| CloudLinux 10 | cPanel 134+, vendor conversion requirements | OS pairing fixtures; licensed LVE/CageFS QA required |
| Ubuntu 24.04 LTS | Vendor-supported panel release | OS pairing fixtures and Linux collector CI |
| CloudLinux 7 ELS | cPanel 110, current vendor ELS entitlement | Legacy warning; not a current-release target |
| Rocky Linux 8/9; Ubuntu 22.04 | Legacy installs only; check channel/lifecycle | Legacy warning; not advertised as current support |

The Rocky installation page explicitly withdraws current installation/support even though historical tables remain. Do not use those historical tables as new-install approval. The current Ubuntu page lists 24.04. ARM, Windows, DNSOnly, unlisted OS versions and unsupported panel pairings fail preflight.

## Check Before Installation

```sh
sudo ./install.sh --check
```

This reports JSON and performs no installation writes. Missing runtime/native commands, incompatible OS/panel pairs or no Jupiter cause nonzero exit. A legacy warning is not certification or vendor support. The normal installer runs the same check before writing runtime files, metadata or cron integration. It never sources `os-release` as shell code or installs/upgrades Perl, cPanel, the OS or packages automatically.

The installer also inspects its existing destination trees, singleton integration files and ancestors before writing. Symlinks, special files, hard-linked regular files, non-root ownership and group/world write bits fail closed. The read-only inspection stops at 8,192 visits, 32 descendant levels or five seconds; exhausting a bound fails installation rather than skipping entries. It neither changes permissions nor follows links into customer homes. Inspect and resolve a failed path under administrator control before retrying; do not broadly `chmod` a shared server or disable this check.

This is a bounded POSIX metadata snapshot, not a race-free installation transaction, an extended-ACL audit or proof of account isolation. Keep installation targets quiescent and review extended ACLs/native registration separately. cPanel's own plugin registration and sprite generation remain vendor-controlled operations. macOS CI runs portable developer regressions and proves that native installation is rejected there; Windows and macOS are not cPanel/WHM server targets.

Install required system packages using the vendor-supported package manager and rerun the check. AlmaLinux/CloudLinux use RPM-family tooling; Ubuntu uses APT. cPanel's bundled Perl is checked separately from system Perl. On CloudLinux verify the actual account-level runtime, shared lock, private caches, home mounts and File Manager while CageFS/LVE are enabled; never disable isolation to make a test pass.

## Native Release Gate

Record OS, panel/plugin versions and exact package checksum. Validate root/reseller WHM and customer Jupiter layouts, foreign-account denial, refresh/303/reload/idle behavior, lock/rate/resource caps, cache ownership, File Manager navigation, cron rotation, updater repair and uninstall. Retain sanitized summaries publicly and customer/session evidence privately. Distro-container collector tests are not licensed-panel installation, role, GUI or CloudLinux validation.

1.0.2 is a source candidate. `update.json` intentionally continues to advertise the immutable 1.0.1 release until promotion. Do not overwrite the published 1.0.1 archive with candidate code.

## Sources

- [AlmaLinux requirements](https://docs.cpanel.net/installation-guide/system-requirements-almalinux/)
- [CloudLinux requirements](https://docs.cpanel.net/installation-guide/system-requirements-cloudlinux/)
- [Ubuntu requirements](https://docs.cpanel.net/installation-guide/system-requirements-ubuntu/)
- [Rocky Linux withdrawal and historical requirements](https://docs.cpanel.net/installation-guide/system-requirements-rockylinux/)
- [Vendor lifecycle policy](https://docs.cpanel.net/knowledge-base/third-party/third-party-software-end-of-life-policy/)

Built by [Help4 Network](https://help4network.com).
