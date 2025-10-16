# Changelog

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
