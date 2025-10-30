# Command Fixtures

Version: 2025-01-23

This directory contains deterministic fixture files used by mock commands for
offline testing.

## Location

Fixtures are stored in `tests/fixtures/command/extra/` and used by the mock
implementations in `tests/mock_commands/` (curl, wget, etc.).

## Purpose

These fixtures provide deterministic, repeatable outputs for testing without
requiring network access or external API calls.

## Fixture Types

The `extra/` subdirectory contains:

- **JSON files**: Note IDs (e.g., `3394115.json`) used for API testing
- **XML files**: OSM notes data (e.g., `OSM-notes-API.xml`, `apiCall_1.xml`,
  `mockPlanetDump.osn.xml`)
- **Data files**: Boundaries data (`countries`, `maritimes`)

## Usage

The mock commands in `tests/mock_commands/` automatically resolve these fixtures
from URLs. For example:

- `curl .../notes/3394115.json` -> `tests/fixtures/command/extra/3394115.json`
- `wget .../countries` -> `tests/fixtures/command/extra/countries`

## Environment Variable

You can override the fixtures directory location with `MOCK_FIXTURES_DIR`:

```bash
export MOCK_FIXTURES_DIR="/custom/path/to/fixtures"
```

Default is `../fixtures/command/extra` relative to `tests/mock_commands/`.

## Maintenance

- Keep fixtures small and deterministic
- Update fixtures when API responses change significantly
- Do not commit generated or temporary files (see `.gitignore`)
