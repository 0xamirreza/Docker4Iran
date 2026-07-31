# Changelog

## [1.5.1] - 2026-07-31

### Fixed
- Removed the redundant image prune step from 0xDocker full cleanup, which could appear to hang before the main system cleanup.
- Added explicit cleanup failure handling and clearer progress messages.

## [1.4.0] - 2026-06-02

### Changed
- Converted DNS and Docker registry selector logic into the single main Bash script.
- Updated the main installer to run embedded Bash workflows for DNS and registry actions.
- Removed runtime and package dependency checks that are no longer needed.

### Removed
- Removed standalone selector files that were replaced by the Bash implementation.

## [1.3.0] - 2026-01-01

### Added
- **Arch Linux Support**: Added full support for Arch Linux based distributions (e.g., Manjaro, Arch).
- **Multi-Package Manager**: The script now uses `pacman` for installation on Arch-based systems.
- **systemd-resolved Support**: DNS configuration is now compatible with modern systems using `systemd-resolved`.

### Fixed
- Fixed an issue where selector dependencies were not installed correctly on non-Debian systems.
- Fixed a crash that occurred when the `/etc/docker/daemon.json` file did not exist on a fresh installation.

## [1.2.0] - 2024-10-17

### Added
- Container logs viewer with live streaming (`docker logs -f`)
- Multiple log viewing options (50, 100, 500 lines, custom count)
- Timestamp support for logs
- Graceful Ctrl+C handling (returns to menu instead of exiting script)

### Fixed
- JSON configuration format consistency between `dns.json` and `docker.json`
- Renamed the mirror selector script for clearer Docker registry usage
- Updated all script references

### Changed
- Standardized configuration file formats
- Improved menu structure and user experience
