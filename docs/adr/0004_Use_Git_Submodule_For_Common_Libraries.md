# ADR-0004: Use Git Submodule for Common Libraries

## Status

Accepted

## Context

Multiple projects in the OSM-Notes ecosystem need to share common Bash functions (logging, validation, error handling). We need a way to share code while maintaining version control and allowing independent project evolution.

## Decision

We will use Git submodules to share common libraries via the OSM-Notes-Common repository.

## Consequences

### Positive

- **Code reuse**: Common functions are shared across projects
- **Version control**: Each project can pin to a specific version of common libraries
- **Independence**: Projects can evolve independently while sharing code
- **Single source of truth**: Common code is maintained in one place
- **Git integration**: Native Git support for submodules

### Negative

- **Complexity**: Submodules add complexity to repository management
- **Learning curve**: Team needs to understand submodule workflow
- **Initialization**: Requires explicit submodule initialization when cloning
- **Updates**: Updating submodules requires explicit commands

## Alternatives Considered

### Alternative 1: Copy-paste common code

- **Description**: Copy common functions into each project
- **Pros**: Simple, no dependencies
- **Cons**: Code duplication, maintenance burden, inconsistencies
- **Why not chosen**: Leads to code duplication and maintenance issues

### Alternative 2: Package manager (npm, pip)

- **Description**: Publish common libraries as packages
- **Pros**: Standard package management, versioning
- **Cons**: Requires package registry, overkill for Bash scripts, adds build complexity
- **Why not chosen**: Overkill for simple Bash function libraries

### Alternative 3: Git subtree

- **Description**: Use Git subtree instead of submodules
- **Pros**: Simpler workflow, code is part of main repository
- **Cons**: Less clear separation, harder to track updates, can lead to merge conflicts
- **Why not chosen**: Submodules provide clearer separation and better version control

## References

- [Git Submodules Documentation](https://git-scm.com/book/en/v2/Git-Tools-Submodules)
- [OSM-Notes-Common Repository](https://github.com/OSM-Notes/OSM-Notes-Common)
