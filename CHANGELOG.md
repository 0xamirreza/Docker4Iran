# Changelog

## [1.3.0] - 2026-01-01

### Added
- **Arch Linux Support**: Added full support for Arch Linux based distributions (e.g., Manjaro, Arch).
- **Multi-Package Manager**: The script now uses `pacman` for installation on Arch-based systems.
- **systemd-resolved Support**: DNS configuration is now compatible with modern systems using `systemd-resolved`.

### Fixed
- Fixed an issue where Python dependencies were not installed correctly on non-Debian systems.
- Fixed a crash that occurred when the `/etc/docker/daemon.json` file did not exist on a fresh installation.

## [1.2.0] - 2024-10-17

### Added
- Container logs viewer with live streaming (`docker logs -f`)
- Multiple log viewing options (50, 100, 500 lines, custom count)
- Timestamp support for logs
- Graceful Ctrl+C handling (returns to menu instead of exiting script)

### Fixed
- JSON configuration format consistency between `dns.json` and `docker.json`
- Renamed `mirror_selector.py` to `docker_selector.py`
- Updated all script references

### Changed
- Standardized configuration file formats
- Improved menu structure and user experience
