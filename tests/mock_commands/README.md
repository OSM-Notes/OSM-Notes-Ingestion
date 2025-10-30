# Offline mock commands

Version: 2025-10-30

This directory provides mock implementations of common CLI tools used by the
pipeline to enable fully offline/local test runs.

Usage

1. Prepend this directory to PATH:

   export PATH="$(pwd)/tests/mock_commands:$PATH"

2. Run your scripts/tests as usual. The mocks will intercept calls to tools
   such as wget and curl and produce deterministic fixture outputs.

Fixtures

- JSON and XML fixtures are located under test/command/extra/.
  The mocks will try to resolve fixtures automatically from URLs.
  Examples (if the file exists under test/command/extra/):
  - curl/wget .../notes/3394115.json -> 3394115.json
  - curl/wget .../countries -> countries
  - curl/wget .../maritimes -> maritimes
  - curl/wget .../OSM-notes-API.xml -> OSM-notes-API.xml
  - curl/wget .../apiCall_1.xml -> apiCall_1.xml
  - curl/wget .../mockPlanetDump.osn.xml -> mockPlanetDump.osn.xml

Environment

- You can override the fixtures directory with MOCK_FIXTURES_DIR.
  Default is ../../test/command/extra relative to this directory.

Notes

- These mocks are intended for testing only.
- Keep outputs small and deterministic.
