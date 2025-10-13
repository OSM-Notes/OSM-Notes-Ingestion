# OSM-Notes-Common

Shared functions and utilities for OSM Notes processing projects.

## Overview

This repository contains common Bash functions and utilities shared between:
- [OSM-Notes-profile](https://github.com/angoca/OSM-Notes-profile) - Ingestion and WMS
- [OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics) - DWH and Analytics

## Components

### Core Functions

- **`commonFunctions.sh`**: Common utility functions used across all scripts
  - Directory and file management
  - Process management
  - Logging helpers
  - Configuration loading

- **`validationFunctions.sh`**: Validation functions for data integrity
  - XML validation
  - CSV validation
  - Database validation
  - Coordinate validation

- **`consolidatedValidationFunctions.sh`**: Consolidated validation utilities
  - Enhanced XML validation
  - Schema validation
  - Data quality checks

- **`errorHandlingFunctions.sh`**: Error handling and recovery functions
  - Error trapping
  - Cleanup on errors
  - Recovery mechanisms
  - Exit code management

### Libraries

- **`bash_logger.sh`**: Logging library (log4j-style for Bash)
  - Multiple log levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL
  - Timestamp formatting
  - Colored output
  - File and console logging

## Usage as Git Submodule

This repository is designed to be used as a Git submodule.

### Adding as Submodule

```bash
# In your project directory
git submodule add https://github.com/angoca/OSM-Notes-Common.git lib/osm-common

# Commit the submodule
git commit -m "Add OSM-Notes-Common as submodule"
```

### Cloning Projects with Submodules

```bash
# Clone with submodules
git clone --recurse-submodules https://github.com/yourorg/yourproject.git

# Or initialize after cloning
git clone https://github.com/yourorg/yourproject.git
cd yourproject
git submodule init
git submodule update
```

### Updating Submodule

```bash
# Update to latest version
git submodule update --remote lib/osm-common

# Commit the update
git add lib/osm-common
git commit -m "Update osm-common submodule"
```

## Using the Functions

### Example 1: Using Common Functions

```bash
#!/bin/bash

# Load common functions from submodule
source "lib/osm-common/commonFunctions.sh"

# Use the functions
__start_logger
logInfo "Processing started"
```

### Example 2: Using Validation Functions

```bash
#!/bin/bash

# Load validation functions
source "lib/osm-common/validationFunctions.sh"

# Validate XML file
if __validate_xml_file "data.xml" "schema.xsd"; then
    echo "XML is valid"
fi
```

### Example 3: Using Logger

```bash
#!/bin/bash

# Load bash logger
source "lib/osm-common/bash_logger.sh"

# Set log level
LOG_LEVEL="DEBUG"

# Use logger
logInfo "Application started"
logDebug "Debug information"
logError "Something went wrong"
```

## Version Compatibility

This library requires:
- **Bash** 4.0 or higher
- **Linux** operating system
- Standard UNIX utilities (grep, awk, sed, etc.)

## Development

### Making Changes

1. Create a feature branch
2. Make your changes
3. Test with both dependent projects
4. Submit a pull request

### Testing

Before committing changes, ensure:
- All functions are documented
- No breaking changes to public APIs
- shellcheck passes: `shellcheck -x -o all *.sh`
- shfmt formatting: `shfmt -w -i 1 -sr -bn *.sh`

## Versioning

This project follows [Semantic Versioning](https://semver.org/):
- **Major version**: Breaking changes
- **Minor version**: New features (backward compatible)
- **Patch version**: Bug fixes

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

## License

See [LICENSE](LICENSE) for license information.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## Support

For issues or questions:
- Create an issue in this repository
- Check documentation in dependent projects
- Contact: angoca@yahoo.com

## Related Projects

- [OSM-Notes-profile](https://github.com/angoca/OSM-Notes-profile) - Notes ingestion and WMS
- [OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics) - DWH and analytics

## Acknowledgments

- **Andres Gomez (@AngocA)**: Main developer
- All contributors to the OSM Notes processing ecosystem

---

**Version:** 2025-10-13

