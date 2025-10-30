Offline mock commands
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

Notes

- These mocks are intended for testing only.
- Keep outputs small and deterministic.

